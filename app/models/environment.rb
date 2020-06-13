# frozen_string_literal: true

class Environment < ApplicationRecord
  include Gitlab::Utils::StrongMemoize
  include ReactiveCaching

  self.reactive_cache_refresh_interval = 1.minute
  self.reactive_cache_lifetime = 55.seconds
  self.reactive_cache_hard_limit = 10.megabytes

  belongs_to :project, required: true

  has_many :deployments, -> { visible }, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent
  has_many :successful_deployments, -> { success }, class_name: 'Deployment'
  has_many :active_deployments, -> { active }, class_name: 'Deployment'
  has_many :prometheus_alerts, inverse_of: :environment

  has_one :last_deployment, -> { success.order('deployments.id DESC') }, class_name: 'Deployment'
  has_one :last_deployable, through: :last_deployment, source: 'deployable', source_type: 'CommitStatus'
  has_one :last_pipeline, through: :last_deployable, source: 'pipeline'
  has_one :last_visible_deployment, -> { visible.distinct_on_environment }, inverse_of: :environment, class_name: 'Deployment'
  has_one :last_visible_deployable, through: :last_visible_deployment, source: 'deployable', source_type: 'CommitStatus'
  has_one :last_visible_pipeline, through: :last_visible_deployable, source: 'pipeline'

  before_validation :nullify_external_url
  before_validation :generate_slug, if: ->(env) { env.slug.blank? }

  before_save :set_environment_type
  after_save :clear_reactive_cache!

  validates :name,
            presence: true,
            uniqueness: { scope: :project_id },
            length: { maximum: 255 },
            format: { with: Gitlab::Regex.environment_name_regex,
                      message: Gitlab::Regex.environment_name_regex_message }

  validates :slug,
            presence: true,
            uniqueness: { scope: :project_id },
            length: { maximum: 24 },
            format: { with: Gitlab::Regex.environment_slug_regex,
                      message: Gitlab::Regex.environment_slug_regex_message }

  validates :external_url,
            length: { maximum: 255 },
            allow_nil: true,
            addressable_url: true

  delegate :stop_action, :manual_actions, to: :last_deployment, allow_nil: true

  scope :available, -> { with_state(:available) }
  scope :stopped, -> { with_state(:stopped) }

  scope :order_by_last_deployed_at, -> do
    order(Gitlab::Database.nulls_first_order("(#{max_deployment_id_sql})", 'ASC'))
  end
  scope :order_by_last_deployed_at_desc, -> do
    order(Gitlab::Database.nulls_last_order("(#{max_deployment_id_sql})", 'DESC'))
  end

  scope :in_review_folder, -> { where(environment_type: "review") }
  scope :for_name, -> (name) { where(name: name) }
  scope :preload_cluster, -> { preload(last_deployment: :cluster) }
  scope :auto_stoppable, -> (limit) { available.where('auto_stop_at < ?', Time.zone.now).limit(limit) }

  ##
  # Search environments which have names like the given query.
  # Do not set a large limit unless you've confirmed that it works on gitlab.com scale.
  scope :for_name_like, -> (query, limit: 5) do
    where(arel_table[:name].matches("#{sanitize_sql_like query}%")).limit(limit)
  end

  scope :for_project, -> (project) { where(project_id: project) }
  scope :with_deployment, -> (sha) { where('EXISTS (?)', Deployment.select(1).where('deployments.environment_id = environments.id').where(sha: sha)) }
  scope :unfoldered, -> { where(environment_type: nil) }
  scope :with_rank, -> do
    select('environments.*, rank() OVER (PARTITION BY project_id ORDER BY id DESC)')
  end

  state_machine :state, initial: :available do
    event :start do
      transition stopped: :available
    end

    event :stop do
      transition available: :stopped
    end

    state :available
    state :stopped

    after_transition do |environment|
      environment.expire_etag_cache
    end
  end

  def self.for_id_and_slug(id, slug)
    find_by(id: id, slug: slug)
  end

  def self.max_deployment_id_sql
    Deployment.select(Deployment.arel_table[:id].maximum)
    .where(Deployment.arel_table[:environment_id].eq(arel_table[:id]))
    .to_sql
  end

  def self.pluck_names
    pluck(:name)
  end

  def self.find_or_create_by_name(name)
    find_or_create_by(name: name)
  end

  class << self
    ##
    # This method returns stop actions (jobs) for multiple environments within one
    # query. It's useful to avoid N+1 problem.
    #
    # NOTE: The count of environments should be small~medium (e.g. < 5000)
    def stop_actions
      cte = cte_for_deployments_with_stop_action
      ci_builds = Ci::Build.arel_table

      inner_join_stop_actions = ci_builds.join(cte.table).on(
        ci_builds[:project_id].eq(cte.table[:project_id])
          .and(ci_builds[:ref].eq(cte.table[:ref]))
          .and(ci_builds[:name].eq(cte.table[:on_stop]))
      ).join_sources

      pipeline_ids = ci_builds.join(cte.table).on(
        ci_builds[:id].eq(cte.table[:deployable_id])
      ).project(:commit_id)

      Ci::Build.joins(inner_join_stop_actions)
               .with(cte.to_arel)
               .where(ci_builds[:commit_id].in(pipeline_ids))
               .where(status: HasStatus::BLOCKED_STATUS)
               .preload_project_and_pipeline_project
               .preload(:user, :metadata, :deployment)
    end

    private

    def cte_for_deployments_with_stop_action
      Gitlab::SQL::CTE.new(:deployments_with_stop_action,
        Deployment.where(environment_id: select(:id))
          .distinct_on_environment
          .stoppable)
    end
  end

  def clear_prometheus_reactive_cache!(query_name)
    cluster_prometheus_adapter&.clear_prometheus_reactive_cache!(query_name, self)
  end

  def cluster_prometheus_adapter
    @cluster_prometheus_adapter ||= ::Gitlab::Prometheus::Adapter.new(project, deployment_platform&.cluster).cluster_prometheus_adapter
  end

  def predefined_variables
    Gitlab::Ci::Variables::Collection.new
      .append(key: 'CI_ENVIRONMENT_NAME', value: name)
      .append(key: 'CI_ENVIRONMENT_SLUG', value: slug)
  end

  def recently_updated_on_branch?(ref)
    ref.to_s == last_deployment.try(:ref)
  end

  def nullify_external_url
    self.external_url = nil if self.external_url.blank?
  end

  def set_environment_type
    names = name.split('/')

    self.environment_type = names.many? ? names.first : nil
  end

  def includes_commit?(commit)
    return false unless last_deployment

    last_deployment.includes_commit?(commit)
  end

  def last_deployed_at
    last_deployment.try(:created_at)
  end

  def update_merge_request_metrics?
    folder_name == "production"
  end

  def ref_path
    "refs/#{Repository::REF_ENVIRONMENTS}/#{slug}"
  end

  def formatted_external_url
    return unless external_url

    external_url.gsub(%r{\A.*?://}, '')
  end

  def stop_action_available?
    available? && stop_action.present?
  end

  def stop_with_action!(current_user)
    return unless available?

    stop!
    stop_action&.play(current_user)
  end

  def reset_auto_stop
    update_column(:auto_stop_at, nil)
  end

  def actions_for(environment)
    return [] unless manual_actions

    manual_actions.select do |action|
      action.expanded_environment_name == environment
    end
  end

  def has_terminals?
    available? && deployment_platform.present? && last_deployment.present?
  end

  def terminals
    with_reactive_cache do |data|
      deployment_platform.terminals(self, data)
    end
  end

  def calculate_reactive_cache
    return unless has_terminals? && !project.pending_delete?

    deployment_platform.calculate_reactive_cache_for(self)
  end

  def deployment_namespace
    strong_memoize(:kubernetes_namespace) do
      deployment_platform.cluster.kubernetes_namespace_for(self) if deployment_platform
    end
  end

  def has_metrics?
    available? && (prometheus_adapter&.configured? || has_sample_metrics?)
  end

  def has_sample_metrics?
    !!ENV['USE_SAMPLE_METRICS']
  end

  def metrics
    prometheus_adapter.query(:environment, self) if has_metrics_and_can_query?
  end

  def prometheus_status
    deployment_platform&.cluster&.application_prometheus&.status_name
  end

  def additional_metrics(*args)
    return unless has_metrics_and_can_query?

    prometheus_adapter.query(:additional_metrics_environment, self, *args.map(&:to_f))
  end

  def prometheus_adapter
    @prometheus_adapter ||= Gitlab::Prometheus::Adapter.new(project, deployment_platform&.cluster).prometheus_adapter
  end

  def slug
    super.presence || generate_slug
  end

  def external_url_for(path, commit_sha)
    return unless self.external_url

    public_path = project.public_path_for_source_path(path, commit_sha)
    return unless public_path

    [external_url.delete_suffix('/'), public_path.delete_prefix('/')].join('/')
  end

  def expire_etag_cache
    Gitlab::EtagCaching::Store.new.tap do |store|
      store.touch(etag_cache_key)
    end
  end

  def etag_cache_key
    Gitlab::Routing.url_helpers.project_environments_path(
      project,
      format: :json)
  end

  def folder_name
    self.environment_type || self.name
  end

  def name_without_type
    @name_without_type ||= name.delete_prefix("#{environment_type}/")
  end

  def deployment_platform
    strong_memoize(:deployment_platform) do
      project.deployment_platform(environment: self.name)
    end
  end

  def knative_services_finder
    if last_deployment&.cluster
      Clusters::KnativeServicesFinder.new(last_deployment.cluster, self)
    end
  end

  def auto_stop_in
    auto_stop_at - Time.now if auto_stop_at
  end

  def auto_stop_in=(value)
    return unless value
    return unless parsed_result = ChronicDuration.parse(value)

    self.auto_stop_at = parsed_result.seconds.from_now
  end

  def elastic_stack_available?
    !!deployment_platform&.cluster&.application_elastic_stack&.available?
  end

  private

  def has_metrics_and_can_query?
    has_metrics? && prometheus_adapter.can_query?
  end

  def generate_slug
    self.slug = Gitlab::Slug::Environment.new(name).generate
  end
end

Environment.prepend_if_ee('EE::Environment')

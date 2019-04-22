# frozen_string_literal: true

class Environment < ApplicationRecord
  include Gitlab::Utils::StrongMemoize
  # Used to generate random suffixes for the slug
  LETTERS = 'a'..'z'
  NUMBERS = '0'..'9'
  SUFFIX_CHARS = LETTERS.to_a + NUMBERS.to_a

  belongs_to :project, required: true

  has_many :deployments, -> { success }, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent

  has_one :last_deployment, -> { success.order('deployments.id DESC') }, class_name: 'Deployment'

  before_validation :nullify_external_url
  before_validation :generate_slug, if: ->(env) { env.slug.blank? }

  before_save :set_environment_type

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
            url: true

  delegate :stop_action, :manual_actions, to: :last_deployment, allow_nil: true

  scope :available, -> { with_state(:available) }
  scope :stopped, -> { with_state(:stopped) }
  scope :order_by_last_deployed_at, -> do
    max_deployment_id_sql =
      Deployment.select(Deployment.arel_table[:id].maximum)
      .where(Deployment.arel_table[:environment_id].eq(arel_table[:id]))
      .to_sql
    order(Gitlab::Database.nulls_first_order("(#{max_deployment_id_sql})", 'ASC'))
  end
  scope :in_review_folder, -> { where(environment_type: "review") }
  scope :for_name, -> (name) { where(name: name) }

  ##
  # Search environments which have names like the given query.
  # Do not set a large limit unless you've confirmed that it works on gitlab.com scale.
  scope :for_name_like, -> (query, limit: 5) do
    where('name LIKE ?', "#{sanitize_sql_like(query)}%").limit(limit)
  end

  scope :for_project, -> (project) { where(project_id: project) }
  scope :with_deployment, -> (sha) { where('EXISTS (?)', Deployment.select(1).where('deployments.environment_id = environments.id').where(sha: sha)) }

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

  def self.pluck_names
    pluck(:name)
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

  def first_deployment_for(commit_sha)
    ref = project.repository.ref_name_for_sha(ref_path, commit_sha)

    return unless ref

    deployment_iid = ref.split('/').last
    deployments.find_by(iid: deployment_iid)
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

  def actions_for(environment)
    return [] unless manual_actions

    manual_actions.select do |action|
      action.expanded_environment_name == environment
    end
  end

  def has_terminals?
    project.deployment_platform.present? && available? && last_deployment.present?
  end

  def terminals
    project.deployment_platform.terminals(self) if has_terminals?
  end

  def has_metrics?
    prometheus_adapter&.can_query? && available?
  end

  def metrics
    prometheus_adapter.query(:environment, self) if has_metrics?
  end

  def additional_metrics(*args)
    return unless has_metrics?

    prometheus_adapter.query(:additional_metrics_environment, self, *args.map(&:to_f))
  end

  # rubocop: disable CodeReuse/ServiceClass
  def prometheus_adapter
    @prometheus_adapter ||= Prometheus::AdapterService.new(project, deployment_platform).prometheus_adapter
  end
  # rubocop: enable CodeReuse/ServiceClass

  def slug
    super.presence || generate_slug
  end

  # An environment name is not necessarily suitable for use in URLs, DNS
  # or other third-party contexts, so provide a slugified version. A slug has
  # the following properties:
  #   * contains only lowercase letters (a-z), numbers (0-9), and '-'
  #   * begins with a letter
  #   * has a maximum length of 24 bytes (OpenShift limitation)
  #   * cannot end with `-`
  def generate_slug
    # Lowercase letters and numbers only
    slugified = +name.to_s.downcase.gsub(/[^a-z0-9]/, '-')

    # Must start with a letter
    slugified = 'env-' + slugified unless LETTERS.cover?(slugified[0])

    # Repeated dashes are invalid (OpenShift limitation)
    slugified.gsub!(/\-+/, '-')

    # Maximum length: 24 characters (OpenShift limitation)
    slugified = slugified[0..23]

    # Cannot end with a dash (Kubernetes label limitation)
    slugified.chop! if slugified.end_with?('-')

    # Add a random suffix, shortening the current string if necessary, if it
    # has been slugified. This ensures uniqueness.
    if slugified != name
      slugified = slugified[0..16]
      slugified << '-' unless slugified.end_with?('-')
      slugified << random_suffix
    end

    self.slug = slugified
  end

  def external_url_for(path, commit_sha)
    return unless self.external_url

    public_path = project.public_path_for_source_path(path, commit_sha)
    return unless public_path

    [external_url, public_path].join('/')
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

  private

  # Slugifying a name may remove the uniqueness guarantee afforded by it being
  # based on name (which must be unique). To compensate, we add a random
  # 6-byte suffix in those circumstances. This is not *guaranteed* uniqueness,
  # but the chance of collisions is vanishingly small
  def random_suffix
    (0..5).map { SUFFIX_CHARS.sample }.join
  end
end

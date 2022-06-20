# frozen_string_literal: true

class Deployment < ApplicationRecord
  include AtomicInternalId
  include IidRoutes
  include AfterCommitQueue
  include UpdatedAtFilterable
  include Importable
  include Gitlab::Utils::StrongMemoize
  include FastDestroyAll

  StatusUpdateError = Class.new(StandardError)
  StatusSyncError = Class.new(StandardError)

  ARCHIVABLE_OFFSET = 50_000

  belongs_to :project, optional: false
  belongs_to :environment, optional: false
  belongs_to :cluster, class_name: 'Clusters::Cluster', optional: true
  belongs_to :user
  belongs_to :deployable, polymorphic: true, optional: true # rubocop:disable Cop/PolymorphicAssociations
  has_many :deployment_merge_requests

  has_many :merge_requests,
    through: :deployment_merge_requests

  has_one :deployment_cluster

  has_internal_id :iid, scope: :project, track_if: -> { !importing? }

  validates :sha, presence: true
  validates :ref, presence: true
  validate :valid_sha, on: :create
  validate :valid_ref, on: :create

  delegate :name, to: :environment, prefix: true
  delegate :kubernetes_namespace, to: :deployment_cluster, allow_nil: true

  scope :for_environment, -> (environment) { where(environment_id: environment) }
  scope :for_environment_name, -> (project, name) do
    where('deployments.environment_id = (?)',
      Environment.select(:id).where(project: project, name: name).limit(1))
  end

  scope :for_status, -> (status) { where(status: status) }
  scope :for_project, -> (project_id) { where(project_id: project_id) }
  scope :for_projects, -> (projects) { where(project: projects) }

  scope :visible, -> { where(status: VISIBLE_STATUSES) }
  scope :stoppable, -> { where.not(on_stop: nil).where.not(deployable_id: nil).success }
  scope :active, -> { where(status: %i[created running]) }
  scope :upcoming, -> { where(status: %i[blocked running]) }
  scope :older_than, -> (deployment) { where('deployments.id < ?', deployment.id) }
  scope :with_api_entity_associations, -> { preload({ deployable: { runner: [], tags: [], user: [], job_artifacts_archive: [] } }) }

  scope :finished_after, ->(date) { where('finished_at >= ?', date) }
  scope :finished_before, ->(date) { where('finished_at < ?', date) }

  scope :ordered, -> { order(finished_at: :desc) }

  VISIBLE_STATUSES = %i[running success failed canceled blocked].freeze
  FINISHED_STATUSES = %i[success failed canceled].freeze

  state_machine :status, initial: :created do
    event :run do
      transition created: :running
    end

    event :block do
      transition created: :blocked
    end

    event :unblock do
      transition blocked: :created
    end

    event :succeed do
      transition any - [:success] => :success
    end

    event :drop do
      transition any - [:failed] => :failed
    end

    event :cancel do
      transition any - [:canceled] => :canceled
    end

    event :skip do
      transition any - [:skipped] => :skipped
    end

    before_transition any => FINISHED_STATUSES do |deployment|
      deployment.finished_at = Time.current
    end

    after_transition any => :running do |deployment|
      next unless deployment.project.ci_forward_deployment_enabled?

      deployment.run_after_commit do
        Deployments::DropOlderDeploymentsWorker.perform_async(id)
      end
    end

    after_transition any => :running do |deployment|
      deployment.run_after_commit do
        Deployments::HooksWorker.perform_async(deployment_id: id, status_changed_at: Time.current)
      end
    end

    after_transition any => :success do |deployment|
      deployment.run_after_commit do
        Deployments::UpdateEnvironmentWorker.perform_async(id)
        Deployments::LinkMergeRequestWorker.perform_async(id)
        Deployments::ArchiveInProjectWorker.perform_async(deployment.project_id)
      end
    end

    after_transition any => FINISHED_STATUSES do |deployment|
      deployment.run_after_commit do
        Deployments::HooksWorker.perform_async(deployment_id: id, status_changed_at: Time.current)
      end
    end

    after_transition any => any - [:skipped] do |deployment, transition|
      next if transition.loopback?

      deployment.run_after_commit do
        next unless deployment.project.jira_subscription_exists?

        ::JiraConnect::SyncDeploymentsWorker.perform_async(id)
      end
    end
  end

  after_create unless: :importing? do |deployment|
    run_after_commit do
      next unless deployment.project.jira_subscription_exists?

      ::JiraConnect::SyncDeploymentsWorker.perform_async(deployment.id)
    end
  end

  enum status: {
    created: 0,
    running: 1,
    success: 2,
    failed: 3,
    canceled: 4,
    skipped: 5,
    blocked: 6
  }

  def self.archivables_in(project, limit:)
    start_iid = project.deployments.order(iid: :desc).limit(1)
      .select("(iid - #{ARCHIVABLE_OFFSET}) AS start_iid")

    project.deployments.preload(:environment).where('iid <= (?)', start_iid)
      .where(archived: false).limit(limit)
  end

  def self.last_for_environment(environment)
    ids = self
      .for_environment(environment)
      .select('MAX(id) AS id')
      .group(:environment_id)
      .map(&:id)
    find(ids)
  end

  def self.distinct_on_environment
    order('environment_id, deployments.id DESC')
      .select('DISTINCT ON (environment_id) deployments.*')
  end

  def self.find_successful_deployment!(iid)
    success.find_by!(iid: iid)
  end

  # It should be used with caution especially on chaining.
  # Fetching any unbounded or large intermediate dataset could lead to loading too many IDs into memory.
  # See: https://docs.gitlab.com/ee/development/database/multiple_databases.html#use-disable_joins-for-has_one-or-has_many-through-relations
  # For safety we default limit to fetch not more than 1000 records.
  def self.builds(limit = 1000)
    deployable_ids = where.not(deployable_id: nil).limit(limit).pluck(:deployable_id)

    Ci::Build.where(id: deployable_ids)
  end

  class << self
    ##
    # FastDestroyAll concerns
    def begin_fast_destroy
      preload(:project).find_each.map do |deployment|
        [deployment.project, deployment.ref_path]
      end
    end

    ##
    # FastDestroyAll concerns
    def finalize_fast_destroy(params)
      by_project = params.group_by(&:shift)

      by_project.each do |project, ref_paths|
        project.repository.delete_refs(*ref_paths.flatten)
      end
    end

    def latest_for_sha(sha)
      where(sha: sha).order(id: :desc).take
    end
  end

  def commit
    @commit ||= project.commit(sha)
  end

  def commit_title
    commit.try(:title)
  end

  def short_sha
    Commit.truncate_sha(sha)
  end

  def execute_hooks(status_changed_at)
    deployment_data = Gitlab::DataBuilder::Deployment.build(self, status_changed_at)
    project.execute_hooks(deployment_data, :deployment_hooks)
    project.execute_integrations(deployment_data, :deployment_hooks)
  end

  def last?
    self == environment.last_deployment
  end

  def create_ref
    project.repository.create_ref(sha, ref_path)
  end

  def invalidate_cache
    environment.expire_etag_cache
  end

  def manual_actions
    @manual_actions ||= deployable.try(:other_manual_actions)
  end

  def scheduled_actions
    @scheduled_actions ||= deployable.try(:other_scheduled_actions)
  end

  def playable_build
    strong_memoize(:playable_build) do
      deployable.try(:playable?) ? deployable : nil
    end
  end

  def includes_commit?(ancestor_sha)
    return false unless sha

    project.repository.ancestor?(ancestor_sha, sha)
  end

  def update_merge_request_metrics!
    return unless environment.production? && success?

    merge_requests = project.merge_requests
                     .joins(:metrics)
                     .where(target_branch: self.ref, merge_request_metrics: { first_deployed_to_production_at: nil })
                     .where("merge_request_metrics.merged_at <= ?", finished_at)

    if previous_deployment
      merge_requests = merge_requests.where("merge_request_metrics.merged_at >= ?", previous_deployment.finished_at)
    end

    MergeRequest::Metrics
      .where(merge_request_id: merge_requests.select(:id), first_deployed_to_production_at: nil)
      .update_all(first_deployed_to_production_at: finished_at)
  end

  def previous_deployment
    @previous_deployment ||=
      self.class.for_environment(environment_id)
        .success
        .where('id < ?', id)
        .order(id: :desc)
        .take
  end

  def stop_action
    return unless on_stop.present?
    return unless manual_actions

    @stop_action ||= manual_actions.find { |action| action.name == self.on_stop }
  end

  def deployed_at
    return unless success?

    finished_at
  end

  def formatted_deployment_time
    deployed_at&.to_time&.in_time_zone&.to_s(:medium)
  end

  def deployed_by
    # We use deployable's user if available because Ci::PlayBuildService
    # does not update the deployment's user, just the one for the deployable.
    # TODO: use deployment's user once https://gitlab.com/gitlab-org/gitlab-foss/issues/66442
    # is completed.
    deployable&.user || user
  end

  def link_merge_requests(relation)
    # NOTE: relation.select will perform column deduplication,
    # when id == environment_id it will outputs 2 columns instead of 3
    # i.e.:
    # MergeRequest.select(1, 2).to_sql #=> SELECT 1, 2 FROM "merge_requests"
    # MergeRequest.select(1, 1).to_sql #=> SELECT 1 FROM "merge_requests"
    select = relation.select('merge_requests.id',
                             "#{id} as deployment_id",
                             "#{environment_id} as environment_id").to_sql

    # We don't use `ApplicationRecord.legacy_bulk_insert` here so that we don't need to
    # first pluck lots of IDs into memory.
    #
    # We also ignore any duplicates so this method can be called multiple times
    # for the same deployment, only inserting any missing merge requests.
    DeploymentMergeRequest.connection.execute(<<~SQL)
      INSERT INTO #{DeploymentMergeRequest.table_name}
      (merge_request_id, deployment_id, environment_id)
      #{select}
      ON CONFLICT DO NOTHING
    SQL
  end

  # Changes the status of a deployment and triggers the corresponding state
  # machine events.
  def update_status(status)
    update_status!(status)
  rescue StandardError => e
    Gitlab::ErrorTracking.track_exception(
      StatusUpdateError.new(e.message), deployment_id: self.id)

    false
  end

  def sync_status_with(build)
    return false unless ::Deployment.statuses.include?(build.status)
    return false if build.created? || build.status == self.status

    update_status!(build.status)
  rescue StandardError => e
    Gitlab::ErrorTracking.track_exception(
      StatusSyncError.new(e.message), deployment_id: self.id, build_id: build.id)

    false
  end

  def valid_sha
    return if project&.commit(sha)

    errors.add(:sha, _('The commit does not exist'))
  end

  def valid_ref
    return if project&.commit(ref)

    errors.add(:ref, _('The branch or tag does not exist'))
  end

  def ref_path
    File.join(environment.ref_path, 'deployments', iid.to_s)
  end

  def equal_to?(params)
    ref == params[:ref] &&
      tag == params[:tag] &&
      sha == params[:sha] &&
      status == params[:status]
  end

  def tier_in_yaml
    return unless deployable

    deployable.environment_deployment_tier
  end

  private

  def update_status!(status)
    case status
    when 'running'
      run!
    when 'success'
      succeed!
    when 'failed'
      drop!
    when 'canceled'
      cancel!
    when 'skipped'
      skip!
    when 'blocked'
      block!
    else
      raise ArgumentError, "The status #{status.inspect} is invalid"
    end
  end
end

Deployment.prepend_mod_with('Deployment')

# frozen_string_literal: true

class CommitStatus < Ci::ApplicationRecord
  include Ci::HasStatus
  include Importable
  include AfterCommitQueue
  include Presentable
  include EnumWithNil
  include BulkInsertableAssociations
  include TaggableQueries
  include IgnorableColumns

  self.table_name = 'ci_builds'

  ignore_column :token, remove_with: '15.4', remove_after: '2022-08-22'

  belongs_to :user
  belongs_to :project
  belongs_to :pipeline, class_name: 'Ci::Pipeline', foreign_key: :commit_id
  belongs_to :auto_canceled_by, class_name: 'Ci::Pipeline'

  has_many :needs, class_name: 'Ci::BuildNeed', foreign_key: :build_id, inverse_of: :build

  enum scheduling_type: { stage: 0, dag: 1 }, _prefix: true

  delegate :commit, to: :pipeline
  delegate :sha, :short_sha, :before_sha, to: :pipeline

  validates :pipeline, presence: true, unless: :importing?
  validates :name, presence: true, unless: :importing?

  alias_attribute :author, :user
  alias_attribute :pipeline_id, :commit_id

  scope :failed_but_allowed, -> do
    where(allow_failure: true, status: [:failed, :canceled])
  end

  scope :order_id_desc, -> { order(id: :desc) }

  scope :exclude_ignored, -> do
    # We want to ignore failed but allowed to fail jobs.
    #
    # TODO, we also skip ignored optional manual actions.
    where("allow_failure = ? OR status IN (?)",
      false, all_state_names - [:failed, :canceled, :manual])
  end

  scope :latest, -> { where(retried: [false, nil]) }
  scope :retried, -> { where(retried: true) }
  scope :ordered, -> { order(:name) }
  scope :ordered_by_stage, -> { order(stage_idx: :asc) }
  scope :latest_ordered, -> { latest.ordered.includes(project: :namespace) }
  scope :retried_ordered, -> { retried.order(name: :asc, id: :desc).includes(project: :namespace) }
  scope :ordered_by_pipeline, -> { order(pipeline_id: :asc) }
  scope :before_stage, -> (index) { where('stage_idx < ?', index) }
  scope :for_stage, -> (index) { where(stage_idx: index) }
  scope :after_stage, -> (index) { where('stage_idx > ?', index) }
  scope :for_project, -> (project_id) { where(project_id: project_id) }
  scope :for_ref, -> (ref) { where(ref: ref) }
  scope :by_name, -> (name) { where(name: name) }
  scope :in_pipelines, ->(pipelines) { where(pipeline: pipelines) }
  scope :with_pipeline, -> { joins(:pipeline) }
  scope :updated_at_before, ->(date) { where('ci_builds.updated_at < ?', date) }
  scope :created_at_before, ->(date) { where('ci_builds.created_at < ?', date) }
  scope :scheduled_at_before, ->(date) {
    where('ci_builds.scheduled_at IS NOT NULL AND ci_builds.scheduled_at < ?', date)
  }

  # The scope applies `pluck` to split the queries. Use with care.
  scope :for_project_paths, -> (paths) do
    # Pluck is used to split this query. Splitting the query is required for database decomposition for `ci_*` tables.
    # https://docs.gitlab.com/ee/development/database/transaction_guidelines.html#database-decomposition-and-sharding
    project_ids = Project.where_full_path_in(Array(paths)).pluck(:id)

    for_project(project_ids)
  end

  scope :with_preloads, -> do
    preload(:project, :user)
  end

  scope :with_project_preload, -> do
    preload(project: :namespace)
  end

  scope :match_id_and_lock_version, -> (items) do
    # it expects that items are an array of attributes to match
    # each hash needs to have `id` and `lock_version`
    or_conditions = items.inject(none) do |relation, item|
      match = CommitStatus.default_scoped.where(item.slice(:id, :lock_version))

      relation.or(match)
    end

    merge(or_conditions)
  end

  # We use `Enums::Ci::CommitStatus.failure_reasons` here so that EE can more easily
  # extend this `Hash` with new values.
  enum_with_nil failure_reason: Enums::Ci::CommitStatus.failure_reasons

  default_value_for :retried, false

  ##
  # We still create some CommitStatuses outside of CreatePipelineService.
  #
  # These are pages deployments and external statuses.
  #
  before_create unless: :importing? do
    # rubocop: disable CodeReuse/ServiceClass
    Ci::EnsureStageService.new(project, user).execute(self) do |stage|
      self.run_after_commit { StageUpdateWorker.perform_async(stage.id) }
    end
    # rubocop: enable CodeReuse/ServiceClass
  end

  before_save if: :status_changed?, unless: :importing? do
    # we mark `processed` as always changed:
    # another process might change its value and our object
    # will not be refreshed to pick the change
    self.processed_will_change!

    if latest?
      self.processed = false # force refresh of all dependent ones
    elsif retried?
      self.processed = true # retried are considered to be already processed
    end
  end

  state_machine :status do
    event :process do
      transition [:skipped, :manual] => :created
    end

    event :enqueue do
      # A CommitStatus will never have prerequisites, but this event
      # is shared by Ci::Build, which cannot progress unless prerequisites
      # are satisfied.
      transition [:created, :skipped, :manual, :scheduled] => :pending, if: :all_met_to_become_pending?
    end

    event :run do
      transition pending: :running
    end

    event :skip do
      transition [:created, :waiting_for_resource, :preparing, :pending] => :skipped
    end

    event :drop do
      transition [:created, :waiting_for_resource, :preparing, :pending, :running, :manual, :scheduled] => :failed
    end

    event :success do
      transition [:created, :waiting_for_resource, :preparing, :pending, :running] => :success
    end

    event :cancel do
      transition [:created, :waiting_for_resource, :preparing, :pending, :running, :manual, :scheduled] => :canceled
    end

    before_transition [:created, :waiting_for_resource, :preparing, :skipped, :manual, :scheduled] => :pending do |commit_status|
      commit_status.queued_at = Time.current
    end

    before_transition [:created, :preparing, :pending] => :running do |commit_status|
      commit_status.started_at = Time.current
    end

    before_transition any => [:success, :failed, :canceled] do |commit_status|
      commit_status.finished_at = Time.current
    end

    before_transition any => :failed do |commit_status, transition|
      reason = ::Gitlab::Ci::Build::Status::Reason
        .fabricate(commit_status, transition.args.first)

      commit_status.failure_reason = reason.failure_reason_enum
      commit_status.allow_failure = true if reason.force_allow_failure?
    end

    before_transition [:skipped, :manual] => :created do |commit_status, transition|
      transition.args.first.try do |user|
        commit_status.user = user
      end
    end

    after_transition do |commit_status, transition|
      next if transition.loopback?
      next if commit_status.processed?
      next unless commit_status.project

      last_arg = transition.args.last
      transition_options = last_arg.is_a?(Hash) && last_arg.extractable_options? ? last_arg : {}

      commit_status.run_after_commit do
        PipelineProcessWorker.perform_async(pipeline_id) unless transition_options[:skip_pipeline_processing]

        expire_etag_cache!
      end
    end

    after_transition any => :failed do |commit_status|
      commit_status.run_after_commit do
        ::Gitlab::Ci::Pipeline::Metrics.job_failure_reason_counter.increment(reason: commit_status.failure_reason)
      end
    end
  end

  def self.names
    select(:name)
  end

  def self.update_as_processed!
    # Marks items as processed
    # we do not increase `lock_version`, as we are the one
    # holding given lock_version (Optimisitc Locking)
    update_all(processed: true)
  end

  def self.locking_enabled?
    false
  end

  def locking_enabled?
    will_save_change_to_status?
  end

  def group_name
    # [\b\s:] -> whitespace or column
    # (\[.*\])|(\d+[\s:\/\\]+\d+) -> variables/matrix or parallel-jobs numbers
    # {1,3} -> number of times that matches the variables/matrix or parallel-jobs numbers
    #          we limit this to 3 because of possible abuse
    regex = %r{([\b\s:]+((\[.*\])|(\d+[\s:\/\\]+\d+))){1,3}\s*\z}

    name.to_s.sub(regex, '').strip
  end

  def failed_but_allowed?
    allow_failure? && (failed? || canceled?)
  end

  # Time spent running.
  def duration
    calculate_duration(started_at, finished_at)
  end

  # Time spent in the pending state.
  def queued_duration
    calculate_duration(queued_at, started_at)
  end

  def latest?
    !retried?
  end

  def playable?
    false
  end

  def retryable?
    false
  end

  def cancelable?
    false
  end

  def archived?
    false
  end

  def stuck?
    false
  end

  def has_trace?
    false
  end

  def all_met_to_become_pending?
    true
  end

  def auto_canceled?
    canceled? && auto_canceled_by_id?
  end

  def detailed_status(current_user)
    Gitlab::Ci::Status::Factory
      .new(self, current_user)
      .fabricate!
  end

  def sortable_name
    name.to_s.split(/(\d+)/).map do |v|
      v =~ /\d+/ ? v.to_i : v
    end
  end

  def recoverable?
    failed? && !unrecoverable_failure?
  end

  def update_older_statuses_retried!
    pipeline
      .statuses
      .latest
      .where(name: name)
      .where.not(id: id)
      .update_all(retried: true, processed: true)
  end

  def expire_etag_cache!
    job_path = Gitlab::Routing.url_helpers.project_build_path(project, id, format: :json)

    Gitlab::EtagCaching::Store.new.touch(job_path)
  end

  private

  def unrecoverable_failure?
    script_failure? || missing_dependency_failure? || archived_failure? || scheduler_failure? || data_integrity_failure?
  end
end

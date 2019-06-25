# frozen_string_literal: true

module Ci
  class Pipeline < ApplicationRecord
    extend Gitlab::Ci::Model
    include HasStatus
    include Importable
    include AfterCommitQueue
    include Presentable
    include Gitlab::OptimisticLocking
    include Gitlab::Utils::StrongMemoize
    include AtomicInternalId
    include EnumWithNil
    include HasRef
    include ShaAttribute
    include FromUnion

    sha_attribute :source_sha
    sha_attribute :target_sha

    belongs_to :project, inverse_of: :all_pipelines
    belongs_to :user
    belongs_to :auto_canceled_by, class_name: 'Ci::Pipeline'
    belongs_to :pipeline_schedule, class_name: 'Ci::PipelineSchedule'
    belongs_to :merge_request, class_name: 'MergeRequest'

    has_internal_id :iid, scope: :project, presence: false, init: ->(s) do
      s&.project&.all_pipelines&.maximum(:iid) || s&.project&.all_pipelines&.count
    end

    has_many :stages, -> { order(position: :asc) }, inverse_of: :pipeline
    has_many :statuses, class_name: 'CommitStatus', foreign_key: :commit_id, inverse_of: :pipeline
    has_many :processables, -> { processables },
             class_name: 'CommitStatus', foreign_key: :commit_id, inverse_of: :pipeline
    has_many :builds, foreign_key: :commit_id, inverse_of: :pipeline
    has_many :trigger_requests, dependent: :destroy, foreign_key: :commit_id # rubocop:disable Cop/ActiveRecordDependent
    has_many :variables, class_name: 'Ci::PipelineVariable'
    has_many :deployments, through: :builds
    has_many :environments, -> { distinct }, through: :deployments

    # Merge requests for which the current pipeline is running against
    # the merge request's latest commit.
    has_many :merge_requests_as_head_pipeline, foreign_key: "head_pipeline_id", class_name: 'MergeRequest'

    has_many :pending_builds, -> { pending }, foreign_key: :commit_id, class_name: 'Ci::Build'
    has_many :retryable_builds, -> { latest.failed_or_canceled.includes(:project) }, foreign_key: :commit_id, class_name: 'Ci::Build'
    has_many :cancelable_statuses, -> { cancelable }, foreign_key: :commit_id, class_name: 'CommitStatus'
    has_many :manual_actions, -> { latest.manual_actions.includes(:project) }, foreign_key: :commit_id, class_name: 'Ci::Build'
    has_many :scheduled_actions, -> { latest.scheduled_actions.includes(:project) }, foreign_key: :commit_id, class_name: 'Ci::Build'
    has_many :artifacts, -> { latest.with_artifacts_not_expired.includes(:project) }, foreign_key: :commit_id, class_name: 'Ci::Build'

    has_many :auto_canceled_pipelines, class_name: 'Ci::Pipeline', foreign_key: 'auto_canceled_by_id'
    has_many :auto_canceled_jobs, class_name: 'CommitStatus', foreign_key: 'auto_canceled_by_id'

    has_one :chat_data, class_name: 'Ci::PipelineChatData'

    accepts_nested_attributes_for :variables, reject_if: :persisted?

    delegate :id, to: :project, prefix: true
    delegate :full_path, to: :project, prefix: true

    validates :sha, presence: { unless: :importing? }
    validates :ref, presence: { unless: :importing? }
    validates :merge_request, presence: { if: :merge_request_event? }
    validates :merge_request, absence: { unless: :merge_request_event? }
    validates :tag, inclusion: { in: [false], if: :merge_request_event? }
    validates :status, presence: { unless: :importing? }
    validate :valid_commit_sha, unless: :importing?
    validates :source, exclusion: { in: %w(unknown), unless: :importing? }, on: :create

    after_create :keep_around_commits, unless: :importing?

    # We use `Ci::PipelineEnums.sources` here so that EE can more easily extend
    # this `Hash` with new values.
    enum_with_nil source: ::Ci::PipelineEnums.sources

    enum_with_nil config_source: ::Ci::PipelineEnums.config_sources

    # We use `Ci::PipelineEnums.failure_reasons` here so that EE can more easily
    # extend this `Hash` with new values.
    enum failure_reason: ::Ci::PipelineEnums.failure_reasons

    state_machine :status, initial: :created do
      event :enqueue do
        transition [:created, :preparing, :skipped, :scheduled] => :pending
        transition [:success, :failed, :canceled] => :running
      end

      event :prepare do
        transition any - [:preparing] => :preparing
      end

      event :run do
        transition any - [:running] => :running
      end

      event :skip do
        transition any - [:skipped] => :skipped
      end

      event :drop do
        transition any - [:failed] => :failed
      end

      event :succeed do
        transition any - [:success] => :success
      end

      event :cancel do
        transition any - [:canceled] => :canceled
      end

      event :block do
        transition any - [:manual] => :manual
      end

      event :delay do
        transition any - [:scheduled] => :scheduled
      end

      # IMPORTANT
      # Do not add any operations to this state_machine
      # Create a separate worker for each new operation

      before_transition [:created, :preparing, :pending] => :running do |pipeline|
        pipeline.started_at = Time.now
      end

      before_transition any => [:success, :failed, :canceled] do |pipeline|
        pipeline.finished_at = Time.now
        pipeline.update_duration
      end

      before_transition any => [:manual] do |pipeline|
        pipeline.update_duration
      end

      before_transition canceled: any - [:canceled] do |pipeline|
        pipeline.auto_canceled_by = nil
      end

      before_transition any => :failed do |pipeline, transition|
        transition.args.first.try do |reason|
          pipeline.failure_reason = reason
        end
      end

      after_transition [:created, :preparing, :pending] => :running do |pipeline|
        pipeline.run_after_commit { PipelineMetricsWorker.perform_async(pipeline.id) }
      end

      after_transition any => [:success] do |pipeline|
        pipeline.run_after_commit { PipelineMetricsWorker.perform_async(pipeline.id) }
      end

      after_transition [:created, :preparing, :pending, :running] => :success do |pipeline|
        pipeline.run_after_commit { PipelineSuccessWorker.perform_async(pipeline.id) }
      end

      after_transition do |pipeline, transition|
        next if transition.loopback?

        pipeline.run_after_commit do
          PipelineHooksWorker.perform_async(pipeline.id)
          ExpirePipelineCacheWorker.perform_async(pipeline.id)
        end
      end

      after_transition any => ::Ci::Pipeline.completed_statuses do |pipeline|
        pipeline.run_after_commit do
          pipeline.all_merge_requests.each do |merge_request|
            next unless merge_request.auto_merge_enabled?

            AutoMergeProcessWorker.perform_async(merge_request.id)
          end
        end
      end

      after_transition any => [:success, :failed] do |pipeline|
        pipeline.run_after_commit do
          PipelineNotificationWorker.perform_async(pipeline.id)
        end
      end

      after_transition any => [:failed] do |pipeline|
        next unless pipeline.auto_devops_source?

        pipeline.run_after_commit { AutoDevops::DisableWorker.perform_async(pipeline.id) }
      end
    end

    scope :internal, -> { where(source: internal_sources) }
    scope :ci_sources, -> { where(config_source: ci_sources_values) }

    scope :sort_by_merge_request_pipelines, -> do
      sql = 'CASE ci_pipelines.source WHEN (?) THEN 0 ELSE 1 END, ci_pipelines.id DESC'
      query = ApplicationRecord.send(:sanitize_sql_array, [sql, sources[:merge_request_event]]) # rubocop:disable GitlabSecurity/PublicSend

      order(query)
    end

    scope :for_user, -> (user) { where(user: user) }
    scope :for_sha, -> (sha) { where(sha: sha) }
    scope :for_source_sha, -> (source_sha) { where(source_sha: source_sha) }
    scope :for_sha_or_source_sha, -> (sha) { for_sha(sha).or(for_source_sha(sha)) }

    scope :triggered_by_merge_request, -> (merge_request) do
      where(source: :merge_request_event, merge_request: merge_request)
    end

    scope :detached_merge_request_pipelines, -> (merge_request, sha) do
      triggered_by_merge_request(merge_request).for_sha(sha)
    end

    scope :merge_request_pipelines, -> (merge_request, source_sha) do
      triggered_by_merge_request(merge_request).for_source_sha(source_sha)
    end

    scope :triggered_for_branch, -> (ref) do
      where(source: branch_pipeline_sources).where(ref: ref, tag: false)
    end

    scope :with_reports, -> (reports_scope) do
      where('EXISTS (?)', ::Ci::Build.latest.with_reports(reports_scope).where('ci_pipelines.id=ci_builds.commit_id').select(1))
    end

    # Returns the pipelines in descending order (= newest first), optionally
    # limited to a number of references.
    #
    # ref - The name (or names) of the branch(es)/tag(s) to limit the list of
    #       pipelines to.
    # limit - This limits a backlog search, default to 100.
    def self.newest_first(ref: nil, limit: 100)
      relation = order(id: :desc)
      relation = relation.where(ref: ref) if ref

      if limit
        ids = relation.limit(limit).select(:id)
        # MySQL does not support limit in subquery
        ids = ids.pluck(:id) if Gitlab::Database.mysql?
        relation = relation.where(id: ids)
      end

      relation
    end

    def self.latest_status(ref = nil)
      newest_first(ref: ref).pluck(:status).first
    end

    def self.latest_successful_for(ref)
      newest_first(ref: ref).success.take
    end

    def self.latest_successful_for_refs(refs)
      relation = newest_first(ref: refs).success

      relation.each_with_object({}) do |pipeline, hash|
        hash[pipeline.ref] ||= pipeline
      end
    end

    # Returns a Hash containing the latest pipeline status for every given
    # commit.
    #
    # The keys of this Hash are the commit SHAs, the values the statuses.
    #
    # commits - The list of commit SHAs to get the status for.
    # ref - The ref to scope the data to (e.g. "master"). If the ref is not
    #       given we simply get the latest status for the commits, regardless
    #       of what refs their pipelines belong to.
    def self.latest_status_per_commit(commits, ref = nil)
      p1 = arel_table
      p2 = arel_table.alias

      # This LEFT JOIN will filter out all but the newest row for every
      # combination of (project_id, sha) or (project_id, sha, ref) if a ref is
      # given.
      cond = p1[:sha].eq(p2[:sha])
        .and(p1[:project_id].eq(p2[:project_id]))
        .and(p1[:id].lt(p2[:id]))

      cond = cond.and(p1[:ref].eq(p2[:ref])) if ref
      join = p1.join(p2, Arel::Nodes::OuterJoin).on(cond)

      relation = select(:sha, :status)
        .where(sha: commits)
        .where(p2[:id].eq(nil))
        .joins(join.join_sources)

      relation = relation.where(ref: ref) if ref

      relation.each_with_object({}) do |row, hash|
        hash[row[:sha]] = row[:status]
      end
    end

    def self.latest_successful_ids_per_project
      success.group(:project_id).select('max(id) as id')
    end

    def self.truncate_sha(sha)
      sha[0...8]
    end

    def self.total_duration
      where.not(duration: nil).sum(:duration)
    end

    def self.internal_sources
      sources.reject { |source| source == "external" }.values
    end

    def self.branch_pipeline_sources
      @branch_pipeline_sources ||= sources.reject { |source| source == 'merge_request_event' }.values
    end

    def self.ci_sources_values
      config_sources.values_at(:repository_source, :auto_devops_source, :unknown_source)
    end

    def stages_count
      statuses.select(:stage).distinct.count
    end

    def total_size
      statuses.count(:id)
    end

    def stages_names
      statuses.order(:stage_idx).distinct
        .pluck(:stage, :stage_idx).map(&:first)
    end

    def legacy_stage(name)
      stage = Ci::LegacyStage.new(self, name: name)
      stage unless stage.statuses_count.zero?
    end

    def ref_exists?
      project.repository.ref_exists?(git_ref)
    rescue Gitlab::Git::Repository::NoRepository
      false
    end

    ##
    # TODO We do not completely switch to persisted stages because of
    # race conditions with setting statuses gitlab-ce#23257.
    #
    def ordered_stages
      return legacy_stages unless complete?

      if Feature.enabled?('ci_pipeline_persisted_stages', default_enabled: true)
        stages
      else
        legacy_stages
      end
    end

    def legacy_stages
      # TODO, this needs refactoring, see gitlab-ce#26481.

      stages_query = statuses
        .group('stage').select(:stage).order('max(stage_idx)')

      status_sql = statuses.latest.where('stage=sg.stage').status_sql

      warnings_sql = statuses.latest.select('COUNT(*)')
        .where('stage=sg.stage').failed_but_allowed.to_sql

      stages_with_statuses = CommitStatus.from(stages_query, :sg)
        .pluck('sg.stage', status_sql, "(#{warnings_sql})")

      stages_with_statuses.map do |stage|
        Ci::LegacyStage.new(self, Hash[%i[name status warnings].zip(stage)])
      end
    end

    def valid_commit_sha
      if self.sha == Gitlab::Git::BLANK_SHA
        self.errors.add(:sha, " cant be 00000000 (branch removal)")
      end
    end

    def git_author_name
      strong_memoize(:git_author_name) do
        commit.try(:author_name)
      end
    end

    def git_author_email
      strong_memoize(:git_author_email) do
        commit.try(:author_email)
      end
    end

    def git_commit_message
      strong_memoize(:git_commit_message) do
        commit.try(:message)
      end
    end

    def git_commit_title
      strong_memoize(:git_commit_title) do
        commit.try(:title)
      end
    end

    def git_commit_full_title
      strong_memoize(:git_commit_full_title) do
        commit.try(:full_title)
      end
    end

    def git_commit_description
      strong_memoize(:git_commit_description) do
        commit.try(:description)
      end
    end

    def short_sha
      Ci::Pipeline.truncate_sha(sha)
    end

    # NOTE: This is loaded lazily and will never be nil, even if the commit
    # cannot be found.
    #
    # Use constructs like: `pipeline.commit.present?`
    def commit
      @commit ||= Commit.lazy(project, sha)
    end

    def stuck?
      pending_builds.any?(&:stuck?)
    end

    def retryable?
      retryable_builds.any?
    end

    def cancelable?
      cancelable_statuses.any?
    end

    def auto_canceled?
      canceled? && auto_canceled_by_id?
    end

    def cancel_running
      retry_optimistic_lock(cancelable_statuses) do |cancelable|
        cancelable.find_each do |job|
          yield(job) if block_given?
          job.cancel
        end
      end
    end

    def auto_cancel_running(pipeline)
      update(auto_canceled_by: pipeline)

      cancel_running do |job|
        job.auto_canceled_by = pipeline
      end
    end

    # rubocop: disable CodeReuse/ServiceClass
    def retry_failed(current_user)
      Ci::RetryPipelineService.new(project, current_user)
        .execute(self)
    end
    # rubocop: enable CodeReuse/ServiceClass

    def mark_as_processable_after_stage(stage_idx)
      builds.skipped.after_stage(stage_idx).find_each(&:process)
    end

    def latest?
      return false unless git_ref && commit.present?

      project.commit(git_ref) == commit
    end

    def retried
      @retried ||= (statuses.order(id: :desc) - statuses.latest)
    end

    def coverage
      coverage_array = statuses.latest.map(&:coverage).compact
      if coverage_array.size >= 1
        '%.2f' % (coverage_array.reduce(:+) / coverage_array.size)
      end
    end

    def stage_seeds
      return [] unless config_processor

      strong_memoize(:stage_seeds) do
        seeds = config_processor.stages_attributes.map do |attributes|
          Gitlab::Ci::Pipeline::Seed::Stage.new(self, attributes)
        end

        seeds.select(&:included?)
      end
    end

    def seeds_size
      stage_seeds.sum(&:size)
    end

    def has_kubernetes_active?
      project.deployment_platform&.active?
    end

    def has_warnings?
      number_of_warnings.positive?
    end

    def number_of_warnings
      BatchLoader.for(id).batch(default_value: 0) do |pipeline_ids, loader|
        ::Ci::Build.where(commit_id: pipeline_ids)
          .latest
          .failed_but_allowed
          .group(:commit_id)
          .count
          .each { |id, amount| loader.call(id, amount) }
      end
    end

    def set_config_source
      if ci_yaml_from_repo
        self.config_source = :repository_source
      elsif implied_ci_yaml_file
        self.config_source = :auto_devops_source
      end
    end

    ##
    # TODO, setting yaml_errors should be moved to the pipeline creation chain.
    #
    def config_processor
      return unless ci_yaml_file
      return @config_processor if defined?(@config_processor)

      @config_processor ||= begin
        ::Gitlab::Ci::YamlProcessor.new(ci_yaml_file, { project: project, sha: sha, user: user })
      rescue Gitlab::Ci::YamlProcessor::ValidationError => e
        self.yaml_errors = e.message
        nil
      rescue
        self.yaml_errors = 'Undefined error'
        nil
      end
    end

    def ci_yaml_file_path
      return unless repository_source? || unknown_source?

      if project.ci_config_path.blank?
        '.gitlab-ci.yml'
      else
        project.ci_config_path
      end
    end

    def ci_yaml_file
      return @ci_yaml_file if defined?(@ci_yaml_file)

      @ci_yaml_file =
        if auto_devops_source?
          implied_ci_yaml_file
        else
          ci_yaml_from_repo
        end

      if @ci_yaml_file
        @ci_yaml_file
      else
        self.yaml_errors = "Failed to load CI/CD config file for #{sha}"
        nil
      end
    end

    def has_yaml_errors?
      yaml_errors.present?
    end

    # Manually set the notes for a Ci::Pipeline
    # There is no ActiveRecord relation between Ci::Pipeline and notes
    # as they are related to a commit sha. This method helps importing
    # them using the +Gitlab::ImportExport::RelationFactory+ class.
    def notes=(notes)
      notes.each do |note|
        note[:id] = nil
        note[:commit_id] = sha
        note[:noteable_id] = self['id']
        note.save!
      end
    end

    def notes
      project.notes.for_commit_id(sha)
    end

    # rubocop: disable CodeReuse/ServiceClass
    def process!
      Ci::ProcessPipelineService.new(project, user).execute(self)
    end
    # rubocop: enable CodeReuse/ServiceClass

    def update_status
      retry_optimistic_lock(self) do
        case latest_builds_status.to_s
        when 'created' then nil
        when 'preparing' then prepare
        when 'pending' then enqueue
        when 'running' then run
        when 'success' then succeed
        when 'failed' then drop
        when 'canceled' then cancel
        when 'skipped' then skip
        when 'manual' then block
        when 'scheduled' then delay
        else
          raise HasStatus::UnknownStatusError,
                "Unknown status `#{latest_builds_status}`"
        end
      end
    end

    def protected_ref?
      strong_memoize(:protected_ref) { project.protected_for?(git_ref) }
    end

    def legacy_trigger
      strong_memoize(:legacy_trigger) { trigger_requests.first }
    end

    def persisted_variables
      Gitlab::Ci::Variables::Collection.new.tap do |variables|
        break variables unless persisted?

        variables.append(key: 'CI_PIPELINE_ID', value: id.to_s)
        variables.append(key: 'CI_PIPELINE_URL', value: Gitlab::Routing.url_helpers.project_pipeline_url(project, self))
      end
    end

    def predefined_variables
      Gitlab::Ci::Variables::Collection.new.tap do |variables|
        variables.append(key: 'CI_PIPELINE_IID', value: iid.to_s)
        variables.append(key: 'CI_CONFIG_PATH', value: ci_yaml_file_path)
        variables.append(key: 'CI_PIPELINE_SOURCE', value: source.to_s)
        variables.append(key: 'CI_COMMIT_MESSAGE', value: git_commit_message.to_s)
        variables.append(key: 'CI_COMMIT_TITLE', value: git_commit_full_title.to_s)
        variables.append(key: 'CI_COMMIT_DESCRIPTION', value: git_commit_description.to_s)
        variables.append(key: 'CI_COMMIT_REF_PROTECTED', value: (!!protected_ref?).to_s)

        if merge_request_event? && merge_request
          variables.append(key: 'CI_MERGE_REQUEST_SOURCE_BRANCH_SHA', value: source_sha.to_s)
          variables.append(key: 'CI_MERGE_REQUEST_TARGET_BRANCH_SHA', value: target_sha.to_s)
          variables.concat(merge_request.predefined_variables)
        end
      end
    end

    def queued_duration
      return unless started_at

      seconds = (started_at - created_at).to_i
      seconds unless seconds.zero?
    end

    def update_duration
      return unless started_at

      self.duration = Gitlab::Ci::Pipeline::Duration.from_pipeline(self)
    end

    def execute_hooks
      data = pipeline_data
      project.execute_hooks(data, :pipeline_hooks)
      project.execute_services(data, :pipeline_hooks)
    end

    # All the merge requests for which the current pipeline runs/ran against
    def all_merge_requests
      @all_merge_requests ||=
        if merge_request_event?
          MergeRequest.where(id: merge_request_id)
        else
          MergeRequest.where(source_project_id: project_id, source_branch: ref)
        end
    end

    def detailed_status(current_user)
      Gitlab::Ci::Status::Pipeline::Factory
        .new(self, current_user)
        .fabricate!
    end

    def latest_builds_with_artifacts
      # We purposely cast the builds to an Array here. Because we always use the
      # rows if there are more than 0 this prevents us from having to run two
      # queries: one to get the count and one to get the rows.
      @latest_builds_with_artifacts ||= builds.latest.with_artifacts_not_expired.to_a
    end

    def has_reports?(reports_scope)
      complete? && builds.latest.with_reports(reports_scope).exists?
    end

    def test_reports
      Gitlab::Ci::Reports::TestReports.new.tap do |test_reports|
        builds.latest.with_reports(Ci::JobArtifact.test_reports).each do |build|
          build.collect_test_reports!(test_reports)
        end
      end
    end

    def branch_updated?
      strong_memoize(:branch_updated) do
        push_details.branch_updated?
      end
    end

    # Returns the modified paths.
    #
    # The returned value is
    # * Array: List of modified paths that should be evaluated
    # * nil: Modified path can not be evaluated
    def modified_paths
      strong_memoize(:modified_paths) do
        if merge_request_event?
          merge_request.modified_paths
        elsif branch_updated?
          push_details.modified_paths
        end
      end
    end

    def default_branch?
      ref == project.default_branch
    end

    def triggered_by_merge_request?
      merge_request_event? && merge_request_id.present?
    end

    def detached_merge_request_pipeline?
      triggered_by_merge_request? && target_sha.nil?
    end

    def legacy_detached_merge_request_pipeline?
      detached_merge_request_pipeline? && !merge_request_ref?
    end

    def merge_request_pipeline?
      triggered_by_merge_request? && target_sha.present?
    end

    def merge_request_ref?
      MergeRequest.merge_request_ref?(ref)
    end

    def matches_sha_or_source_sha?(sha)
      self.sha == sha || self.source_sha == sha
    end

    def triggered_by?(current_user)
      user == current_user
    end

    def source_ref
      if triggered_by_merge_request?
        merge_request.source_branch
      else
        ref
      end
    end

    def source_ref_slug
      Gitlab::Utils.slugify(source_ref.to_s)
    end

    def find_stage_by_name!(name)
      stages.find_by!(name: name)
    end

    private

    def ci_yaml_from_repo
      return unless project
      return unless sha
      return unless ci_yaml_file_path

      project.repository.gitlab_ci_yml_for(sha, ci_yaml_file_path)
    rescue GRPC::NotFound, GRPC::Internal
      nil
    end

    def implied_ci_yaml_file
      return unless project

      if project.auto_devops_enabled?
        Gitlab::Template::GitlabCiYmlTemplate.find('Auto-DevOps').content
      end
    end

    def pipeline_data
      Gitlab::DataBuilder::Pipeline.build(self)
    end

    def push_details
      strong_memoize(:push_details) do
        Gitlab::Git::Push.new(project, before_sha, sha, git_ref)
      end
    end

    def git_ref
      strong_memoize(:git_ref) do
        if merge_request_event?
          ##
          # In the future, we're going to change this ref to
          # merge request's merged reference, such as "refs/merge-requests/:iid/merge".
          # In order to do that, we have to update GitLab-Runner's source pulling
          # logic.
          # See https://gitlab.com/gitlab-org/gitlab-runner/merge_requests/1092
          Gitlab::Git::BRANCH_REF_PREFIX + ref.to_s
        else
          super
        end
      end
    end

    def latest_builds_status
      return 'failed' unless yaml_errors.blank?

      statuses.latest.status || 'skipped'
    end

    def keep_around_commits
      return unless project

      project.repository.keep_around(self.sha, self.before_sha)
    end
  end
end

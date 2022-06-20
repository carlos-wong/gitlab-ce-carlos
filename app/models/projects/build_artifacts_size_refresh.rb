# frozen_string_literal: true

module Projects
  class BuildArtifactsSizeRefresh < ApplicationRecord
    include BulkInsertSafe

    STALE_WINDOW = 2.hours

    self.table_name = 'project_build_artifacts_size_refreshes'

    belongs_to :project

    validates :project, presence: true

    STATES = {
      created: 1,
      running: 2,
      pending: 3
    }.freeze

    state_machine :state, initial: :created do
      # created -> running <-> pending
      state :created, value: STATES[:created]
      state :running, value: STATES[:running]
      state :pending, value: STATES[:pending]

      event :process do
        transition [:created, :pending, :running] => :running
      end

      event :requeue do
        transition running: :pending
      end

      # set it only the first time we execute the refresh
      before_transition created: :running do |refresh|
        refresh.reset_project_statistics!
        refresh.refresh_started_at = Time.zone.now
      end

      before_transition running: any do |refresh, transition|
        refresh.updated_at = Time.zone.now
      end

      before_transition running: :pending do |refresh, transition|
        refresh.last_job_artifact_id = transition.args.first
      end
    end

    scope :stale, -> { with_state(:running).where('updated_at < ?', STALE_WINDOW.ago) }
    scope :remaining, -> { with_state(:created, :pending).or(stale) }

    def self.enqueue_refresh(projects)
      now = Time.zone.now

      records = Array(projects).map do |project|
        new(project: project, state: STATES[:created], created_at: now, updated_at: now)
      end

      bulk_insert!(records, skip_duplicates: true)
    end

    def self.process_next_refresh!
      next_refresh = nil

      transaction do
        next_refresh = remaining
          .order(:state, :updated_at)
          .lock('FOR UPDATE SKIP LOCKED')
          .take

        next_refresh&.process!
      end

      next_refresh
    end

    def reset_project_statistics!
      statistics = project.statistics
      statistics.update!(build_artifacts_size: 0)
      statistics.clear_counter!(:build_artifacts_size)
    end

    def next_batch(limit:)
      project.job_artifacts.select(:id, :size)
        .where('created_at <= ? AND id > ?', refresh_started_at, last_job_artifact_id.to_i)
        .order(:created_at)
        .limit(limit)
    end
  end
end

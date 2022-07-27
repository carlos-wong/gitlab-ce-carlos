# frozen_string_literal: true

module Gitlab
  module GithubImport
    module Importer
      module Events
        class CrossReferenced
          attr_reader :project, :user_id

          def initialize(project, user_id)
            @project = project
            @user_id = user_id
          end

          # issue_event - An instance of `Gitlab::GithubImport::Representation::IssueEvent`.
          def execute(issue_event)
            mentioned_in_record_class = mentioned_in_type(issue_event)
            mentioned_in_number = issue_event.source.dig(:issue, :number)
            mentioned_in_record = init_mentioned_in(
              mentioned_in_record_class, mentioned_in_number
            )
            return if mentioned_in_record.nil?

            note_body = cross_reference_note_content(mentioned_in_record.gfm_reference(project))
            track_activity(mentioned_in_record_class)
            create_note(issue_event, note_body)
          end

          private

          def track_activity(mentioned_in_class)
            return if mentioned_in_class != Issue

            Gitlab::UsageDataCounters::HLLRedisCounter.track_event(
              Gitlab::UsageDataCounters::IssueActivityUniqueCounter::ISSUE_CROSS_REFERENCED,
              values: user_id
            )
          end

          def create_note(issue_event, note_body)
            Note.create!(
              system: true,
              noteable_type: Issue.name,
              noteable_id: issue_event.issue_db_id,
              project: project,
              author_id: user_id,
              note: note_body,
              system_note_metadata: SystemNoteMetadata.new(action: 'cross_reference'),
              created_at: issue_event.created_at
            )
          end

          def mentioned_in_type(issue_event)
            is_pull_request = issue_event.source.dig(:issue, :pull_request).present?
            is_pull_request ? MergeRequest : Issue
          end

          # record_class - Issue/MergeRequest
          def init_mentioned_in(record_class, iid)
            db_id = fetch_mentioned_in_db_id(record_class, iid)
            return if db_id.nil?

            record = record_class.new(id: db_id, iid: iid)
            record.project = project
            record.readonly!
            record
          end

          # record_class - Issue/MergeRequest
          def fetch_mentioned_in_db_id(record_class, number)
            sawyer_mentioned_in_adapter = Struct.new(:iid, :issuable_type, keyword_init: true)
            mentioned_in_adapter = sawyer_mentioned_in_adapter.new(
              iid: number, issuable_type: record_class.name
            )

            Gitlab::GithubImport::IssuableFinder.new(project, mentioned_in_adapter).database_id
          end

          def cross_reference_note_content(gfm_reference)
            "#{::SystemNotes::IssuablesService.cross_reference_note_prefix}#{gfm_reference}"
          end
        end
      end
    end
  end
end

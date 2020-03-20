# frozen_string_literal: true

module Gitlab
  module ImportExport
    class ProjectRelationFactory < BaseRelationFactory
      prepend_if_ee('::EE::Gitlab::ImportExport::ProjectRelationFactory') # rubocop: disable Cop/InjectEnterpriseEditionModule

      OVERRIDES = { snippets: :project_snippets,
                    ci_pipelines: 'Ci::Pipeline',
                    pipelines: 'Ci::Pipeline',
                    stages: 'Ci::Stage',
                    statuses: 'commit_status',
                    triggers: 'Ci::Trigger',
                    pipeline_schedules: 'Ci::PipelineSchedule',
                    builds: 'Ci::Build',
                    runners: 'Ci::Runner',
                    hooks: 'ProjectHook',
                    merge_access_levels: 'ProtectedBranch::MergeAccessLevel',
                    push_access_levels: 'ProtectedBranch::PushAccessLevel',
                    create_access_levels: 'ProtectedTag::CreateAccessLevel',
                    labels: :project_labels,
                    priorities: :label_priorities,
                    auto_devops: :project_auto_devops,
                    label: :project_label,
                    custom_attributes: 'ProjectCustomAttribute',
                    project_badges: 'Badge',
                    metrics: 'MergeRequest::Metrics',
                    ci_cd_settings: 'ProjectCiCdSetting',
                    error_tracking_setting: 'ErrorTracking::ProjectErrorTrackingSetting',
                    links: 'Releases::Link',
                    metrics_setting: 'ProjectMetricsSetting' }.freeze

      BUILD_MODELS = %i[Ci::Build commit_status].freeze

      GROUP_REFERENCES = %w[group_id].freeze

      PROJECT_REFERENCES = %w[project_id source_project_id target_project_id].freeze

      EXISTING_OBJECT_RELATIONS = %i[
        milestone
        milestones
        label
        labels
        project_label
        project_labels
        group_label
        group_labels
        project_feature
        merge_request
        epic
        ProjectCiCdSetting
        container_expiration_policy
      ].freeze

      def create
        @object = super

        # We preload the project, user, and group to re-use objects
        @object = preload_keys(@object, PROJECT_REFERENCES, @importable)
        @object = preload_keys(@object, GROUP_REFERENCES, @importable.group)
        @object = preload_keys(@object, USER_REFERENCES, @user)
      end

      private

      def invalid_relation?
        # Do not create relation if it is:
        #   - An unknown service
        #   - A legacy trigger
        unknown_service? ||
          (!Feature.enabled?(:use_legacy_pipeline_triggers, @importable) && legacy_trigger?)
      end

      def setup_models
        case @relation_name
        when :merge_request_diff_files then setup_diff
        when :notes then setup_note
        when :'Ci::Pipeline' then setup_pipeline
        when *BUILD_MODELS then setup_build
        end

        update_project_references
        update_group_references
      end

      def generate_imported_object
        if @relation_name == :merge_requests
          MergeRequestParser.new(@importable, @relation_hash.delete('diff_head_sha'), super, @relation_hash).parse!
        else
          super
        end
      end

      def update_project_references
        # If source and target are the same, populate them with the new project ID.
        if @relation_hash['source_project_id']
          @relation_hash['source_project_id'] = same_source_and_target? ? @relation_hash['project_id'] : MergeRequestParser::FORKED_PROJECT_ID
        end

        @relation_hash['target_project_id'] = @relation_hash['project_id'] if @relation_hash['target_project_id']
      end

      def same_source_and_target?
        @relation_hash['target_project_id'] && @relation_hash['target_project_id'] == @relation_hash['source_project_id']
      end

      def update_group_references
        return unless existing_object?
        return unless @relation_hash['group_id']

        @relation_hash['group_id'] = @importable.namespace_id
      end

      # This code is a workaround for broken project exports that don't
      # export merge requests with CI pipelines (i.e. exports that were
      # generated from
      # https://gitlab.com/gitlab-org/gitlab/merge_requests/17844).
      # This method can be removed in GitLab 12.6.
      def update_merge_request_references
        # If a merge request was properly created, we don't need to fix
        # up this export.
        return if @relation_hash['merge_request']

        merge_request_id = @relation_hash['merge_request_id']

        return unless merge_request_id

        new_merge_request_id = @merge_requests_mapping[merge_request_id]

        return unless new_merge_request_id

        @relation_hash['merge_request_id'] = new_merge_request_id
        parsed_relation_hash['merge_request_id'] = new_merge_request_id
      end

      def setup_build
        @relation_hash.delete('trace') # old export files have trace
        @relation_hash.delete('token')
        @relation_hash.delete('commands')
        @relation_hash.delete('artifacts_file_store')
        @relation_hash.delete('artifacts_metadata_store')
        @relation_hash.delete('artifacts_size')
      end

      def setup_diff
        @relation_hash['diff'] = @relation_hash.delete('utf8_diff')
      end

      def setup_pipeline
        update_merge_request_references

        @relation_hash.fetch('stages', []).each do |stage|
          stage.statuses.each do |status|
            status.pipeline = imported_object
          end
        end
      end

      def unknown_service?
        @relation_name == :services && parsed_relation_hash['type'] &&
          !Object.const_defined?(parsed_relation_hash['type'])
      end

      def legacy_trigger?
        @relation_name == :'Ci::Trigger' && @relation_hash['owner_id'].nil?
      end

      def preload_keys(object, references, value)
        return object unless value

        references.each do |key|
          attribute = "#{key.delete_suffix('_id')}=".to_sym
          next unless object.respond_to?(key) && object.respond_to?(attribute)

          if object.read_attribute(key) == value&.id
            object.public_send(attribute, value) # rubocop:disable GitlabSecurity/PublicSend
          end
        end

        object
      end
    end
  end
end

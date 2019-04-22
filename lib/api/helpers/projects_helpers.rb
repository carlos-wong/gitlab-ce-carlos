# frozen_string_literal: true

module API
  module Helpers
    module ProjectsHelpers
      extend ActiveSupport::Concern

      included do
        helpers do
          params :optional_project_params_ce do
            optional :description, type: String, desc: 'The description of the project'
            optional :ci_config_path, type: String, desc: 'The path to CI config file. Defaults to `.gitlab-ci.yml`'
            optional :issues_enabled, type: Boolean, desc: 'Flag indication if the issue tracker is enabled'
            optional :merge_requests_enabled, type: Boolean, desc: 'Flag indication if merge requests are enabled'
            optional :wiki_enabled, type: Boolean, desc: 'Flag indication if the wiki is enabled'
            optional :jobs_enabled, type: Boolean, desc: 'Flag indication if jobs are enabled'
            optional :snippets_enabled, type: Boolean, desc: 'Flag indication if snippets are enabled'
            optional :shared_runners_enabled, type: Boolean, desc: 'Flag indication if shared runners are enabled for that project'
            optional :resolve_outdated_diff_discussions, type: Boolean, desc: 'Automatically resolve merge request diffs discussions on lines changed with a push'
            optional :container_registry_enabled, type: Boolean, desc: 'Flag indication if the container registry is enabled for that project'
            optional :lfs_enabled, type: Boolean, desc: 'Flag indication if Git LFS is enabled for that project'
            optional :visibility, type: String, values: Gitlab::VisibilityLevel.string_values, desc: 'The visibility of the project.'
            optional :public_builds, type: Boolean, desc: 'Perform public builds'
            optional :request_access_enabled, type: Boolean, desc: 'Allow users to request member access'
            optional :only_allow_merge_if_pipeline_succeeds, type: Boolean, desc: 'Only allow to merge if builds succeed'
            optional :only_allow_merge_if_all_discussions_are_resolved, type: Boolean, desc: 'Only allow to merge if all discussions are resolved'
            optional :tag_list, type: Array[String], desc: 'The list of tags for a project'
            optional :avatar, type: File, desc: 'Avatar image for project'
            optional :printing_merge_request_link_enabled, type: Boolean, desc: 'Show link to create/view merge request when pushing from the command line'
            optional :merge_method, type: String, values: %w(ff rebase_merge merge), desc: 'The merge method used when merging merge requests'
            optional :initialize_with_readme, type: Boolean, desc: "Initialize a project with a README.md"
            optional :external_authorization_classification_label, type: String, desc: 'The classification label for the project'
          end

          if Gitlab.ee?
            params :optional_project_params_ee do
              optional :repository_storage, type: String, desc: 'Which storage shard the repository is on. Available only to admins'
              optional :approvals_before_merge, type: Integer, desc: 'How many approvers should approve merge request by default'
              optional :mirror, type: Boolean, desc: 'Enables pull mirroring in a project'
              optional :mirror_trigger_builds, type: Boolean, desc: 'Pull mirroring triggers builds'
            end
          end

          params :optional_project_params do
            use :optional_project_params_ce
            use :optional_project_params_ee if Gitlab.ee?
          end
        end
      end

      def self.update_params_at_least_one_of
        [
          :jobs_enabled,
          :resolve_outdated_diff_discussions,
          :ci_config_path,
          :container_registry_enabled,
          :default_branch,
          :description,
          :issues_enabled,
          :lfs_enabled,
          :merge_requests_enabled,
          :merge_method,
          :name,
          :only_allow_merge_if_all_discussions_are_resolved,
          :only_allow_merge_if_pipeline_succeeds,
          :path,
          :printing_merge_request_link_enabled,
          :public_builds,
          :request_access_enabled,
          :shared_runners_enabled,
          :snippets_enabled,
          :tag_list,
          :visibility,
          :wiki_enabled,
          :avatar,
          :external_authorization_classification_label
        ]
      end
    end
  end
end

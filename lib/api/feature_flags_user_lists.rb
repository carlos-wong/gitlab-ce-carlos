# frozen_string_literal: true

module API
  class FeatureFlagsUserLists < ::API::Base
    include PaginationParams

    error_formatter :json, -> (message, _backtrace, _options, _env, _original_exception) {
      message.is_a?(String) ? { message: message }.to_json : message.to_json
    }

    feature_category :feature_flags
    urgency :low

    before do
      authorize_admin_feature_flags_user_lists!
    end

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource 'projects/:id', requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      resource :feature_flags_user_lists do
        desc 'Get all feature flags user lists of a project' do
          detail 'This feature was introduced in GitLab 12.10'
          success ::API::Entities::FeatureFlag::UserList
        end
        params do
          optional :search, type: String, desc: 'Returns the list of user lists matching the search critiera'

          use :pagination
        end
        get do
          user_lists = ::FeatureFlagsUserListsFinder.new(user_project, current_user, params).execute
          present paginate(user_lists),
            with: ::API::Entities::FeatureFlag::UserList
        end

        desc 'Create a feature flags user list for a project' do
          detail 'This feature was introduced in GitLab 12.10'
          success ::API::Entities::FeatureFlag::UserList
        end
        params do
          requires :name, type: String, desc: 'The name of the list'
          requires :user_xids, type: String, desc: 'A comma separated list of external user ids'
        end
        post do
          # TODO: Move the business logic to a service class in app/services/feature_flags.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/367021
          list = user_project.operations_feature_flags_user_lists.create(declared_params)

          if list.save
            update_last_feature_flag_updated_at!

            present list, with: ::API::Entities::FeatureFlag::UserList
          else
            render_api_error!(list.errors.full_messages, :bad_request)
          end
        end
      end

      params do
        requires :iid, type: String, desc: 'The internal ID of the user list'
      end
      resource 'feature_flags_user_lists/:iid' do
        desc 'Get a single feature flag user list belonging to a project' do
          detail 'This feature was introduced in GitLab 12.10'
          success ::API::Entities::FeatureFlag::UserList
        end
        get do
          present user_project.operations_feature_flags_user_lists.find_by_iid!(params[:iid]),
            with: ::API::Entities::FeatureFlag::UserList
        end

        desc 'Update a feature flag user list' do
          detail 'This feature was introduced in GitLab 12.10'
          success ::API::Entities::FeatureFlag::UserList
        end
        params do
          optional :name, type: String, desc: 'The name of the list'
          optional :user_xids, type: String, desc: 'A comma separated list of external user ids'
        end
        put do
          # TODO: Move the business logic to a service class in app/services/feature_flags.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/367021
          list = user_project.operations_feature_flags_user_lists.find_by_iid!(params[:iid])

          if list.update(declared_params(include_missing: false))
            update_last_feature_flag_updated_at!

            present list, with: ::API::Entities::FeatureFlag::UserList
          else
            render_api_error!(list.errors.full_messages, :bad_request)
          end
        end

        desc 'Delete a feature flag user list' do
          detail 'This feature was introduced in GitLab 12.10'
        end
        delete do
          # TODO: Move the business logic to a service class in app/services/feature_flags.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/367021
          list = user_project.operations_feature_flags_user_lists.find_by_iid!(params[:iid])
          if list.destroy
            update_last_feature_flag_updated_at!

            nil
          else
            render_api_error!(list.errors.full_messages, :conflict)
          end
        end
      end
    end

    helpers do
      def authorize_admin_feature_flags_user_lists!
        authorize! :admin_feature_flags_user_lists, user_project
      end

      def update_last_feature_flag_updated_at!
        Operations::FeatureFlagsClient.update_last_feature_flag_updated_at!(user_project)
      end
    end
  end
end

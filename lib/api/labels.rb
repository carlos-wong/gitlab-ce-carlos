# frozen_string_literal: true

module API
  class Labels < Grape::API
    include PaginationParams
    helpers ::API::Helpers::LabelHelpers

    before { authenticate! }

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all labels of the project' do
        success Entities::ProjectLabel
      end
      params do
        optional :with_counts, type: Boolean, default: false,
                 desc: 'Include issue and merge request counts'
        optional :include_ancestor_groups, type: Boolean, default: true,
                 desc: 'Include ancestor groups'
        use :pagination
      end
      get ':id/labels' do
        get_labels(user_project, Entities::ProjectLabel, include_ancestor_groups: params[:include_ancestor_groups])
      end

      desc 'Get a single label' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::ProjectLabel
      end
      params do
        optional :include_ancestor_groups, type: Boolean, default: true,
                 desc: 'Include ancestor groups'
      end
      get ':id/labels/:name' do
        get_label(user_project, Entities::ProjectLabel, include_ancestor_groups: params[:include_ancestor_groups])
      end

      desc 'Create a new label' do
        success Entities::ProjectLabel
      end
      params do
        use :label_create_params
        optional :priority, type: Integer, desc: 'The priority of the label', allow_blank: true
      end
      post ':id/labels' do
        create_label(user_project, Entities::ProjectLabel)
      end

      desc 'Update an existing label. At least one optional parameter is required.' do
        detail 'This feature was deprecated in GitLab 12.4.'
        success Entities::ProjectLabel
      end
      params do
        optional :label_id, type: Integer, desc: 'The id of the label to be updated'
        optional :name, type: String, desc: 'The name of the label to be updated'
        use :project_label_update_params
        exactly_one_of :label_id, :name
      end
      put ':id/labels' do
        update_label(user_project, Entities::ProjectLabel)
      end

      desc 'Delete an existing label' do
        detail 'This feature was deprecated in GitLab 12.4.'
        success Entities::ProjectLabel
      end
      params do
        optional :label_id, type: Integer, desc: 'The id of the label to be deleted'
        optional :name, type: String, desc: 'The name of the label to be deleted'
        exactly_one_of :label_id, :name
      end
      delete ':id/labels' do
        delete_label(user_project)
      end

      desc 'Promote a label to a group label' do
        detail 'This feature was added in GitLab 12.3 and deprecated in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        requires :name, type: String, desc: 'The name of the label to be promoted'
      end
      put ':id/labels/promote' do
        promote_label(user_project)
      end

      desc 'Update an existing label. At least one optional parameter is required.' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::ProjectLabel
      end
      params do
        requires :name, type: String, desc: 'The name or id of the label to be updated'
        use :project_label_update_params
      end
      put ':id/labels/:name' do
        update_label(user_project, Entities::ProjectLabel)
      end

      desc 'Delete an existing label' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::ProjectLabel
      end
      params do
        requires :name, type: String, desc: 'The name or id of the label to be deleted'
      end
      delete ':id/labels/:name' do
        delete_label(user_project)
      end

      desc 'Promote a label to a group label' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        requires :name, type: String, desc: 'The name or id of the label to be promoted'
      end
      put ':id/labels/:name/promote' do
        promote_label(user_project)
      end
    end
  end
end

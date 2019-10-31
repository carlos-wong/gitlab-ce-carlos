# frozen_string_literal: true

module API
  class GroupLabels < Grape::API
    include PaginationParams
    helpers ::API::Helpers::LabelHelpers

    before { authenticate! }

    params do
      requires :id, type: String, desc: 'The ID of a group'
    end
    resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all labels of the group' do
        detail 'This feature was added in GitLab 11.8'
        success Entities::GroupLabel
      end
      params do
        optional :with_counts, type: Boolean, default: false,
                 desc: 'Include issue and merge request counts'
        optional :include_ancestor_groups, type: Boolean, default: true,
                 desc: 'Include ancestor groups'
        use :pagination
      end
      get ':id/labels' do
        get_labels(user_group, Entities::GroupLabel, include_ancestor_groups: params[:include_ancestor_groups])
      end

      desc 'Get a single label' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        optional :include_ancestor_groups, type: Boolean, default: true,
                 desc: 'Include ancestor groups'
      end
      get ':id/labels/:name' do
        get_label(user_group, Entities::GroupLabel, include_ancestor_groups: params[:include_ancestor_groups])
      end

      desc 'Create a new label' do
        detail 'This feature was added in GitLab 11.8'
        success Entities::GroupLabel
      end
      params do
        use :label_create_params
      end
      post ':id/labels' do
        create_label(user_group, Entities::GroupLabel)
      end

      desc 'Update an existing label. At least one optional parameter is required.' do
        detail 'This feature was added in GitLab 11.8 and deprecated in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        optional :label_id, type: Integer, desc: 'The id of the label to be updated'
        optional :name, type: String, desc: 'The name of the label to be updated'
        use :group_label_update_params
        exactly_one_of :label_id, :name
      end
      put ':id/labels' do
        update_label(user_group, Entities::GroupLabel)
      end

      desc 'Delete an existing label' do
        detail 'This feature was added in GitLab 11.8 and deprecated in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        requires :name, type: String, desc: 'The name of the label to be deleted'
      end
      delete ':id/labels' do
        delete_label(user_group)
      end

      desc 'Update an existing label. At least one optional parameter is required.' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        requires :name, type: String, desc: 'The name or id of the label to be updated'
        use :group_label_update_params
      end
      put ':id/labels/:name' do
        update_label(user_group, Entities::GroupLabel)
      end

      desc 'Delete an existing label' do
        detail 'This feature was added in GitLab 12.4.'
        success Entities::GroupLabel
      end
      params do
        requires :name, type: String, desc: 'The name or id of the label to be deleted'
      end
      delete ':id/labels/:name' do
        delete_label(user_group)
      end
    end
  end
end

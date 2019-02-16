# frozen_string_literal: true

module API
  class Subscriptions < Grape::API
    helpers ::API::Helpers::LabelHelpers

    before { authenticate! }

    subscribables = [
      {
        type: 'merge_requests',
        entity: Entities::MergeRequest,
        source: Project,
        finder: ->(id) { find_merge_request_with_access(id, :update_merge_request) }
      },
      {
        type: 'issues',
        entity: Entities::Issue,
        source: Project,
        finder: ->(id) { find_project_issue(id) }
      },
      {
        type: 'labels',
        entity: Entities::ProjectLabel,
        source: Project,
        finder: ->(id) { find_label(user_project, id) }
      },
      {
        type: 'labels',
        entity: Entities::GroupLabel,
        source: Group,
        finder: ->(id) { find_label(user_group, id) }
      }
    ]

    subscribables.each do |subscribable|
      source_type = subscribable[:source].name.underscore

      params do
        requires :id, type: String, desc: "The #{source_type} ID"
        requires :subscribable_id, type: String, desc: 'The ID of a resource'
      end
      resource source_type.pluralize, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
        desc 'Subscribe to a resource' do
          success subscribable[:entity]
        end
        post ":id/#{subscribable[:type]}/:subscribable_id/subscribe" do
          parent = parent_resource(source_type)
          resource = instance_exec(params[:subscribable_id], &subscribable[:finder])

          if resource.subscribed?(current_user, parent)
            not_modified!
          else
            resource.subscribe(current_user, parent)
            present resource, with: subscribable[:entity], current_user: current_user, project: parent, parent: parent
          end
        end

        desc 'Unsubscribe from a resource' do
          success subscribable[:entity]
        end
        post ":id/#{subscribable[:type]}/:subscribable_id/unsubscribe" do
          parent = parent_resource(source_type)
          resource = instance_exec(params[:subscribable_id], &subscribable[:finder])

          if !resource.subscribed?(current_user, parent)
            not_modified!
          else
            resource.unsubscribe(current_user, parent)
            present resource, with: subscribable[:entity], current_user: current_user, project: parent, parent: parent
          end
        end
      end
    end

    private

    helpers do
      def parent_resource(source_type)
        case source_type
        when 'project'
          user_project
        else
          nil
        end
      end
    end
  end
end

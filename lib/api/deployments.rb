# frozen_string_literal: true

module API
  # Deployments RESTful API endpoints
  class Deployments < Grape::API
    include PaginationParams

    before { authenticate! }

    params do
      requires :id, type: String, desc: 'The project ID'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all deployments of the project' do
        detail 'This feature was introduced in GitLab 8.11.'
        success Entities::Deployment
      end
      params do
        use :pagination
        optional :order_by, type: String, values: %w[id iid created_at updated_at ref], default: 'id', desc: 'Return deployments ordered by `id` or `iid` or `created_at` or `updated_at` or `ref`'
        optional :sort, type: String, values: %w[asc desc], default: 'asc', desc: 'Sort by asc (ascending) or desc (descending)'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ':id/deployments' do
        authorize! :read_deployment, user_project

        present paginate(user_project.deployments.order(params[:order_by] => params[:sort])), with: Entities::Deployment
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Gets a specific deployment' do
        detail 'This feature was introduced in GitLab 8.11.'
        success Entities::Deployment
      end
      params do
        requires :deployment_id, type: Integer, desc: 'The deployment ID'
      end
      get ':id/deployments/:deployment_id' do
        authorize! :read_deployment, user_project

        deployment = user_project.deployments.find(params[:deployment_id])

        present deployment, with: Entities::Deployment
      end

      desc 'Creates a new deployment' do
        detail 'This feature was introduced in GitLab 12.4'
        success Entities::Deployment
      end
      params do
        requires :environment,
          type: String,
          desc: 'The name of the environment to deploy to'

        requires :sha,
          type: String,
          desc: 'The SHA of the commit that was deployed'

        requires :ref,
          type: String,
          desc: 'The name of the branch or tag that was deployed'

        requires :tag,
          type: Boolean,
          desc: 'A boolean indicating if the deployment ran for a tag'

        requires :status,
          type: String,
          desc: 'The status of the deployment',
          values: %w[running success failed canceled]
      end
      post ':id/deployments' do
        authorize!(:create_deployment, user_project)
        authorize!(:create_environment, user_project)

        environment = user_project
          .environments
          .find_or_create_by_name(params[:environment])

        unless environment.persisted?
          render_validation_error!(deployment)
        end

        authorize!(:create_deployment, environment)

        service = ::Deployments::CreateService
          .new(environment, current_user, declared_params)

        deployment = service.execute

        if deployment.persisted?
          present(deployment, with: Entities::Deployment, current_user: current_user)
        else
          render_validation_error!(deployment)
        end
      end

      desc 'Updates an existing deployment' do
        detail 'This feature was introduced in GitLab 12.4'
        success Entities::Deployment
      end
      params do
        requires :status,
          type: String,
          desc: 'The new status of the deployment',
          values: %w[running success failed canceled]
      end
      put ':id/deployments/:deployment_id' do
        authorize!(:read_deployment, user_project)

        deployment = user_project.deployments.find(params[:deployment_id])

        authorize!(:update_deployment, deployment)

        if deployment.deployable
          forbidden!('Deployments created using GitLab CI can not be updated using the API')
        end

        service = ::Deployments::UpdateService.new(deployment, declared_params)

        if service.execute
          present(deployment, with: Entities::Deployment, current_user: current_user)
        else
          render_validation_error!(deployment)
        end
      end
    end
  end
end

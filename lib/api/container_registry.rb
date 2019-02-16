# frozen_string_literal: true

module API
  class ContainerRegistry < Grape::API
    include PaginationParams

    REGISTRY_ENDPOINT_REQUIREMENTS = API::NAMESPACE_OR_PROJECT_REQUIREMENTS.merge(
      tag_name: API::NO_SLASH_URL_PART_REGEX)

    before { error!('404 Not Found', 404) unless Feature.enabled?(:container_registry_api, user_project, default_enabled: true) }
    before { authorize_read_container_images! }

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a project container repositories' do
        detail 'This feature was introduced in GitLab 11.8.'
        success Entities::ContainerRegistry::Repository
      end
      params do
        use :pagination
      end
      get ':id/registry/repositories' do
        repositories = user_project.container_repositories.ordered

        present paginate(repositories), with: Entities::ContainerRegistry::Repository
      end

      desc 'Delete repository' do
        detail 'This feature was introduced in GitLab 11.8.'
      end
      params do
        requires :repository_id, type: Integer, desc: 'The ID of the repository'
      end
      delete ':id/registry/repositories/:repository_id', requirements: REGISTRY_ENDPOINT_REQUIREMENTS do
        authorize_admin_container_image!

        DeleteContainerRepositoryWorker.perform_async(current_user.id, repository.id)

        status :accepted
      end

      desc 'Get a list of repositories tags' do
        detail 'This feature was introduced in GitLab 11.8.'
        success Entities::ContainerRegistry::Tag
      end
      params do
        requires :repository_id, type: Integer, desc: 'The ID of the repository'
        use :pagination
      end
      get ':id/registry/repositories/:repository_id/tags', requirements: REGISTRY_ENDPOINT_REQUIREMENTS do
        authorize_read_container_image!

        tags = Kaminari.paginate_array(repository.tags)
        present paginate(tags), with: Entities::ContainerRegistry::Tag
      end

      desc 'Delete repository tags (in bulk)' do
        detail 'This feature was introduced in GitLab 11.8.'
      end
      params do
        requires :repository_id, type: Integer, desc: 'The ID of the repository'
        requires :name_regex, type: String, desc: 'The tag name regexp to delete, specify .* to delete all'
        optional :keep_n, type: Integer, desc: 'Keep n of latest tags with matching name'
        optional :older_than, type: String, desc: 'Delete older than: 1h, 1d, 1month'
      end
      delete ':id/registry/repositories/:repository_id/tags', requirements: REGISTRY_ENDPOINT_REQUIREMENTS do
        authorize_admin_container_image!

        CleanupContainerRepositoryWorker.perform_async(current_user.id, repository.id,
          declared_params.except(:repository_id)) # rubocop: disable CodeReuse/ActiveRecord

        status :accepted
      end

      desc 'Get a details about repository tag' do
        detail 'This feature was introduced in GitLab 11.8.'
        success Entities::ContainerRegistry::TagDetails
      end
      params do
        requires :repository_id, type: Integer, desc: 'The ID of the repository'
        requires :tag_name, type: String, desc: 'The name of the tag'
      end
      get ':id/registry/repositories/:repository_id/tags/:tag_name', requirements: REGISTRY_ENDPOINT_REQUIREMENTS do
        authorize_read_container_image!
        validate_tag!

        present tag, with: Entities::ContainerRegistry::TagDetails
      end

      desc 'Delete repository tag' do
        detail 'This feature was introduced in GitLab 11.8.'
      end
      params do
        requires :repository_id, type: Integer, desc: 'The ID of the repository'
        requires :tag_name, type: String, desc: 'The name of the tag'
      end
      delete ':id/registry/repositories/:repository_id/tags/:tag_name', requirements: REGISTRY_ENDPOINT_REQUIREMENTS do
        authorize_destroy_container_image!
        validate_tag!

        tag.delete

        status :ok
      end
    end

    helpers do
      def authorize_read_container_images!
        authorize! :read_container_image, user_project
      end

      def authorize_read_container_image!
        authorize! :read_container_image, repository
      end

      def authorize_update_container_image!
        authorize! :update_container_image, repository
      end

      def authorize_destroy_container_image!
        authorize! :admin_container_image, repository
      end

      def authorize_admin_container_image!
        authorize! :admin_container_image, repository
      end

      def repository
        @repository ||= user_project.container_repositories.find(params[:repository_id])
      end

      def tag
        @tag ||= repository.tag(params[:tag_name])
      end

      def validate_tag!
        not_found!('Tag') unless tag.valid?
      end
    end
  end
end

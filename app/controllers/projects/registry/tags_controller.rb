# frozen_string_literal: true

module Projects
  module Registry
    class TagsController < ::Projects::Registry::ApplicationController
      before_action :authorize_destroy_container_image!, only: [:destroy]

      LIMIT = 15

      def index
        track_event(:list_tags)
        respond_to do |format|
          format.json do
            render json: ContainerTagsSerializer
              .new(project: @project, current_user: @current_user)
              .with_pagination(request, response)
              .represent(tags)
          end
        end
      end

      def destroy
        result = Projects::ContainerRepository::DeleteTagsService
          .new(image.project, current_user, tags: [params[:id]])
          .execute(image)
        track_event(:delete_tag)

        respond_to do |format|
          format.json { head(result[:status] == :success ? :ok : bad_request) }
        end
      end

      def bulk_destroy
        unless params[:ids].present?
          head :bad_request
          return
        end

        tag_names = params[:ids] || []
        if tag_names.size > LIMIT
          head :bad_request
          return
        end

        result = Projects::ContainerRepository::DeleteTagsService
          .new(image.project, current_user, tags: tag_names)
          .execute(image)
        track_event(:delete_tag_bulk)

        respond_to do |format|
          format.json { head(result[:status] == :success ? :no_content : :bad_request) }
        end
      end

      private

      def tags
        Kaminari::PaginatableArray.new(image.tags, limit: LIMIT)
      end

      def image
        @image ||= project.container_repositories
          .find(params[:repository_id])
      end
    end
  end
end

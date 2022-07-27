# frozen_string_literal: true

module API
  class Tags < ::API::Base
    include PaginationParams

    TAG_ENDPOINT_REQUIREMENTS = API::NAMESPACE_OR_PROJECT_REQUIREMENTS.merge(tag_name: API::NO_SLASH_URL_PART_REGEX)

    before do
      authorize! :download_code, user_project

      not_found! unless user_project.repo_exists?
    end

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a project repository tags' do
        success Entities::Tag
      end
      params do
        optional :sort, type: String, values: %w[asc desc], default: 'desc',
                        desc: 'Return tags sorted in updated by `asc` or `desc` order.'
        optional :order_by, type: String, values: %w[name updated], default: 'updated',
                            desc: 'Return tags ordered by `name` or `updated` fields.'
        optional :search, type: String, desc: 'Return list of tags matching the search criteria'
        optional :page_token, type: String, desc: 'Name of tag to start the paginaition from'
        use :pagination
      end
      get ':id/repository/tags', feature_category: :source_code_management, urgency: :low do
        tags_finder = ::TagsFinder.new(user_project.repository,
                                sort: "#{params[:order_by]}_#{params[:sort]}",
                                search: params[:search],
                                page_token: params[:page_token],
                                per_page: params[:per_page])

        paginated_tags = Gitlab::Pagination::GitalyKeysetPager.new(self, user_project).paginate(tags_finder)

        present_cached paginated_tags, with: Entities::Tag, project: user_project, cache_context: -> (_tag) { user_project.cache_key }

      rescue Gitlab::Git::InvalidPageToken => e
        unprocessable_entity!(e.message)
      rescue Gitlab::Git::CommandError
        service_unavailable!
      end

      desc 'Get a single repository tag' do
        success Entities::Tag
      end
      params do
        requires :tag_name, type: String, desc: 'The name of the tag'
      end
      get ':id/repository/tags/:tag_name', requirements: TAG_ENDPOINT_REQUIREMENTS, feature_category: :source_code_management do
        tag = user_project.repository.find_tag(params[:tag_name])
        not_found!('Tag') unless tag

        present tag, with: Entities::Tag, project: user_project
      end

      desc 'Create a new repository tag' do
        success Entities::Tag
      end
      params do
        requires :tag_name,            type: String, desc: 'The name of the tag'
        requires :ref,                 type: String, desc: 'The commit sha or branch name'
        optional :message,             type: String, desc: 'Specifying a message creates an annotated tag'
      end
      post ':id/repository/tags', :release_orchestration do
        authorize_admin_tag

        result = ::Tags::CreateService.new(user_project, current_user)
          .execute(params[:tag_name], params[:ref], params[:message])

        if result[:status] == :success
          present result[:tag],
                  with: Entities::Tag,
                  project: user_project
        else
          render_api_error!(result[:message], 400)
        end
      end

      desc 'Delete a repository tag'
      params do
        requires :tag_name, type: String, desc: 'The name of the tag'
      end
      delete ':id/repository/tags/:tag_name', requirements: TAG_ENDPOINT_REQUIREMENTS, feature_category: :source_code_management do
        authorize_admin_tag

        tag = user_project.repository.find_tag(params[:tag_name])
        not_found!('Tag') unless tag

        commit = user_project.repository.commit(tag.dereferenced_target)

        destroy_conditionally!(commit, last_updated: commit.authored_date) do
          result = ::Tags::DestroyService.new(user_project, current_user)
                    .execute(params[:tag_name])

          if result[:status] != :success
            render_api_error!(result[:message], result[:return_code])
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module API
  class Search < ::API::Base
    include PaginationParams

    before do
      authenticate!

      check_rate_limit!(:search_rate_limit, scope: [current_user])
    end

    feature_category :global_search
    urgency :low

    rescue_from ActiveRecord::QueryCanceled do |e|
      render_api_error!({ error: 'Request timed out' }, 408)
    end

    helpers do
      SCOPE_ENTITY = {
        merge_requests: Entities::MergeRequestBasic,
        issues: Entities::IssueBasic,
        projects: Entities::BasicProjectDetails,
        milestones: Entities::Milestone,
        notes: Entities::Note,
        commits: Entities::CommitDetail,
        blobs: Entities::Blob,
        wiki_blobs: Entities::Blob,
        snippet_titles: Entities::Snippet,
        users: Entities::UserBasic
      }.freeze

      def scope_preload_method
        {
          merge_requests: :with_api_entity_associations,
          projects: :with_api_entity_associations,
          issues: :with_api_entity_associations,
          milestones: :with_api_entity_associations,
          commits: :with_api_commit_entity_associations
        }.freeze
      end

      def search_service(additional_params = {})
        search_params = {
          scope: params[:scope],
          search: params[:search],
          state: params[:state],
          confidential: params[:confidential],
          snippets: snippets?,
          basic_search: params[:basic_search],
          page: params[:page],
          per_page: params[:per_page],
          order_by: params[:order_by],
          sort: params[:sort]
        }.merge(additional_params)

        SearchService.new(current_user, search_params)
      end

      def search(additional_params = {})
        @search_duration_s = Benchmark.realtime do
          @results = search_service(additional_params).search_objects(preload_method)
        end

        set_global_search_log_information

        Gitlab::UsageDataCounters::SearchCounter.count(:all_searches)

        paginate(@results)
      end

      def snippets?
        %w(snippet_titles).include?(params[:scope]).to_s
      end

      def entity
        SCOPE_ENTITY[params[:scope].to_sym]
      end

      def preload_method
        scope_preload_method[params[:scope].to_sym]
      end

      def verify_search_scope!(resource:)
        # In EE we have additional validation requirements for searches.
        # Defining this method here as a noop allows us to easily extend it in
        # EE, without having to modify this file directly.
      end

      def search_type
        'basic'
      end

      def search_scope
        params[:scope]
      end

      def set_global_search_log_information
        Gitlab::Instrumentation::GlobalSearchApi.set_information(
          type: search_type,
          level: search_service.level,
          scope: search_scope,
          search_duration_s: @search_duration_s
        )
      end
    end

    resource :search do
      desc 'Search on GitLab' do
        detail 'This feature was introduced in GitLab 10.5.'
      end
      params do
        requires :search, type: String, desc: 'The expression it should be searched for'
        requires :scope,
          type: String,
          desc: 'The scope of the search',
          values: Helpers::SearchHelpers.global_search_scopes
        optional :state, type: String, desc: 'Filter results by state', values: Helpers::SearchHelpers.search_states
        optional :confidential, type: Boolean, desc: 'Filter results by confidentiality'
        use :pagination
      end
      get do
        verify_search_scope!(resource: nil)

        present search, with: entity, current_user: current_user
      end
    end

    resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Search on GitLab' do
        detail 'This feature was introduced in GitLab 10.5.'
      end
      params do
        requires :id, type: String, desc: 'The ID of a group'
        requires :search, type: String, desc: 'The expression it should be searched for'
        requires :scope,
          type: String,
          desc: 'The scope of the search',
          values: Helpers::SearchHelpers.group_search_scopes
        optional :state, type: String, desc: 'Filter results by state', values: Helpers::SearchHelpers.search_states
        optional :confidential, type: Boolean, desc: 'Filter results by confidentiality'
        use :pagination
      end
      get ':id/(-/)search' do
        verify_search_scope!(resource: user_group)

        present search(group_id: user_group.id), with: entity, current_user: current_user
      end
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Search on GitLab' do
        detail 'This feature was introduced in GitLab 10.5.'
      end
      params do
        requires :id, type: String, desc: 'The ID of a project'
        requires :search, type: String, desc: 'The expression it should be searched for'
        requires :scope,
          type: String,
          desc: 'The scope of the search',
          values: Helpers::SearchHelpers.project_search_scopes
        optional :ref, type: String, desc: 'The name of a repository branch or tag. If not given, the default branch is used'
        optional :state, type: String, desc: 'Filter results by state', values: Helpers::SearchHelpers.search_states
        optional :confidential, type: Boolean, desc: 'Filter results by confidentiality'
        use :pagination
      end
      get ':id/(-/)search' do
        present search({ project_id: user_project.id, repository_ref: params[:ref] }), with: entity, current_user: current_user
      end
    end
  end
end

API::Search.prepend_mod_with('API::Search')

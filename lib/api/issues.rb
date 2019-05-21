# frozen_string_literal: true

module API
  class Issues < Grape::API
    include PaginationParams

    before { authenticate_non_get! }

    helpers ::Gitlab::IssuableMetadata

    helpers do
      # rubocop: disable CodeReuse/ActiveRecord
      def find_issues(args = {})
        args = declared_params.merge(args)

        args.delete(:id)
        args[:milestone_title] = args.delete(:milestone)
        args[:label_name] = args.delete(:labels)
        args[:scope] = args[:scope].underscore if args[:scope]

        issues = IssuesFinder.new(current_user, args).execute
                   .with_api_entity_associations
        issues.reorder(order_options_with_tie_breaker)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      if Gitlab.ee?
        params :issues_params_ee do
          optional :weight, types: [Integer, String], integer_none_any: true, desc: 'The weight of the issue'
        end

        params :issue_params_ee do
          optional :weight, type: Integer, desc: 'The weight of the issue'
        end
      end

      params :issues_params do
        optional :labels, type: Array[String], coerce_with: Validations::Types::LabelsList.coerce, desc: 'Comma-separated list of label names'
        optional :milestone, type: String, desc: 'Milestone title'
        optional :order_by, type: String, values: %w[created_at updated_at], default: 'created_at',
                            desc: 'Return issues ordered by `created_at` or `updated_at` fields.'
        optional :sort, type: String, values: %w[asc desc], default: 'desc',
                        desc: 'Return issues sorted in `asc` or `desc` order.'
        optional :milestone, type: String, desc: 'Return issues for a specific milestone'
        optional :iids, type: Array[Integer], desc: 'The IID array of issues'
        optional :search, type: String, desc: 'Search issues for text present in the title, description, or any combination of these'
        optional :in, type: String, desc: '`title`, `description`, or a string joining them with comma'
        optional :created_after, type: DateTime, desc: 'Return issues created after the specified time'
        optional :created_before, type: DateTime, desc: 'Return issues created before the specified time'
        optional :updated_after, type: DateTime, desc: 'Return issues updated after the specified time'
        optional :updated_before, type: DateTime, desc: 'Return issues updated before the specified time'
        optional :author_id, type: Integer, desc: 'Return issues which are authored by the user with the given ID'
        optional :assignee_id, types: [Integer, String], integer_none_any: true,
                               desc: 'Return issues which are assigned to the user with the given ID'
        optional :scope, type: String, values: %w[created-by-me assigned-to-me created_by_me assigned_to_me all],
                         desc: 'Return issues for the given scope: `created_by_me`, `assigned_to_me` or `all`'
        optional :my_reaction_emoji, type: String, desc: 'Return issues reacted by the authenticated user by the given emoji'
        optional :confidential, type: Boolean, desc: 'Filter confidential or public issues'
        use :pagination

        use :issues_params_ee if Gitlab.ee?
      end

      params :issue_params do
        optional :description, type: String, desc: 'The description of an issue'
        optional :assignee_ids, type: Array[Integer], desc: 'The array of user IDs to assign issue'
        optional :assignee_id,  type: Integer, desc: '[Deprecated] The ID of a user to assign issue'
        optional :milestone_id, type: Integer, desc: 'The ID of a milestone to assign issue'
        optional :labels, type: Array[String], coerce_with: Validations::Types::LabelsList.coerce, desc: 'Comma-separated list of label names'
        optional :due_date, type: String, desc: 'Date string in the format YEAR-MONTH-DAY'
        optional :confidential, type: Boolean, desc: 'Boolean parameter if the issue should be confidential'
        optional :discussion_locked, type: Boolean, desc: " Boolean parameter indicating if the issue's discussion is locked"

        use :issue_params_ee if Gitlab.ee?
      end
    end

    resource :issues do
      desc "Get currently authenticated user's issues" do
        success Entities::IssueBasic
      end
      params do
        optional :state, type: String, values: %w[opened closed all], default: 'all',
                         desc: 'Return opened, closed, or all issues'
        use :issues_params
        optional :scope, type: String, values: %w[created-by-me assigned-to-me created_by_me assigned_to_me all], default: 'created_by_me',
                         desc: 'Return issues for the given scope: `created_by_me`, `assigned_to_me` or `all`'
      end
      get do
        authenticate! unless params[:scope] == 'all'
        issues = paginate(find_issues)

        options = {
          with: Entities::IssueBasic,
          current_user: current_user,
          issuable_metadata: issuable_meta_data(issues, 'Issue')
        }

        present issues, options
      end
    end

    params do
      requires :id, type: String, desc: 'The ID of a group'
    end
    resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a list of group issues' do
        success Entities::IssueBasic
      end
      params do
        optional :state, type: String, values: %w[opened closed all], default: 'all',
                         desc: 'Return opened, closed, or all issues'
        use :issues_params
      end
      get ":id/issues" do
        group = find_group!(params[:id])

        issues = paginate(find_issues(group_id: group.id, include_subgroups: true))

        options = {
          with: Entities::IssueBasic,
          current_user: current_user,
          issuable_metadata: issuable_meta_data(issues, 'Issue')
        }

        present issues, options
      end
    end

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      include TimeTrackingEndpoints

      desc 'Get a list of project issues' do
        success Entities::IssueBasic
      end
      params do
        optional :state, type: String, values: %w[opened closed all], default: 'all',
                         desc: 'Return opened, closed, or all issues'
        use :issues_params
      end
      get ":id/issues" do
        project = find_project!(params[:id])

        issues = paginate(find_issues(project_id: project.id))

        options = {
          with: Entities::IssueBasic,
          current_user: current_user,
          project: user_project,
          issuable_metadata: issuable_meta_data(issues, 'Issue')
        }

        present issues, options
      end

      desc 'Get a single project issue' do
        success Entities::Issue
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
      end
      get ":id/issues/:issue_iid", as: :api_v4_project_issue do
        issue = find_project_issue(params[:issue_iid])
        present issue, with: Entities::Issue, current_user: current_user, project: user_project
      end

      desc 'Create a new project issue' do
        success Entities::Issue
      end
      params do
        requires :title, type: String, desc: 'The title of an issue'
        optional :created_at, type: DateTime,
                              desc: 'Date time when the issue was created. Available only for admins and project owners.'
        optional :merge_request_to_resolve_discussions_of, type: Integer,
                                                           desc: 'The IID of a merge request for which to resolve discussions'
        optional :discussion_to_resolve, type: String,
                                         desc: 'The ID of a discussion to resolve, also pass `merge_request_to_resolve_discussions_of`'
        optional :iid, type: Integer,
                       desc: 'The internal ID of a project issue. Available only for admins and project owners.'

        use :issue_params
      end
      post ':id/issues' do
        Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab-ce/issues/42320')

        authorize! :create_issue, user_project

        params.delete(:created_at) unless current_user.can?(:set_issue_created_at, user_project)
        params.delete(:iid) unless current_user.can?(:set_issue_iid, user_project)

        issue_params = declared_params(include_missing: false)
        issue_params[:system_note_timestamp] = params[:created_at]

        issue_params = convert_parameters_from_legacy_format(issue_params)

        issue = ::Issues::CreateService.new(user_project,
                                            current_user,
                                            issue_params.merge(request: request, api: true)).execute

        if issue.spam?
          render_api_error!({ error: 'Spam detected' }, 400)
        end

        if issue.valid?
          present issue, with: Entities::Issue, current_user: current_user, project: user_project
        else
          render_validation_error!(issue)
        end
      end

      desc 'Update an existing issue' do
        success Entities::Issue
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
        optional :title, type: String, desc: 'The title of an issue'
        optional :updated_at, type: DateTime,
                              desc: 'Date time when the issue was updated. Available only for admins and project owners.'
        optional :state_event, type: String, values: %w[reopen close], desc: 'State of the issue'
        use :issue_params

        at_least_one_of(*Helpers::IssuesHelpers.update_params_at_least_one_of)
      end
      # rubocop: disable CodeReuse/ActiveRecord
      put ':id/issues/:issue_iid' do
        Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab-ce/issues/42322')

        issue = user_project.issues.find_by!(iid: params.delete(:issue_iid))
        authorize! :update_issue, issue

        # Setting updated_at only allowed for admins and owners as well
        if params[:updated_at].present?
          if current_user.admin? || user_project.owner == current_user || current_user.owned_groups.include?(user_project.owner)
            issue.system_note_timestamp = params[:updated_at]
          else
            params.delete(:updated_at)
          end
        end

        update_params = declared_params(include_missing: false).merge(request: request, api: true)

        update_params = convert_parameters_from_legacy_format(update_params)

        issue = ::Issues::UpdateService.new(user_project,
                                            current_user,
                                            update_params).execute(issue)

        render_spam_error! if issue.spam?

        if issue.valid?
          present issue, with: Entities::Issue, current_user: current_user, project: user_project
        else
          render_validation_error!(issue)
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Move an existing issue' do
        success Entities::Issue
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
        requires :to_project_id, type: Integer, desc: 'The ID of the new project'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      post ':id/issues/:issue_iid/move' do
        Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab-ce/issues/42323')

        issue = user_project.issues.find_by(iid: params[:issue_iid])
        not_found!('Issue') unless issue

        new_project = Project.find_by(id: params[:to_project_id])
        not_found!('Project') unless new_project

        begin
          issue = ::Issues::MoveService.new(user_project, current_user).execute(issue, new_project)
          present issue, with: Entities::Issue, current_user: current_user, project: user_project
        rescue ::Issues::MoveService::MoveError => error
          render_api_error!(error.message, 400)
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Delete a project issue'
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      delete ":id/issues/:issue_iid" do
        issue = user_project.issues.find_by(iid: params[:issue_iid])
        not_found!('Issue') unless issue

        authorize!(:destroy_issue, issue)

        destroy_conditionally!(issue) do |issue|
          Issuable::DestroyService.new(user_project, current_user).execute(issue)
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'List merge requests that are related to the issue' do
        success Entities::MergeRequestBasic
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
      end
      get ':id/issues/:issue_iid/related_merge_requests' do
        issue = find_project_issue(params[:issue_iid])

        merge_requests = ::Issues::ReferencedMergeRequestsService.new(user_project, current_user)
          .execute(issue)
          .first

        present paginate(::Kaminari.paginate_array(merge_requests)),
          with: Entities::MergeRequest,
          current_user: current_user,
          project: user_project
      end

      desc 'List merge requests closing issue' do
        success Entities::MergeRequestBasic
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ':id/issues/:issue_iid/closed_by' do
        issue = find_project_issue(params[:issue_iid])

        merge_request_ids = MergeRequestsClosingIssues.where(issue_id: issue).select(:merge_request_id)
        merge_requests = MergeRequestsFinder.new(current_user, project_id: user_project.id).execute.where(id: merge_request_ids)

        present paginate(merge_requests), with: Entities::MergeRequestBasic, current_user: current_user, project: user_project
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'List participants for an issue' do
        success Entities::UserBasic
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
      end
      get ':id/issues/:issue_iid/participants' do
        issue = find_project_issue(params[:issue_iid])
        participants = ::Kaminari.paginate_array(issue.participants)

        present paginate(participants), with: Entities::UserBasic, current_user: current_user, project: user_project
      end

      desc 'Get the user agent details for an issue' do
        success Entities::UserAgentDetail
      end
      params do
        requires :issue_iid, type: Integer, desc: 'The internal ID of a project issue'
      end
      get ":id/issues/:issue_iid/user_agent_detail" do
        authenticated_as_admin!

        issue = find_project_issue(params[:issue_iid])

        break not_found!('UserAgentDetail') unless issue.user_agent_detail

        present issue.user_agent_detail, with: Entities::UserAgentDetail
      end
    end
  end
end

# frozen_string_literal: true

class UsersController < ApplicationController
  include InternalRedirect
  include RoutableActions
  include RendersMemberAccess
  include RendersProjectsList
  include ControllerWithCrossProjectAccessCheck
  include Gitlab::NoteableMetadata

  requires_cross_project_access show: false,
                                groups: false,
                                projects: false,
                                contributed: false,
                                snippets: true,
                                calendar: false,
                                followers: false,
                                following: false,
                                calendar_activities: true

  skip_before_action :authenticate_user!
  prepend_before_action(only: [:show]) { authenticate_sessionless_user!(:rss) }
  before_action :user, except: [:exists]
  before_action :authorize_read_user_profile!,
                only: [:calendar, :calendar_activities, :groups, :projects, :contributed, :starred, :snippets, :followers, :following]
  before_action only: [:exists] do
    check_rate_limit!(:username_exists, scope: request.ip)
  end

  feature_category :users, [:show, :activity, :groups, :projects, :contributed, :starred,
                            :followers, :following, :calendar, :calendar_activities,
                            :exists, :activity, :follow, :unfollow, :ssh_keys, :gpg_keys]

  feature_category :snippets, [:snippets]

  # TODO: Set higher urgency after resolving https://gitlab.com/gitlab-org/gitlab/-/issues/357914
  urgency :low, [:show]

  def show
    respond_to do |format|
      format.html

      format.atom do
        load_events
        render layout: 'xml'
      end

      format.json do
        msg = "This endpoint is deprecated. Use %s instead." % user_activity_path
        render json: { message: msg }, status: :not_found
      end
    end
  end

  # Get all keys of a user(params[:username]) in a text format
  # Helpful for sysadmins to put in respective servers
  def ssh_keys
    render plain: user.all_ssh_keys.join("\n")
  end

  def activity
    respond_to do |format|
      format.html { render 'show' }

      format.json do
        load_events
        pager_json("events/_events", @events.count, events: @events)
      end
    end
  end

  # Get all gpg keys of a user(params[:username]) in a text format
  def gpg_keys
    render plain: user.gpg_keys.select(&:verified?).map(&:key).join("\n")
  end

  def groups
    load_groups

    respond_to do |format|
      format.html { render 'show' }
      format.json do
        render json: {
          html: view_to_html_string("shared/groups/_list", groups: @groups)
        }
      end
    end
  end

  def projects
    load_projects

    present_projects(@projects)
  end

  def contributed
    load_contributed_projects

    present_projects(@contributed_projects)
  end

  def starred
    load_starred_projects

    present_projects(@starred_projects)
  end

  def followers
    @user_followers = user.followers.page(params[:page])

    present_users(@user_followers)
  end

  def following
    @user_following = user.followees.page(params[:page])

    present_users(@user_following)
  end

  def present_projects(projects)
    skip_pagination = Gitlab::Utils.to_boolean(params[:skip_pagination])
    skip_namespace = Gitlab::Utils.to_boolean(params[:skip_namespace])
    compact_mode = Gitlab::Utils.to_boolean(params[:compact_mode])

    respond_to do |format|
      format.html { render 'show' }
      format.json do
        pager_json("shared/projects/_list", projects.count, projects: projects, skip_pagination: skip_pagination, skip_namespace: skip_namespace, compact_mode: compact_mode)
      end
    end
  end

  def snippets
    load_snippets

    respond_to do |format|
      format.html { render 'show' }
      format.json do
        render json: {
          html: view_to_html_string("snippets/_snippets", collection: @snippets)
        }
      end
    end
  end

  def calendar
    render json: contributions_calendar.activity_dates
  end

  def calendar_activities
    @calendar_date = Date.parse(params[:date]) rescue Date.today
    @events = contributions_calendar.events_by_date(@calendar_date).map(&:present)

    render 'calendar_activities', layout: false
  end

  def exists
    if Gitlab::CurrentSettings.signup_enabled? || current_user
      render json: { exists: !!Namespace.find_by_path_or_name(params[:username]) }
    else
      render json: { error: _('You must be authenticated to access this path.') }, status: :unauthorized
    end
  end

  def follow
    current_user.follow(user)

    redirect_path = referer_path(request) || @user

    redirect_to redirect_path
  end

  def unfollow
    current_user.unfollow(user)

    redirect_path = referer_path(request) || @user

    redirect_to redirect_path
  end

  private

  def user
    @user ||= find_routable!(User, params[:username], request.fullpath)
  end

  def personal_projects
    PersonalProjectsFinder.new(user).execute(current_user)
  end

  def contributed_projects
    ContributedProjectsFinder.new(user).execute(current_user)
  end

  def starred_projects
    StarredProjectsFinder.new(user, params: finder_params, current_user: current_user).execute
  end

  def contributions_calendar
    @contributions_calendar ||= Gitlab::ContributionsCalendar.new(user, current_user)
  end

  def load_events
    @events = UserRecentEventsFinder.new(current_user, user, nil, params).execute

    Events::RenderService.new(current_user).execute(@events, atom_request: request.format.atom?)
  end

  def load_projects
    @projects = personal_projects
      .page(params[:page])
      .per(params[:limit])

    prepare_projects_for_rendering(@projects)
  end

  def load_contributed_projects
    @contributed_projects = contributed_projects.joined(user)

    prepare_projects_for_rendering(@contributed_projects)
  end

  def load_starred_projects
    @starred_projects = starred_projects

    prepare_projects_for_rendering(@starred_projects)
  end

  def load_groups
    @groups = JoinedGroupsFinder.new(user).execute(current_user)

    prepare_groups_for_rendering(@groups)
  end

  def load_snippets
    @snippets = SnippetsFinder.new(current_user, author: user, scope: params[:scope])
      .execute
      .page(params[:page])
      .inc_author

    @noteable_meta_data = noteable_meta_data(@snippets, 'Snippet')
  end

  def build_canonical_path(user)
    url_for(safe_params.merge(username: user.to_param))
  end

  def authorize_read_user_profile!
    access_denied! unless can?(current_user, :read_user_profile, user)
  end

  def present_users(users)
    respond_to do |format|
      format.html { render 'show' }
      format.json do
        render json: {
          html: view_to_html_string("shared/users/index", users: users)
        }
      end
    end
  end

  def finder_params
    {
      # don't display projects pending deletion
      without_deleted: true,
      # don't display projects marked for deletion
      not_aimed_for_deletion: true
    }
  end
end

UsersController.prepend_mod_with('UsersController')

# frozen_string_literal: true

class Explore::ProjectsController < Explore::ApplicationController
  include PageLimiter
  include ParamsBackwardCompatibility
  include RendersMemberAccess
  include RendersProjectsList
  include SortingHelper
  include SortingPreference

  MIN_SEARCH_LENGTH = 3
  PAGE_LIMIT = 50

  before_action :set_non_archived_param
  before_action :set_sorting

  # For background information on the limit, see:
  #   https://gitlab.com/gitlab-org/gitlab/-/issues/38357
  #   https://gitlab.com/gitlab-org/gitlab/-/issues/262682
  before_action only: [:index, :trending, :starred] do
    limit_pages(PAGE_LIMIT)
  end

  rescue_from PageOutOfBoundsError, with: :page_out_of_bounds

  feature_category :projects

  # TODO: Set higher urgency after addressing https://gitlab.com/gitlab-org/gitlab/-/issues/357913
  urgency :low, [:index]

  def index
    show_alert_if_search_is_disabled
    @projects = load_projects

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("explore/projects/_projects", projects: @projects)
        }
      end
    end
  end

  def trending
    params[:trending] = true
    @projects = load_projects

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("explore/projects/_projects", projects: @projects)
        }
      end
    end
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def starred
    @projects = load_projects.reorder('star_count DESC')

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("explore/projects/_projects", projects: @projects)
        }
      end
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def topics
    load_project_counts
    load_topics
  end

  def topic
    load_topic

    return render_404 unless @topic

    params[:topic] = @topic.name
    @projects = load_projects
  end

  private

  def load_project_counts
    @total_user_projects_count = ProjectsFinder.new(params: { non_public: true }, current_user: current_user).execute
    @total_starred_projects_count = ProjectsFinder.new(params: { starred: true }, current_user: current_user).execute
  end

  def load_projects
    load_project_counts

    finder_params = {
      minimum_search_length: MIN_SEARCH_LENGTH,
      not_aimed_for_deletion: true
    }

    projects = ProjectsFinder.new(current_user: current_user, params: params.merge(finder_params)).execute

    projects = preload_associations(projects)
    projects = projects.page(params[:page]).without_count

    prepare_projects_for_rendering(projects)
  end

  def load_topics
    @topics = Projects::TopicsFinder.new(params: params.permit(:search)).execute.page(params[:page]).without_count
  end

  def load_topic
    @topic = Projects::Topic.find_by_name_case_insensitive(params[:topic_name])
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def preload_associations(projects)
    projects.includes(:route, :creator, :group, :project_feature, :topics, namespace: [:route, :owner])
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def set_sorting
    params[:sort] = set_sort_order
    @sort = params[:sort]
  end

  def default_sort_order
    sort_value_latest_activity
  end

  def sorting_field
    Project::SORTING_PREFERENCE_FIELD
  end

  def page_out_of_bounds(error)
    load_project_counts
    @max_page_number = error.message

    respond_to do |format|
      format.html do
        render "page_out_of_bounds", status: :bad_request
      end

      format.json do
        render json: {
          html: view_to_html_string("explore/projects/page_out_of_bounds")
        }, status: :bad_request
      end
    end
  end

  def show_alert_if_search_is_disabled
    return if current_user || params[:name].blank? && params[:search].blank? || !html_request? || Feature.disabled?(:disable_anonymous_project_search, type: :ops)

    flash.now[:notice] = _('You must sign in to search for specific projects.')
  end
end

Explore::ProjectsController.prepend_mod_with('Explore::ProjectsController')

# frozen_string_literal: true

class Dashboard::ProjectsController < Dashboard::ApplicationController
  include ParamsBackwardCompatibility
  include RendersMemberAccess

  prepend_before_action(only: [:index]) { authenticate_sessionless_user!(:rss) }
  before_action :set_non_archived_param
  before_action :default_sorting
  skip_cross_project_access_check :index, :starred

  def index
    @projects = load_projects(params.merge(non_public: true))

    respond_to do |format|
      format.html do
        # n+1: https://gitlab.com/gitlab-org/gitlab-ce/issues/37434
        # Also https://gitlab.com/gitlab-org/gitlab-ce/issues/40260
        Gitlab::GitalyClient.allow_n_plus_1_calls do
          render
        end
      end
      format.atom do
        load_events
        render layout: 'xml.atom'
      end
      format.json do
        render json: {
          html: view_to_html_string("dashboard/projects/_projects", locals: { projects: @projects })
        }
      end
    end
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def starred
    @projects = load_projects(params.merge(starred: true))
      .includes(:forked_from_project, :tags)

    @groups = []

    respond_to do |format|
      format.html
      format.json do
        render json: {
          html: view_to_html_string("dashboard/projects/_projects", locals: { projects: @projects })
        }
      end
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  def default_sorting
    params[:sort] ||= 'latest_activity_desc'
    @sort = params[:sort]
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def load_projects(finder_params)
    @total_user_projects_count = ProjectsFinder.new(params: { non_public: true }, current_user: current_user).execute
    @total_starred_projects_count = ProjectsFinder.new(params: { starred: true }, current_user: current_user).execute

    projects = ProjectsFinder
                .new(params: finder_params, current_user: current_user)
                .execute
                .includes(:route, :creator, :group, namespace: [:route, :owner])
                .page(finder_params[:page])

    prepare_projects_for_rendering(projects)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def load_events
    projects = load_projects(params.merge(non_public: true))

    @events = EventCollection
      .new(projects, offset: params[:offset].to_i, filter: event_filter)
      .to_a

    Events::RenderService.new(current_user).execute(@events, atom_request: request.format.atom?)
  end
end

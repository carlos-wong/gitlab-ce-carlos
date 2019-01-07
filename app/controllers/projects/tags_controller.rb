# frozen_string_literal: true

class Projects::TagsController < Projects::ApplicationController
  include SortingHelper

  prepend_before_action(only: [:index]) { authenticate_sessionless_user!(:rss) }

  # Authorize
  before_action :require_non_empty_project
  before_action :authorize_download_code!
  before_action :authorize_push_code!, only: [:new, :create]
  before_action :authorize_admin_project!, only: [:destroy]

  # rubocop: disable CodeReuse/ActiveRecord
  def index
    params[:sort] = params[:sort].presence || sort_value_recently_updated

    @sort = params[:sort]
    @tags = TagsFinder.new(@repository, params).execute
    @tags = Kaminari.paginate_array(@tags).page(params[:page])

    tag_names = @tags.map(&:name)
    @tags_pipelines = @project.ci_pipelines.latest_successful_for_refs(tag_names)
    @releases = project.releases.where(tag: tag_names)

    respond_to do |format|
      format.html
      format.atom { render layout: 'xml.atom' }
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def show
    @tag = @repository.find_tag(params[:id])

    return render_404 unless @tag

    @release = @project.releases.find_or_initialize_by(tag: @tag.name)
    @commit = @repository.commit(@tag.dereferenced_target)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def create
    result = ::Tags::CreateService.new(@project, current_user)
      .execute(params[:tag_name], params[:ref], params[:message])

    if result[:status] == :success
      # Release creation with Tags was deprecated in GitLab 11.7
      if params[:release_description].present?
        release_params = {
          tag: params[:tag_name],
          name: params[:tag_name],
          description: params[:release_description]
        }

        Releases::CreateService
          .new(@project, current_user, release_params)
          .execute
      end

      @tag = result[:tag]

      redirect_to project_tag_path(@project, @tag.name)
    else
      @error = result[:message]
      @message = params[:message]
      @release_description = params[:release_description]
      render action: 'new'
    end
  end

  def destroy
    result = ::Tags::DestroyService.new(project, current_user).execute(params[:id])

    respond_to do |format|
      if result[:status] == :success
        format.html do
          redirect_to project_tags_path(@project), status: :see_other
        end

        format.js
      else
        @error = result[:message]

        format.html do
          redirect_to project_tags_path(@project),
            alert: @error, status: 303
        end

        format.js do
          render status: :unprocessable_entity
        end
      end
    end
  end
end

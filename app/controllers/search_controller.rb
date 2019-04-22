# frozen_string_literal: true

class SearchController < ApplicationController
  include ControllerWithCrossProjectAccessCheck
  include SearchHelper
  include RendersCommits

  skip_before_action :authenticate_user!
  requires_cross_project_access if: -> do
    search_term_present = params[:search].present? || params[:term].present?
    search_term_present && !params[:project_id].present?
  end

  layout 'search'

  def show
    @project = search_service.project
    @group = search_service.group

    return if params[:search].blank?

    @search_term = params[:search]

    @scope = search_service.scope
    @show_snippets = search_service.show_snippets?
    @search_results = search_service.search_results
    @search_objects = search_service.search_objects

    render_commits if @scope == 'commits'
    eager_load_user_status if @scope == 'users'

    check_single_commit_result
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def autocomplete
    term = params[:term]

    if params[:project_id].present?
      @project = Project.find_by(id: params[:project_id])
      @project = nil unless can?(current_user, :read_project, @project)
    end

    @ref = params[:project_ref] if params[:project_ref].present?

    render json: search_autocomplete_opts(term).to_json
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  def render_commits
    @search_objects = prepare_commits_for_rendering(@search_objects)
  end

  def eager_load_user_status
    return if Feature.disabled?(:users_search, default_enabled: true)

    @search_objects = @search_objects.eager_load(:status) # rubocop:disable CodeReuse/ActiveRecord
  end

  def check_single_commit_result
    if @search_results.single_commit_result?
      only_commit = @search_results.objects('commits').first
      query = params[:search].strip.downcase
      found_by_commit_sha = Commit.valid_hash?(query) && only_commit.sha.start_with?(query)

      redirect_to project_commit_path(@project, only_commit) if found_by_commit_sha
    end
  end
end

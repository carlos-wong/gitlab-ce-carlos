# frozen_string_literal: true

class Projects::GraphsController < Projects::ApplicationController
  include ExtractsPath

  # Authorize
  before_action :require_non_empty_project
  before_action :assign_ref_vars
  before_action :authorize_download_code!

  def show
    respond_to do |format|
      format.html
      format.json do
        fetch_graph
      end
    end
  end

  def commits
    redirect_to action: 'charts'
  end

  def languages
    redirect_to action: 'charts'
  end

  def charts
    get_commits
    get_languages
  end

  def ci
    redirect_to charts_project_pipelines_path(@project)
  end

  private

  def get_commits
    @commits_limit = 2000
    @commits = @project.repository.commits(@ref, limit: @commits_limit, skip_merges: true)
    @commits_graph = Gitlab::Graphs::Commits.new(@commits)
    @commits_per_week_days = @commits_graph.commits_per_week_days
    @commits_per_time = @commits_graph.commits_per_time
    @commits_per_month = @commits_graph.commits_per_month
  end

  def get_languages
    @languages =
      ::Projects::RepositoryLanguagesService.new(@project, current_user).execute.map do |lang|
        { value: lang.share, label: lang.name, color: lang.color, highlight: lang.color }
      end
  end

  def fetch_graph
    @commits = @project.repository.commits(@ref, limit: 6000, skip_merges: true)
    @log = []

    @commits.each do |commit|
      @log << {
        author_name: commit.author_name,
        author_email: commit.author_email,
        date: commit.committed_date.strftime("%Y-%m-%d")
      }
    end

    render json: @log.to_json
  end
end

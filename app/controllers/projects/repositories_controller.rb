# frozen_string_literal: true

class Projects::RepositoriesController < Projects::ApplicationController
  include ExtractsPath

  # Authorize
  before_action :require_non_empty_project, except: :create
  before_action :assign_archive_vars, only: :archive
  before_action :authorize_download_code!
  before_action :authorize_admin_project!, only: :create

  def create
    @project.create_repository

    redirect_to project_path(@project)
  end

  def archive
    append_sha = params[:append_sha]

    if @ref
      shortname = "#{@project.path}-#{@ref.tr('/', '-')}"
      append_sha = false if @filename == shortname
    end

    send_git_archive @repository, ref: @ref, path: params[:path], format: params[:format], append_sha: append_sha
  rescue => ex
    logger.error("#{self.class.name}: #{ex}")
    git_not_found!
  end

  def assign_archive_vars
    if params[:id]
      @ref, @filename = extract_ref(params[:id])
    else
      @ref = params[:ref]
      @filename = nil
    end
  rescue InvalidPathError
    render_404
  end
end

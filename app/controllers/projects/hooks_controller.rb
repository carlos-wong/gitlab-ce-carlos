# frozen_string_literal: true

class Projects::HooksController < Projects::ApplicationController
  include HooksExecution

  # Authorize
  before_action :authorize_admin_project!
  before_action :hook_logs, only: :edit

  respond_to :html

  layout "project_settings"

  def index
    redirect_to project_settings_integrations_path(@project)
  end

  def create
    @hook = @project.hooks.new(hook_params)
    @hook.save

    unless @hook.valid?
      @hooks = @project.hooks.select(&:persisted?)
      flash[:alert] = @hook.errors.full_messages.join.html_safe
    end

    redirect_to project_settings_integrations_path(@project)
  end

  def edit
  end

  def update
    if hook.update(hook_params)
      flash[:notice] = _('Hook was successfully updated.')
      redirect_to project_settings_integrations_path(@project)
    else
      render 'edit'
    end
  end

  def test
    result = TestHooks::ProjectService.new(hook, current_user, params[:trigger]).execute

    set_hook_execution_notice(result)

    redirect_back_or_default(default: { action: 'index' })
  end

  def destroy
    hook.destroy

    redirect_to project_settings_integrations_path(@project), status: :found
  end

  private

  def hook
    @hook ||= @project.hooks.find(params[:id])
  end

  def hook_logs
    @hook_logs ||= hook.web_hook_logs.recent.page(params[:page])
  end

  def hook_params
    params.require(:hook).permit(
      :enable_ssl_verification,
      :token,
      :url,
      :push_events_branch_filter,
      *ProjectHook.triggers.values
    )
  end
end

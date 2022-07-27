# frozen_string_literal: true

class Projects::HooksController < Projects::ApplicationController
  include ::Integrations::HooksExecution

  # Authorize
  before_action :authorize_admin_project!
  before_action :hook_logs, only: :edit
  before_action -> { check_rate_limit!(:project_testing_hook, scope: [@project, current_user]) }, only: :test

  respond_to :html

  layout "project_settings"

  feature_category :integrations
  urgency :low, [:test]

  def test
    trigger = params.fetch(:trigger, ::ProjectHook.triggers.each_value.first.to_s)
    result = TestHooks::ProjectService.new(hook, current_user, trigger).execute

    set_hook_execution_notice(result)

    redirect_back_or_default(default: { action: :index })
  end

  private

  def relation
    @project.hooks
  end

  def hook
    @hook ||= @project.hooks.find(params[:id])
  end

  def hook_logs
    @hook_logs ||= hook.web_hook_logs.recent.page(params[:page])
  end

  def trigger_values
    ProjectHook.triggers.values
  end
end

# frozen_string_literal: true

class Admin::HooksController < Admin::ApplicationController
  include ::Integrations::HooksExecution

  before_action :hook_logs, only: :edit

  feature_category :integrations
  urgency :low, [:test]

  def test
    result = TestHooks::SystemService.new(hook, current_user, params[:trigger]).execute

    set_hook_execution_notice(result)

    redirect_back_or_default
  end

  private

  def relation
    SystemHook
  end

  def hook
    @hook ||= SystemHook.find(params[:id])
  end

  def hook_logs
    @hook_logs ||= hook.web_hook_logs.recent.page(params[:page])
  end

  def hook_param_names
    %i[enable_ssl_verification token url]
  end

  def trigger_values
    SystemHook.triggers.values
  end
end

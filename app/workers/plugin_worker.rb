# frozen_string_literal: true

class PluginWorker
  include ApplicationWorker

  sidekiq_options retry: false
  feature_category :integrations

  def perform(file_name, data)
    success, message = Gitlab::Plugin.execute(file_name, data)

    unless success
      Gitlab::PluginLogger.error("Plugin Error => #{file_name}: #{message}")
    end

    true
  end
end

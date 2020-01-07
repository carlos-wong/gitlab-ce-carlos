# frozen_string_literal: true

class WebHookWorker
  include ApplicationWorker

  feature_category :integrations
  worker_has_external_dependencies!

  sidekiq_options retry: 4, dead: false

  def perform(hook_id, data, hook_name)
    hook = WebHook.find(hook_id)
    data = data.with_indifferent_access

    WebHookService.new(hook, data, hook_name).execute
  end
end

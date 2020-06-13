# frozen_string_literal: true

module Chaos
  class KillWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker
    include ChaosQueue

    sidekiq_options retry: false

    def perform
      Gitlab::Chaos.kill
    end
  end
end

# frozen_string_literal: true

# This module adds additional performance metrics to the grape logger
module Gitlab
  module GrapeLogging
    module Loggers
      class PerfLogger < ::GrapeLogging::Loggers::Base
        def parameters(_, _)
          {
            gitaly_calls: Gitlab::GitalyClient.get_request_count,
            gitaly_duration: Gitlab::GitalyClient.query_time_ms
          }
        end
      end
    end
  end
end

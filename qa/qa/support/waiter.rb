# frozen_string_literal: true

module QA
  module Support
    module Waiter
      extend Repeater

      module_function

      def wait_until(max_duration: singleton_class::DEFAULT_MAX_WAIT_TIME, reload_page: nil, sleep_interval: 0.1, raise_on_failure: true, retry_on_exception: false, log: true)
        if log
          QA::Runtime::Logger.debug(
            <<~MSG.tr("\n", ' ')
              with wait_until: max_duration: #{max_duration};
              reload_page: #{reload_page};
              sleep_interval: #{sleep_interval};
              raise_on_failure: #{raise_on_failure}
            MSG
          )
        end

        result = nil
        self.repeat_until(
          max_duration: max_duration,
          reload_page: reload_page,
          sleep_interval: sleep_interval,
          raise_on_failure: raise_on_failure,
          retry_on_exception: retry_on_exception,
          log: log
        ) do
          result = yield
        end
        QA::Runtime::Logger.debug("ended wait_until") if log

        result
      end
    end
  end
end

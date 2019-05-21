# frozen_string_literal: true

module QA
  module CE
    module Strategy
      extend self

      def extend_autoloads!
        # noop
      end

      def perform_before_hooks
        # The login page could take some time to load the first time it is visited.
        # We visit the login page and wait for it to properly load only once before the tests.
        QA::Runtime::Browser.visit(:gitlab, QA::Page::Main::Login)
        QA::Page::Main::Login.perform(&:assert_page_loaded)
      end
    end
  end
end

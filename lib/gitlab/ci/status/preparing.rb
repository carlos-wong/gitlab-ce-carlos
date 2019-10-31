# frozen_string_literal: true

module Gitlab
  module Ci
    module Status
      class Preparing < Status::Core
        def text
          s_('CiStatusText|preparing')
        end

        def label
          s_('CiStatusLabel|preparing')
        end

        def icon
          'status_preparing'
        end

        def favicon
          'favicon_status_preparing'
        end
      end
    end
  end
end

# frozen_string_literal: true

module QA
  module Page
    module Admin
      module Settings
        module Component
          class UsageStatistics < Page::Base
            view 'app/views/admin/application_settings/_usage.html.haml' do
              element :enable_usage_data_checkbox
            end

            def has_disabled_usage_data_checkbox?
              has_element?(:enable_usage_data_checkbox, disabled: true, visible: false)
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module QA
  module Page
    module Settings
      module Common
        # Click the Expand button present in the specified section
        #
        # @param [Symbol] element_name `element` name defined in a `view` block
        def expand_section(element_name)
          within_element(element_name) do
            # Because it is possible to click the button before the JS toggle code is bound
            wait(reload: false) do
              click_button 'Expand' unless has_css?('button', text: 'Collapse', wait: 1)

              has_content?('Collapse')
              finished_loading?
            end

            yield if block_given?
          end
        end
      end
    end
  end
end

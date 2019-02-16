# frozen_string_literal: true

module QA
  module Page
    module Project
      module SubMenus
        module Issues
          def self.included(base)
            base.class_eval do
              view 'app/views/layouts/nav/sidebar/_project.html.haml' do
                element :issues_item
                element :labels_link
                element :milestones_link
              end
            end
          end

          def click_issues
            within_sidebar do
              click_link('Issues')
            end
          end

          def click_milestones
            within_sidebar do
              click_element :milestones_link
            end
          end

          def go_to_labels
            hover_issues do
              within_submenu do
                click_element(:labels_link)
              end
            end
          end

          private

          def hover_issues
            within_sidebar do
              scroll_to_element(:issues_item)
              find_element(:issues_item).hover

              yield
            end
          end
        end
      end
    end
  end
end

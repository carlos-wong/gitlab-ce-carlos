# frozen_string_literal: true

module QA
  module Page
    module Admin
      module Overview
        module Users
          class Index < QA::Page::Base
            view 'app/views/admin/users/index.html.haml' do
              element :user_search_field
            end

            view 'app/views/admin/users/_user.html.haml' do
              element :user_row_content
            end

            view 'app/views/admin/users/_user_detail.html.haml' do
              element :username_link
            end

            def search_user(username)
              find_element(:user_search_field).set(username).send_keys(:return)
            end

            def click_user(username)
              within_element(:user_row_content, text: username) do
                click_element(:username_link)
              end
            end
          end
        end
      end
    end
  end
end

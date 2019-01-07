module QA
  module Page
    module Main
      class Login < Page::Base
        view 'app/views/devise/passwords/edit.html.haml' do
          element :password_field
          element :password_confirmation
          element :change_password_button
        end

        view 'app/views/devise/sessions/_new_base.html.haml' do
          element :login_field
          element :password_field
          element :sign_in_button
        end

        view 'app/views/devise/sessions/_new_ldap.html.haml' do
          element :username_field
          element :password_field
          element :sign_in_button
        end

        view 'app/views/devise/shared/_tabs_ldap.html.haml' do
          element :ldap_tab
          element :standard_tab
          element :register_tab
        end

        view 'app/views/devise/shared/_tabs_normal.html.haml' do
          element :sign_in_tab
          element :register_tab
        end

        view 'app/views/devise/shared/_omniauth_box.html.haml' do
          element :saml_login_button
        end

        view 'app/views/layouts/devise.html.haml' do
          element :login_page
        end

        def initialize
          # The login page is usually the entry point for all the scenarios so
          # we need to wait for the instance to start. That said, in some cases
          # we are already logged-in so we check both cases here.
          # Check if we're already logged in first. If we don't then we have to
          # wait 10 seconds for the check for the login page to fail every time
          # we use this class when we're already logged in (E.g., whenever we
          # create a personal access token to use for API access).
          wait(max: 500) do
            Page::Main::Menu.act { has_personal_area?(wait: 0) } ||
              has_element?(:login_page)
          end
        end

        def sign_in_using_credentials(user = nil)
          # Don't try to log-in if we're already logged-in
          return if Page::Main::Menu.act { has_personal_area?(wait: 0) }

          using_wait_time 0 do
            set_initial_password_if_present

            raise NotImplementedError if Runtime::User.ldap_user? && user&.credentials_given?

            if Runtime::User.ldap_user?
              sign_in_using_ldap_credentials
            else
              sign_in_using_gitlab_credentials(user || Runtime::User)
            end
          end

          Page::Main::Menu.act { has_personal_area? }
        end

        def sign_in_using_admin_credentials
          admin = QA::Resource::User.new.tap do |user|
            user.username = QA::Runtime::User.admin_username
            user.password = QA::Runtime::User.admin_password
          end

          using_wait_time 0 do
            set_initial_password_if_present

            sign_in_using_gitlab_credentials(admin)
          end

          Page::Main::Menu.act { has_personal_area? }
        end

        def self.path
          '/users/sign_in'
        end

        def has_sign_in_tab?
          has_element?(:sign_in_tab)
        end

        def has_ldap_tab?
          has_element?(:ldap_tab)
        end

        def has_standard_tab?
          has_element?(:standard_tab)
        end

        def sign_in_tab?
          has_css?(".active", text: 'Sign in')
        end

        def ldap_tab?
          has_css?(".active", text: 'LDAP')
        end

        def standard_tab?
          has_css?(".active", text: 'Standard')
        end

        def switch_to_sign_in_tab
          click_element :sign_in_tab
        end

        def switch_to_register_tab
          set_initial_password_if_present
          click_element :register_tab
        end

        def switch_to_ldap_tab
          click_element :ldap_tab
        end

        def switch_to_standard_tab
          click_element :standard_tab
        end

        private

        def sign_in_using_ldap_credentials
          switch_to_ldap_tab

          fill_element :username_field, Runtime::User.ldap_username
          fill_element :password_field, Runtime::User.ldap_password
          click_element :sign_in_button
        end

        def sign_in_with_saml
          set_initial_password_if_present
          click_element :saml_login_button
        end

        def sign_in_using_gitlab_credentials(user)
          switch_to_sign_in_tab if has_sign_in_tab?
          switch_to_standard_tab if has_standard_tab?

          fill_element :login_field, user.username
          fill_element :password_field, user.password
          click_element :sign_in_button
        end

        def set_initial_password_if_present
          return unless has_content?('Change your password')

          fill_element :password_field, Runtime::User.password
          fill_element :password_confirmation, Runtime::User.password
          click_element :change_password_button
        end
      end
    end
  end
end

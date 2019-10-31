# frozen_string_literal: true

require 'airborne'

module QA
  module Runtime
    module API
      class Client
        attr_reader :address, :user

        def initialize(address = :gitlab, personal_access_token: nil, is_new_session: true, user: nil, ip_limits: false)
          @address = address
          @personal_access_token = personal_access_token
          @is_new_session = is_new_session
          @user = user
          enable_ip_limits if ip_limits
        end

        def personal_access_token
          @personal_access_token ||= begin
            # you can set the environment variable GITLAB_QA_ACCESS_TOKEN
            # to use a specific access token rather than create one from the UI
            # unless a specific user has been passed
            @user.nil? ? Runtime::Env.personal_access_token ||= create_personal_access_token : create_personal_access_token
          end
        end

        private

        def enable_ip_limits
          Page::Main::Menu.perform(&:sign_out) if Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }

          Runtime::Browser.visit(@address, Page::Main::Login)
          Page::Main::Login.perform(&:sign_in_using_admin_credentials)
          Page::Main::Menu.perform(&:click_admin_area)
          Page::Admin::Menu.perform(&:go_to_network_settings)

          Page::Admin::Settings::Network.perform do |setting|
            setting.expand_ip_limits do |page|
              page.enable_throttles
              page.save_settings
            end
          end

          Page::Main::Menu.perform(&:sign_out)
        end

        def create_personal_access_token
          Page::Main::Menu.perform(&:sign_out) if @is_new_session && Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }

          unless Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }
            Runtime::Browser.visit(@address, Page::Main::Login)
            Page::Main::Login.perform { |login| login.sign_in_using_credentials(user: @user) }
          end

          token = Resource::PersonalAccessToken.fabricate!.access_token

          # If this is a new session, that tests that follow could fail if they
          # try to sign in without starting a new session
          # Sign out so the tests can successfully sign in
          Page::Main::Menu.perform(&:sign_out) if @is_new_session

          token
        end
      end
    end
  end
end

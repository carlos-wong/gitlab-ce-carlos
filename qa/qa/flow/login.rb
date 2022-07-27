# frozen_string_literal: true

module QA
  module Flow
    module Login
      module_function

      def while_signed_in(as: nil, address: :gitlab, admin: false)
        sign_in(as: as, address: address, admin: admin)

        result = yield

        Page::Main::Menu.perform(&:sign_out)
        result
      end

      def while_signed_in_as_admin(address: :gitlab)
        while_signed_in(address: address, admin: true) do
          yield
        end
      end

      def sign_in(as: nil, address: :gitlab, skip_page_validation: false, admin: false)
        Page::Main::Login.perform { |p| p.redirect_to_login_page(address) }

        unless Page::Main::Login.perform(&:on_login_page?)
          Page::Main::Menu.perform(&:sign_out) if Page::Main::Menu.perform(&:signed_in?)
        end

        Page::Main::Login.perform do |login|
          if admin
            login.sign_in_using_admin_credentials
          else
            login.sign_in_using_credentials(user: as, skip_page_validation: skip_page_validation)
          end
        end
      end

      def sign_in_as_admin(address: :gitlab)
        sign_in(as: Runtime::User.admin, address: address, admin: true)
      end

      def sign_in_unless_signed_in(user: nil, address: :gitlab)
        if user
          sign_in(as: user, address: address) unless Page::Main::Menu.perform do |menu|
            menu.signed_in_as_user?(user)
          end
        else
          sign_in(address: address) unless Page::Main::Menu.perform(&:signed_in?)
        end
      end
    end
  end
end

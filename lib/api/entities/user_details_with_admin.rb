# frozen_string_literal: true

module API
  module Entities
    class UserDetailsWithAdmin < UserWithAdmin
      expose :highest_role
      expose :current_sign_in_ip
      expose :last_sign_in_ip
    end
  end
end

API::Entities::UserDetailsWithAdmin.prepend_if_ee('EE::API::Entities::UserDetailsWithAdmin')

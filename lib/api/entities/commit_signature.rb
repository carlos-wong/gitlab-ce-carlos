# frozen_string_literal: true

module API
  module Entities
    class CommitSignature < Grape::Entity
      expose :gpg_key_id
      expose :gpg_key_primary_keyid, :gpg_key_user_name, :gpg_key_user_email
      expose :verification_status
      expose :gpg_key_subkey_id
    end
  end
end

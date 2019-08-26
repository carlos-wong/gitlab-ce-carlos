# frozen_string_literal: true

module NewHasVariable
  extend ActiveSupport::Concern
  include HasVariable

  included do
    attr_encrypted :value,
      mode: :per_attribute_iv,
      algorithm: 'aes-256-gcm',
      key: Settings.attr_encrypted_db_key_base_32,
      insecure_mode: false
  end
end

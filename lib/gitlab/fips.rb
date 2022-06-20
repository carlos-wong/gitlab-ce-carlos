# rubocop: disable Naming/FileName
# frozen_string_literal: true

module Gitlab
  class FIPS
    # A simple utility class for FIPS-related helpers

    Technology = Gitlab::SSHPublicKey::Technology

    SSH_KEY_TECHNOLOGIES = [
      Technology.new(:rsa, SSHData::PublicKey::RSA, [3072, 4096], %w(ssh-rsa)),
      Technology.new(:dsa, SSHData::PublicKey::DSA, [], %w(ssh-dss)),
      Technology.new(:ecdsa, SSHData::PublicKey::ECDSA, [256, 384, 521], %w(ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521)),
      Technology.new(:ed25519, SSHData::PublicKey::ED25519, [256], %w(ssh-ed25519)),
      Technology.new(:ecdsa_sk, SSHData::PublicKey::SKECDSA, [256], %w(sk-ecdsa-sha2-nistp256@openssh.com)),
      Technology.new(:ed25519_sk, SSHData::PublicKey::SKED25519, [256], %w(sk-ssh-ed25519@openssh.com))
    ].freeze

    class << self
      # Returns whether we should be running in FIPS mode or not
      #
      # @return [Boolean]
      def enabled?
        # Attempt to auto-detect FIPS mode from OpenSSL
        return true if OpenSSL.fips_mode

        # Otherwise allow it to be set manually via the env vars
        return true if ENV["FIPS_MODE"] == "true"

        false
      end
    end
  end
end

# rubocop: enable Naming/FileName

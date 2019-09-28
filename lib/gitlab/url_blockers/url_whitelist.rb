# frozen_string_literal: true

module Gitlab
  module UrlBlockers
    class UrlWhitelist
      class << self
        def ip_whitelisted?(ip_string)
          return false if ip_string.blank?

          ip_whitelist, _ = outbound_local_requests_whitelist_arrays
          ip_obj = Gitlab::Utils.string_to_ip_object(ip_string)

          ip_whitelist.any? { |ip| ip.include?(ip_obj) }
        end

        def domain_whitelisted?(domain_string)
          return false if domain_string.blank?

          _, domain_whitelist = outbound_local_requests_whitelist_arrays

          domain_whitelist.include?(domain_string)
        end

        private

        attr_reader :ip_whitelist, :domain_whitelist

        # We cannot use Gitlab::CurrentSettings as ApplicationSetting itself
        # calls this class. This ends up in a cycle where
        # Gitlab::CurrentSettings creates an ApplicationSetting which then
        # calls this method.
        #
        # See https://gitlab.com/gitlab-org/gitlab/issues/9833
        def outbound_local_requests_whitelist_arrays
          return [[], []] unless ApplicationSetting.current

          ApplicationSetting.current.outbound_local_requests_whitelist_arrays
        end
      end
    end
  end
end

# frozen_string_literal: true

# UrlValidator
#
# Custom validator for URLs.
#
# By default, only URLs for the HTTP(S) protocols will be considered valid.
# Provide a `:protocols` option to configure accepted protocols.
#
# Example:
#
#   class User < ActiveRecord::Base
#     validates :personal_url, url: true
#
#     validates :ftp_url, url: { protocols: %w(ftp) }
#
#     validates :git_url, url: { protocols: %w(http https ssh git) }
#   end
#
# This validator can also block urls pointing to localhost or the local network to
# protect against Server-side Request Forgery (SSRF), or check for the right port.
#
# The available options are:
# - protocols: Allowed protocols. Default: http and https
# - allow_localhost: Allow urls pointing to localhost. Default: true
# - allow_local_network: Allow urls pointing to private network addresses. Default: true
# - ports: Allowed ports. Default: all.
# - enforce_user: Validate user format. Default: false
# - enforce_sanitization: Validate that there are no html/css/js tags. Default: false
#
# Example:
#   class User < ActiveRecord::Base
#     validates :personal_url, url: { allow_localhost: false, allow_local_network: false}
#
#     validates :web_url, url: { ports: [80, 443] }
#   end
class UrlValidator < ActiveModel::EachValidator
  DEFAULT_PROTOCOLS = %w(http https).freeze

  attr_reader :record

  def validate_each(record, attribute, value)
    @record = record

    unless value.present?
      record.errors.add(attribute, 'must be a valid URL')
      return
    end

    value = strip_value!(record, attribute, value)

    Gitlab::UrlBlocker.validate!(value, blocker_args)
  rescue Gitlab::UrlBlocker::BlockedUrlError => e
    record.errors.add(attribute, "is blocked: #{e.message}")
  end

  private

  def strip_value!(record, attribute, value)
    new_value = value.strip
    return value if new_value == value

    record.public_send("#{attribute}=", new_value) # rubocop:disable GitlabSecurity/PublicSend
  end

  def default_options
    # By default the validator doesn't block any url based on the ip address
    {
      protocols: DEFAULT_PROTOCOLS,
      ports: [],
      allow_localhost: true,
      allow_local_network: true,
      ascii_only: false,
      enforce_user: false,
      enforce_sanitization: false
    }
  end

  def current_options
    options = self.options.map do |option, value|
      [option, value.is_a?(Proc) ? value.call(record) : value]
    end.to_h

    default_options.merge(options)
  end

  def blocker_args
    current_options.slice(*default_options.keys).tap do |args|
      if allow_setting_local_requests?
        args[:allow_localhost] = args[:allow_local_network] = true
      end
    end
  end

  def allow_setting_local_requests?
    # We cannot use Gitlab::CurrentSettings as ApplicationSetting itself
    # uses UrlValidator to validate urls. This ends up in a cycle
    # when Gitlab::CurrentSettings creates an ApplicationSetting which then
    # calls this validator.
    #
    # See https://gitlab.com/gitlab-org/gitlab-ee/issues/9833
    ApplicationSetting.current&.allow_local_requests_from_hooks_and_services?
  end
end

# frozen_string_literal: true

module ErrorTracking
  class ProjectErrorTrackingSetting < ActiveRecord::Base
    include ReactiveCaching

    self.reactive_cache_key = ->(setting) { [setting.class.model_name.singular, setting.project_id] }

    belongs_to :project

    validates :api_url, length: { maximum: 255 }, public_url: true, url: { enforce_sanitization: true }

    validate :validate_api_url_path

    attr_encrypted :token,
      mode: :per_attribute_iv,
      key: Settings.attr_encrypted_db_key_base_truncated,
      algorithm: 'aes-256-gcm'

    after_save :clear_reactive_cache!

    def sentry_client
      Sentry::Client.new(api_url, token)
    end

    def sentry_external_url
      self.class.extract_sentry_external_url(api_url)
    end

    def list_sentry_issues(opts = {})
      with_reactive_cache('list_issues', opts.stringify_keys) do |result|
        { issues: result }
      end
    end

    def calculate_reactive_cache(request, opts)
      case request
      when 'list_issues'
        sentry_client.list_issues(**opts.symbolize_keys)
      end
    end

    # http://HOST/api/0/projects/ORG/PROJECT
    # ->
    # http://HOST/ORG/PROJECT
    def self.extract_sentry_external_url(url)
      url.sub('api/0/projects/', '')
    end

    private

    def validate_api_url_path
      unless URI(api_url).path.starts_with?('/api/0/projects')
        errors.add(:api_url, 'path needs to start with /api/0/projects')
      end
    rescue URI::InvalidURIError
    end
  end
end

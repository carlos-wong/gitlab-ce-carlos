# frozen_string_literal: true

class ApplicationSetting < ApplicationRecord
  include CacheableAttributes
  include CacheMarkdownField
  include TokenAuthenticatable
  include IgnorableColumn
  include ChronicDurationAttribute

  add_authentication_token_field :runners_registration_token, encrypted: -> { Feature.enabled?(:application_settings_tokens_optional_encryption, default_enabled: true) ? :optional : :required }
  add_authentication_token_field :health_check_access_token

  # Include here so it can override methods from
  # `add_authentication_token_field`
  # We don't prepend for now because otherwise we'll need to
  # fix a lot of tests using allow_any_instance_of
  include ApplicationSettingImplementation

  serialize :restricted_visibility_levels # rubocop:disable Cop/ActiveRecordSerialize
  serialize :import_sources # rubocop:disable Cop/ActiveRecordSerialize
  serialize :disabled_oauth_sign_in_sources, Array # rubocop:disable Cop/ActiveRecordSerialize
  serialize :domain_whitelist, Array # rubocop:disable Cop/ActiveRecordSerialize
  serialize :domain_blacklist, Array # rubocop:disable Cop/ActiveRecordSerialize
  serialize :repository_storages # rubocop:disable Cop/ActiveRecordSerialize

  ignore_column :circuitbreaker_failure_count_threshold
  ignore_column :circuitbreaker_failure_reset_time
  ignore_column :circuitbreaker_storage_timeout
  ignore_column :circuitbreaker_access_retries
  ignore_column :circuitbreaker_check_interval
  ignore_column :koding_url
  ignore_column :koding_enabled

  cache_markdown_field :sign_in_text
  cache_markdown_field :help_page_text
  cache_markdown_field :shared_runners_text, pipeline: :plain_markdown
  cache_markdown_field :after_sign_up_text

  default_value_for :id, 1

  chronic_duration_attr_writer :archive_builds_in_human_readable, :archive_builds_in_seconds

  validates :uuid, presence: true

  validates :session_expire_delay,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :home_page_url,
            allow_blank: true,
            addressable_url: true,
            if: :home_page_url_column_exists?

  validates :help_page_support_url,
            allow_blank: true,
            addressable_url: true,
            if: :help_page_support_url_column_exists?

  validates :after_sign_out_path,
            allow_blank: true,
            addressable_url: true

  validates :admin_notification_email,
            devise_email: true,
            allow_blank: true

  validates :two_factor_grace_period,
            numericality: { greater_than_or_equal_to: 0 }

  validates :recaptcha_site_key,
            presence: true,
            if: :recaptcha_enabled

  validates :recaptcha_private_key,
            presence: true,
            if: :recaptcha_enabled

  validates :sentry_dsn,
            presence: true,
            if: :sentry_enabled

  validates :clientside_sentry_dsn,
            presence: true,
            if: :clientside_sentry_enabled

  validates :akismet_api_key,
            presence: true,
            if: :akismet_enabled

  validates :unique_ips_limit_per_user,
            numericality: { greater_than_or_equal_to: 1 },
            presence: true,
            if: :unique_ips_limit_enabled

  validates :unique_ips_limit_time_window,
            numericality: { greater_than_or_equal_to: 0 },
            presence: true,
            if: :unique_ips_limit_enabled

  validates :plantuml_url,
            presence: true,
            if: :plantuml_enabled

  validates :max_attachment_size,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validates :max_artifacts_size,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validates :default_artifacts_expire_in, presence: true, duration: true

  validates :container_registry_token_expire_delay,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validates :repository_storages, presence: true
  validate :check_repository_storages

  validates :auto_devops_domain,
            allow_blank: true,
            hostname: { allow_numeric_hostname: true, require_valid_tld: true },
            if: :auto_devops_enabled?

  validates :enabled_git_access_protocol,
            inclusion: { in: %w(ssh http), allow_blank: true, allow_nil: true }

  validates :domain_blacklist,
            presence: { message: 'Domain blacklist cannot be empty if Blacklist is enabled.' },
            if: :domain_blacklist_enabled?

  validates :housekeeping_incremental_repack_period,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validates :housekeeping_full_repack_period,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: :housekeeping_incremental_repack_period }

  validates :housekeeping_gc_period,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: :housekeeping_full_repack_period }

  validates :terminal_max_session_time,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :polling_interval_multiplier,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }

  validates :gitaly_timeout_default,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :gitaly_timeout_medium,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gitaly_timeout_medium,
            numericality: { less_than_or_equal_to: :gitaly_timeout_default },
            if: :gitaly_timeout_default
  validates :gitaly_timeout_medium,
            numericality: { greater_than_or_equal_to: :gitaly_timeout_fast },
            if: :gitaly_timeout_fast

  validates :gitaly_timeout_fast,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :gitaly_timeout_fast,
            numericality: { less_than_or_equal_to: :gitaly_timeout_default },
            if: :gitaly_timeout_default

  validates :diff_max_patch_bytes,
            presence: true,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: Gitlab::Git::Diff::DEFAULT_MAX_PATCH_BYTES,
                            less_than_or_equal_to: Gitlab::Git::Diff::MAX_PATCH_BYTES_UPPER_BOUND }

  validates :user_default_internal_regex, js_regex: true, allow_nil: true

  validates :commit_email_hostname, format: { with: /\A[^@]+\z/ }

  validates :archive_builds_in_seconds,
            allow_nil: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1.day.seconds }

  validates :local_markdown_version,
            allow_nil: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 65536 }

  SUPPORTED_KEY_TYPES.each do |type|
    validates :"#{type}_key_restriction", presence: true, key_restriction: { type: type }
  end

  validates :allowed_key_types, presence: true

  validates_each :restricted_visibility_levels do |record, attr, value|
    value&.each do |level|
      unless Gitlab::VisibilityLevel.options.value?(level)
        record.errors.add(attr, _("'%{level}' is not a valid visibility level") % { level: level })
      end
    end
  end

  validates_each :import_sources do |record, attr, value|
    value&.each do |source|
      unless Gitlab::ImportSources.options.value?(source)
        record.errors.add(attr, _("'%{source}' is not a import source") % { source: source })
      end
    end
  end

  validate :terms_exist, if: :enforce_terms?

  validates :external_authorization_service_default_label,
            presence: true,
            if: :external_authorization_service_enabled

  validates :external_authorization_service_url,
            addressable_url: true, allow_blank: true,
            if: :external_authorization_service_enabled

  validates :external_authorization_service_timeout,
            numericality: { greater_than: 0, less_than_or_equal_to: 10 },
            if: :external_authorization_service_enabled

  validates :external_auth_client_key,
            presence: true,
            if: -> (setting) { setting.external_auth_client_cert.present? }

  validates :lets_encrypt_notification_email,
            devise_email: true,
            format: { without: /@example\.(com|org|net)\z/,
                      message: N_("Let's Encrypt does not accept emails on example.com") },
            allow_blank: true

  validates :lets_encrypt_notification_email,
            presence: true,
            if: :lets_encrypt_terms_of_service_accepted?

  validates_with X509CertificateCredentialsValidator,
                 certificate: :external_auth_client_cert,
                 pkey: :external_auth_client_key,
                 pass: :external_auth_client_key_pass,
                 if: -> (setting) { setting.external_auth_client_cert.present? }

  attr_encrypted :external_auth_client_key,
                 mode: :per_attribute_iv,
                 key: Settings.attr_encrypted_db_key_base_truncated,
                 algorithm: 'aes-256-gcm',
                 encode: true

  attr_encrypted :external_auth_client_key_pass,
                 mode: :per_attribute_iv,
                 key: Settings.attr_encrypted_db_key_base_truncated,
                 algorithm: 'aes-256-gcm',
                 encode: true

  attr_encrypted :lets_encrypt_private_key,
                 mode: :per_attribute_iv,
                 key: Settings.attr_encrypted_db_key_base_truncated,
                 algorithm: 'aes-256-gcm',
                 encode: true

  before_validation :ensure_uuid!
  before_validation :strip_sentry_values

  before_save :ensure_runners_registration_token
  before_save :ensure_health_check_access_token

  after_commit do
    reset_memoized_terms
  end
  after_commit :expire_performance_bar_allowed_user_ids_cache, if: -> { previous_changes.key?('performance_bar_allowed_group_id') }

  def self.create_from_defaults
    transaction(requires_new: true) do
      super
    end
  rescue ActiveRecord::RecordNotUnique
    # We already have an ApplicationSetting record, so just return it.
    current_without_cache
  end
end

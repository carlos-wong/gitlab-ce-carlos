# frozen_string_literal: true

module ApplicationSettingsHelper
  extend self

  delegate  :allow_signup?,
            :gravatar_enabled?,
            :password_authentication_enabled_for_web?,
            :akismet_enabled?,
            to: :'Gitlab::CurrentSettings.current_application_settings'

  def user_oauth_applications?
    Gitlab::CurrentSettings.user_oauth_applications
  end

  def allowed_protocols_present?
    Gitlab::CurrentSettings.enabled_git_access_protocol.present?
  end

  def enabled_protocol
    case Gitlab::CurrentSettings.enabled_git_access_protocol
    when 'http'
      Gitlab.config.gitlab.protocol
    when 'ssh'
      'ssh'
    end
  end

  def all_protocols_enabled?
    Gitlab::CurrentSettings.enabled_git_access_protocol.blank?
  end

  def ssh_enabled?
    all_protocols_enabled? || enabled_protocol == 'ssh'
  end

  def http_enabled?
    all_protocols_enabled? || Gitlab::CurrentSettings.enabled_git_access_protocol == 'http'
  end

  def enabled_project_button(project, protocol)
    case protocol
    when 'ssh'
      ssh_clone_button(project, append_link: false)
    else
      http_clone_button(project, append_link: false)
    end
  end

  # Return a group of checkboxes that use Bootstrap's button plugin for a
  # toggle button effect.
  def restricted_level_checkboxes(help_block_id, checkbox_name, options = {})
    Gitlab::VisibilityLevel.values.map do |level|
      checked = restricted_visibility_levels(true).include?(level)
      css_class = checked ? 'active' : ''
      tag_name = "application_setting_visibility_level_#{level}"

      label_tag(tag_name, class: css_class) do
        check_box_tag(checkbox_name, level, checked,
                      autocomplete: 'off',
                      'aria-describedby' => help_block_id,
                      'class' => options[:class],
                      id: tag_name) + visibility_level_icon(level) + visibility_level_label(level)
      end
    end
  end

  # Return a group of checkboxes that use Bootstrap's button plugin for a
  # toggle button effect.
  def import_sources_checkboxes(help_block_id, options = {})
    Gitlab::ImportSources.options.map do |name, source|
      checked = Gitlab::CurrentSettings.import_sources.include?(source)
      css_class = checked ? 'active' : ''
      checkbox_name = 'application_setting[import_sources][]'

      label_tag(name, class: css_class) do
        check_box_tag(checkbox_name, source, checked,
                      autocomplete: 'off',
                      'aria-describedby' => help_block_id,
                      'class' => options[:class],
                      id: name.tr(' ', '_')) + name
      end
    end
  end

  def oauth_providers_checkboxes
    button_based_providers.map do |source|
      disabled = Gitlab::CurrentSettings.disabled_oauth_sign_in_sources.include?(source.to_s)
      css_class = ['btn']
      css_class << 'active' unless disabled
      checkbox_name = 'application_setting[enabled_oauth_sign_in_sources][]'
      name = Gitlab::Auth::OAuth::Provider.label_for(source)

      label_tag(checkbox_name, class: css_class.join(' ')) do
        check_box_tag(checkbox_name, source, !disabled,
                      autocomplete: 'off',
                      id: name.tr(' ', '_')) + name
      end
    end
  end

  def key_restriction_options_for_select(type)
    bit_size_options = Gitlab::SSHPublicKey.supported_sizes(type).map do |bits|
      ["Must be at least #{bits} bits", bits]
    end

    [
      ['Are allowed', 0],
      *bit_size_options,
      ['Are forbidden', ApplicationSetting::FORBIDDEN_KEY_VALUE]
    ]
  end

  def repository_storages_options_for_select(selected)
    options = Gitlab.config.repositories.storages.map do |name, storage|
      ["#{name} - #{storage['gitaly_address']}", name]
    end

    options_for_select(options, selected)
  end

  def external_authorization_description
    _("If enabled, access to projects will be validated on an external service"\
        " using their classification label.")
  end

  def external_authorization_timeout_help_text
    _("Time in seconds GitLab will wait for a response from the external "\
        "service. When the service does not respond in time, access will be "\
        "denied.")
  end

  def external_authorization_url_help_text
    _("When leaving the URL blank, classification labels can still be "\
        "specified without disabling cross project features or performing "\
        "external authorization checks.")
  end

  def external_authorization_client_certificate_help_text
    _("The X509 Certificate to use when mutual TLS is required to communicate "\
        "with the external authorization service. If left blank, the server "\
        "certificate is still validated when accessing over HTTPS.")
  end

  def external_authorization_client_key_help_text
    _("The private key to use when a client certificate is provided. This value "\
        "is encrypted at rest.")
  end

  def external_authorization_client_pass_help_text
    _("The passphrase required to decrypt the private key. This is optional "\
        "and the value is encrypted at rest.")
  end

  def visible_attributes
    [
      :admin_notification_email,
      :after_sign_out_path,
      :after_sign_up_text,
      :akismet_api_key,
      :akismet_enabled,
      :allow_local_requests_from_hooks_and_services,
      :dns_rebinding_protection_enabled,
      :archive_builds_in_human_readable,
      :authorized_keys_enabled,
      :auto_devops_enabled,
      :auto_devops_domain,
      :clientside_sentry_dsn,
      :clientside_sentry_enabled,
      :container_registry_token_expire_delay,
      :default_artifacts_expire_in,
      :default_branch_protection,
      :default_group_visibility,
      :default_project_creation,
      :default_project_visibility,
      :default_projects_limit,
      :default_snippet_visibility,
      :disabled_oauth_sign_in_sources,
      :domain_blacklist_enabled,
      :domain_blacklist_raw,
      :domain_whitelist_raw,
      :dsa_key_restriction,
      :ecdsa_key_restriction,
      :ed25519_key_restriction,
      :email_author_in_body,
      :enabled_git_access_protocol,
      :enforce_terms,
      :first_day_of_week,
      :gitaly_timeout_default,
      :gitaly_timeout_medium,
      :gitaly_timeout_fast,
      :gravatar_enabled,
      :hashed_storage_enabled,
      :help_page_hide_commercial_content,
      :help_page_support_url,
      :help_page_text,
      :hide_third_party_offers,
      :home_page_url,
      :housekeeping_bitmaps_enabled,
      :housekeeping_enabled,
      :housekeeping_full_repack_period,
      :housekeeping_gc_period,
      :housekeeping_incremental_repack_period,
      :html_emails_enabled,
      :import_sources,
      :max_artifacts_size,
      :max_attachment_size,
      :max_pages_size,
      :metrics_enabled,
      :metrics_host,
      :metrics_method_call_threshold,
      :metrics_packet_size,
      :metrics_pool_size,
      :metrics_port,
      :metrics_sample_interval,
      :metrics_timeout,
      :mirror_available,
      :pages_domain_verification_enabled,
      :password_authentication_enabled_for_web,
      :password_authentication_enabled_for_git,
      :performance_bar_allowed_group_path,
      :performance_bar_enabled,
      :plantuml_enabled,
      :plantuml_url,
      :polling_interval_multiplier,
      :project_export_enabled,
      :prometheus_metrics_enabled,
      :recaptcha_enabled,
      :recaptcha_private_key,
      :recaptcha_site_key,
      :receive_max_input_size,
      :repository_checks_enabled,
      :repository_storages,
      :require_two_factor_authentication,
      :restricted_visibility_levels,
      :rsa_key_restriction,
      :send_user_confirmation_email,
      :sentry_dsn,
      :sentry_enabled,
      :session_expire_delay,
      :shared_runners_enabled,
      :shared_runners_text,
      :sign_in_text,
      :signup_enabled,
      :terminal_max_session_time,
      :terms,
      :throttle_authenticated_api_enabled,
      :throttle_authenticated_api_period_in_seconds,
      :throttle_authenticated_api_requests_per_period,
      :throttle_authenticated_web_enabled,
      :throttle_authenticated_web_period_in_seconds,
      :throttle_authenticated_web_requests_per_period,
      :throttle_unauthenticated_enabled,
      :throttle_unauthenticated_period_in_seconds,
      :throttle_unauthenticated_requests_per_period,
      :two_factor_grace_period,
      :unique_ips_limit_enabled,
      :unique_ips_limit_per_user,
      :unique_ips_limit_time_window,
      :usage_ping_enabled,
      :instance_statistics_visibility_private,
      :user_default_external,
      :user_show_add_ssh_key_message,
      :user_default_internal_regex,
      :user_oauth_applications,
      :version_check_enabled,
      :web_ide_clientside_preview_enabled,
      :diff_max_patch_bytes,
      :commit_email_hostname,
      :protected_ci_variables,
      :local_markdown_version
    ]
  end

  def external_authorization_service_attributes
    [
      :external_auth_client_cert,
      :external_auth_client_key,
      :external_auth_client_key_pass,
      :external_authorization_service_default_label,
      :external_authorization_service_enabled,
      :external_authorization_service_timeout,
      :external_authorization_service_url
    ]
  end

  def expanded_by_default?
    Rails.env.test?
  end

  def instance_clusters_enabled?
    can?(current_user, :read_cluster, Clusters::Instance.new)
  end
end

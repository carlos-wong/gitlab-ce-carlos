# frozen_string_literal: true

class WebHook < ApplicationRecord
  include Sortable
  include WebHooks::AutoDisabling

  InterpolationError = Class.new(StandardError)

  SECRET_MASK = '************'

  attr_encrypted :token,
                 mode: :per_attribute_iv,
                 algorithm: 'aes-256-gcm',
                 key: Settings.attr_encrypted_db_key_base_32

  attr_encrypted :url,
                 mode: :per_attribute_iv,
                 algorithm: 'aes-256-gcm',
                 key: Settings.attr_encrypted_db_key_base_32

  attr_encrypted :url_variables,
                 mode: :per_attribute_iv,
                 key: Settings.attr_encrypted_db_key_base_32,
                 algorithm: 'aes-256-gcm',
                 marshal: true,
                 marshaler: ::Gitlab::Json,
                 encode: false,
                 encode_iv: false

  has_many :web_hook_logs

  validates :url, presence: true
  validates :url, public_url: true, unless: ->(hook) { hook.is_a?(SystemHook) || hook.url_variables? }

  validates :token, format: { without: /\n/ }
  after_initialize :initialize_url_variables

  before_validation :reset_token
  before_validation :reset_url_variables, unless: ->(hook) { hook.is_a?(ServiceHook) }, on: :update
  before_validation :set_branch_filter_nil, if: :branch_filter_strategy_all_branches?
  validates :push_events_branch_filter, untrusted_regexp: true, if: :branch_filter_strategy_regex?
  validates :push_events_branch_filter, "web_hooks/wildcard_branch_filter": true, if: :branch_filter_strategy_wildcard?

  validates :url_variables, json_schema: { filename: 'web_hooks_url_variables' }
  validate :no_missing_url_variables
  validates :interpolated_url, public_url: true, if: ->(hook) { hook.url_variables? && hook.errors.empty? }

  enum branch_filter_strategy: {
    wildcard: 0,
    regex: 1,
    all_branches: 2
  }, _prefix: true

  # rubocop: disable CodeReuse/ServiceClass
  def execute(data, hook_name, force: false)
    # hook.executable? is checked in WebHookService#execute
    WebHookService.new(self, data, hook_name, force: force).execute
  end
  # rubocop: enable CodeReuse/ServiceClass

  # rubocop: disable CodeReuse/ServiceClass
  def async_execute(data, hook_name)
    WebHookService.new(self, data, hook_name).async_execute if executable?
  end
  # rubocop: enable CodeReuse/ServiceClass

  # Allow urls pointing localhost and the local network
  def allow_local_requests?
    Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
  end

  def help_path
    'user/project/integrations/webhooks'
  end

  # @return [Boolean] Whether or not the WebHook is currently throttled.
  def rate_limited?
    rate_limiter.rate_limited?
  end

  # @return [Integer] The rate limit for the WebHook. `0` for no limit.
  def rate_limit
    rate_limiter.limit
  end

  # Returns the associated Project or Group for the WebHook if one exists.
  # Overridden by inheriting classes.
  def parent
  end

  # Custom attributes to be included in the worker context.
  def application_context
    { related_class: type }
  end

  # Exclude binary columns by default - they have no sensible JSON encoding
  def serializable_hash(options = nil)
    options = options.try(:dup) || {}
    options[:except] = Array(options[:except]).dup
    options[:except].concat [:encrypted_url_variables, :encrypted_url_variables_iv]

    super(options)
  end

  # See app/validators/json_schemas/web_hooks_url_variables.json
  VARIABLE_REFERENCE_RE = /\{([A-Za-z]+[0-9]*(?:[._-][A-Za-z0-9]+)*)\}/.freeze

  def interpolated_url(url = self.url, url_variables = self.url_variables)
    return url unless url.include?('{')

    vars = url_variables
    url.gsub(VARIABLE_REFERENCE_RE) do
      vars.fetch(_1.delete_prefix('{').delete_suffix('}'))
    end
  rescue KeyError => e
    raise InterpolationError, "Invalid URL template. Missing key #{e.key}"
  end

  def update_last_failure
    # Overridden in child classes.
  end

  def masked_token
    token.present? ? SECRET_MASK : nil
  end

  private

  def reset_token
    self.token = nil if url_changed? && !encrypted_token_changed?
  end

  def reset_url_variables
    interpolated_url_was = interpolated_url(decrypt_url_was, url_variables_were)

    return if url_variables_were.empty? || interpolated_url_was == interpolated_url

    self.url_variables = {} if url_changed? && url_variables_were.to_a.intersection(url_variables.to_a).any?
  end

  def decrypt_url_was
    self.class.decrypt_url(encrypted_url_was, iv: Base64.decode64(encrypted_url_iv_was))
  end

  def url_variables_were
    self.class.decrypt_url_variables(encrypted_url_variables_was, iv: encrypted_url_variables_iv_was)
  end

  def initialize_url_variables
    self.url_variables = {} if encrypted_url_variables.nil?
  end

  def rate_limiter
    @rate_limiter ||= Gitlab::WebHooks::RateLimiter.new(self)
  end

  def no_missing_url_variables
    return if url.nil?

    variable_names = url_variables.keys
    used_variables = url.scan(VARIABLE_REFERENCE_RE).map(&:first)

    missing = used_variables - variable_names

    return if missing.empty?

    errors.add(:url, "Invalid URL template. Missing keys: #{missing}")
  end

  def set_branch_filter_nil
    self.push_events_branch_filter = nil
  end
end

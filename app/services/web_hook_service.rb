# frozen_string_literal: true

class WebHookService
  class InternalErrorResponse
    ERROR_MESSAGE = 'internal error'

    attr_reader :body, :headers, :code

    def success?
      false
    end

    def redirection?
      false
    end

    def internal_server_error?
      true
    end

    def initialize
      @headers = Gitlab::HTTP::Response::Headers.new({})
      @body = ''
      @code = ERROR_MESSAGE
    end
  end

  REQUEST_BODY_SIZE_LIMIT = 25.megabytes
  # Response body is for UI display only. It does not make much sense to save
  # whatever the receivers throw back at us
  RESPONSE_BODY_SIZE_LIMIT = 8.kilobytes
  # The headers are for debugging purpose. They are displayed on the UI only.
  RESPONSE_HEADERS_COUNT_LIMIT = 50
  RESPONSE_HEADERS_SIZE_LIMIT = 1.kilobytes

  attr_accessor :hook, :data, :hook_name, :request_options
  attr_reader :uniqueness_token

  def self.hook_to_event(hook_name)
    hook_name.to_s.singularize.titleize
  end

  def initialize(hook, data, hook_name, uniqueness_token = nil, force: false)
    @hook = hook
    @data = data.to_h
    @hook_name = hook_name.to_s
    @uniqueness_token = uniqueness_token
    @force = force
    @request_options = {
      timeout: Gitlab.config.gitlab.webhook_timeout,
      allow_local_requests: hook.allow_local_requests?
    }
  end

  def disabled?
    !@force && !hook.executable?
  end

  def execute
    return { status: :error, message: 'Hook disabled' } if disabled?

    if recursion_blocked?
      log_recursion_blocked
      return { status: :error, message: 'Recursive webhook blocked' }
    end

    Gitlab::WebHooks::RecursionDetection.register!(hook)

    start_time = Gitlab::Metrics::System.monotonic_time

    response = if parsed_url.userinfo.blank?
                 make_request(parsed_url.to_s)
               else
                 make_request_with_auth
               end

    log_execution(
      response: response,
      execution_duration: Gitlab::Metrics::System.monotonic_time - start_time
    )

    {
      status: :success,
      http_status: response.code,
      message: response.body
    }
  rescue *Gitlab::HTTP::HTTP_ERRORS,
         Gitlab::Json::LimitedEncoder::LimitExceeded, URI::InvalidURIError => e
    execution_duration = Gitlab::Metrics::System.monotonic_time - start_time
    error_message = e.to_s

    log_execution(
      response: InternalErrorResponse.new,
      execution_duration: execution_duration,
      error_message: error_message
    )

    Gitlab::AppLogger.error("WebHook Error after #{execution_duration.to_i.seconds}s => #{e}")

    {
      status: :error,
      message: error_message
    }
  end

  def async_execute
    Gitlab::ApplicationContext.with_context(hook.application_context) do
      break log_rate_limited if rate_limit!
      break log_recursion_blocked if recursion_blocked?

      params = {
        recursion_detection_request_uuid: Gitlab::WebHooks::RecursionDetection::UUID.instance.request_uuid
      }.compact

      WebHookWorker.perform_async(hook.id, data, hook_name, params)
    end
  end

  private

  def parsed_url
    @parsed_url ||= URI.parse(hook.interpolated_url)
  rescue WebHook::InterpolationError => e
    # Behavior-preserving fallback.
    Gitlab::ErrorTracking.track_exception(e)
    @parsed_url = URI.parse(hook.url)
  end

  def make_request(url, basic_auth = false)
    Gitlab::HTTP.post(url,
      body: Gitlab::Json::LimitedEncoder.encode(data, limit: REQUEST_BODY_SIZE_LIMIT),
      headers: build_headers,
      verify: hook.enable_ssl_verification,
      basic_auth: basic_auth,
      **request_options)
  end

  def make_request_with_auth
    post_url = parsed_url.to_s.gsub("#{parsed_url.userinfo}@", '')
    basic_auth = {
      username: CGI.unescape(parsed_url.user),
      password: CGI.unescape(parsed_url.password.presence || '')
    }
    make_request(post_url, basic_auth)
  end

  def log_execution(response:, execution_duration:, error_message: nil)
    category = response_category(response)
    log_data = {
      trigger: hook_name,
      url: hook.url,
      execution_duration: execution_duration,
      request_headers: build_headers,
      request_data: data,
      response_headers: safe_response_headers(response),
      response_body: safe_response_body(response),
      response_status: response.code,
      internal_error_message: error_message
    }

    if @force # executed as part of test - run log-execution inline.
      ::WebHooks::LogExecutionService.new(hook: hook, log_data: log_data, response_category: category).execute
    else
      queue_log_execution_with_retry(log_data, category)
    end
  end

  def queue_log_execution_with_retry(log_data, category)
    retried = false
    begin
      ::WebHooks::LogExecutionWorker.perform_async(hook.id, log_data, category, uniqueness_token)
    rescue Gitlab::SidekiqMiddleware::SizeLimiter::ExceedLimitError
      raise if retried

      # Strip request data
      log_data[:request_data] = ::WebHookLog::OVERSIZE_REQUEST_DATA
      retried = true
      retry
    end
  end

  def response_category(response)
    if response.success? || response.redirection?
      :ok
    elsif response.internal_server_error?
      :error
    else
      :failed
    end
  end

  def build_headers
    @headers ||= begin
      headers = {
        'Content-Type' => 'application/json',
        'User-Agent' => "GitLab/#{Gitlab::VERSION}",
        Gitlab::WebHooks::GITLAB_EVENT_HEADER => self.class.hook_to_event(hook_name)
      }

      headers['X-Gitlab-Token'] = Gitlab::Utils.remove_line_breaks(hook.token) if hook.token.present?
      headers.merge!(Gitlab::WebHooks::RecursionDetection.header(hook))
    end
  end

  # Make response headers more stylish
  # Net::HTTPHeader has downcased hash with arrays: { 'content-type' => ['text/html; charset=utf-8'] }
  # This method format response to capitalized hash with strings: { 'Content-Type' => 'text/html; charset=utf-8' }
  # rubocop:disable Style/HashTransformValues
  def safe_response_headers(response)
    response.headers.each_capitalized.first(RESPONSE_HEADERS_COUNT_LIMIT).to_h do |header_key, header_value|
      [enforce_utf8(header_key), string_size_limit(enforce_utf8(header_value), RESPONSE_HEADERS_SIZE_LIMIT)]
    end
  end
  # rubocop:enable Style/HashTransformValues

  def safe_response_body(response)
    return '' unless response.body

    response_body = enforce_utf8(response.body)
    string_size_limit(response_body, RESPONSE_BODY_SIZE_LIMIT)
  end

  # Increments rate-limit counter.
  # Returns true if hook should be rate-limited.
  def rate_limit!
    Gitlab::WebHooks::RateLimiter.new(hook).rate_limit!
  end

  def recursion_blocked?
    Gitlab::WebHooks::RecursionDetection.block?(hook)
  end

  def log_rate_limited
    log_auth_error('Webhook rate limit exceeded')
  end

  def log_recursion_blocked
    log_auth_error(
      'Recursive webhook blocked from executing',
      recursion_detection: ::Gitlab::WebHooks::RecursionDetection.to_log(hook)
    )
  end

  def log_auth_error(message, params = {})
    Gitlab::AuthLogger.error(
      params.merge(
        { message: message, hook_id: hook.id, hook_type: hook.type, hook_name: hook_name },
        Gitlab::ApplicationContext.current
      )
    )
  end

  def string_size_limit(str, limit)
    str.truncate_bytes(limit)
  end

  def enforce_utf8(str)
    Gitlab::EncodingHelper.encode_utf8(str)
  end
end

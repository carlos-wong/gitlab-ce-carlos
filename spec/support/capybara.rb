# frozen_string_literal: true

# rubocop:disable Style/GlobalVars
require 'capybara/rails'
require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'selenium-webdriver'

# Give CI some extra time
timeout = (ENV['CI'] || ENV['CI_SERVER']) ? 60 : 30

# Define an error class for JS console messages
JSConsoleError = Class.new(StandardError)

# Filter out innocuous JS console messages
JS_CONSOLE_FILTER = Regexp.union([
  '"[HMR] Waiting for update signal from WDS..."',
  '"[WDS] Hot Module Replacement enabled."',
  '"[WDS] Live Reloading enabled."',
  'Download the Vue Devtools extension',
  'Download the Apollo DevTools'
])

CAPYBARA_WINDOW_SIZE = [1366, 768].freeze

# Run Workhorse on the given host and port, proxying to Puma on a UNIX socket,
# for a closer-to-production experience
Capybara.register_server :puma_via_workhorse do |app, port, host, **options|
  file = Tempfile.new
  socket_path = file.path
  file.close! # We just want the filename

  TestEnv.with_workhorse(TestEnv.workhorse_dir, host, port, socket_path) do
    Capybara.servers[:puma].call(app, nil, socket_path, **options)
  end
end

Capybara.register_driver :chrome do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    # This enables access to logs with `page.driver.manage.get_log(:browser)`
    loggingPrefs: {
      browser: "ALL",
      client: "ALL",
      driver: "ALL",
      server: "ALL"
    }
  )

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("window-size=#{CAPYBARA_WINDOW_SIZE.join(',')}")

  # Chrome won't work properly in a Docker container in sandbox mode
  options.add_argument("no-sandbox")

  # Run headless by default unless CHROME_HEADLESS specified
  options.add_argument("headless") unless ENV['CHROME_HEADLESS'] =~ /^(false|no|0)$/i

  # Disable /dev/shm use in CI. See https://gitlab.com/gitlab-org/gitlab/issues/4252
  options.add_argument("disable-dev-shm-usage") if ENV['CI'] || ENV['CI_SERVER']

  # Explicitly set user-data-dir to prevent crashes. See https://gitlab.com/gitlab-org/gitlab-foss/issues/58882#note_179811508
  options.add_argument("user-data-dir=/tmp/chrome") if ENV['CI'] || ENV['CI_SERVER']

  # Chrome 75 defaults to W3C mode which doesn't allow console log access
  options.add_option(:w3c, false)

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    desired_capabilities: capabilities,
    options: options
  )
end

Capybara.server = :puma_via_workhorse
Capybara.javascript_driver = :chrome
Capybara.default_max_wait_time = timeout
Capybara.ignore_hidden_elements = true
Capybara.default_normalize_ws = true
Capybara.enable_aria_label = true

Capybara::Screenshot.append_timestamp = false

Capybara::Screenshot.register_filename_prefix_formatter(:rspec) do |example|
  example.full_description.downcase.parameterize(separator: "_")[0..99]
end
# Keep only the screenshots generated from the last failing test suite
Capybara::Screenshot.prune_strategy = :keep_last_run
# From https://github.com/mattheworiordan/capybara-screenshot/issues/84#issuecomment-41219326
Capybara::Screenshot.register_driver(:chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end

RSpec.configure do |config|
  config.include CapybaraHelpers, type: :feature

  config.before(:context, :js) do
    next if $capybara_server_already_started

    TestEnv.eager_load_driver_server
    $capybara_server_already_started = true
  end

  config.before(:example, :js) do
    session = Capybara.current_session

    allow(Gitlab::Application.routes).to receive(:default_url_options).and_return(
      host: session.server.host,
      port: session.server.port,
      protocol: 'http')

    # reset window size between tests
    unless session.current_window.size == CAPYBARA_WINDOW_SIZE
      begin
        session.current_window.resize_to(*CAPYBARA_WINDOW_SIZE)
      rescue # ?
      end
    end
  end

  # The :capybara_ignore_server_errors metadata means unhandled exceptions raised
  # by the application under test will not necessarily fail the server. This is
  # useful when testing conditions that are expected to raise a 500 error in
  # production; it should not be used on the happy path.
  config.around(:each, :capybara_ignore_server_errors) do |example|
    Capybara.raise_server_errors = false

    example.run

    if example.metadata[:screenshot]
      screenshot = example.metadata[:screenshot][:image] || example.metadata[:screenshot][:html]
      example.metadata[:stdout] = %{[[ATTACHMENT|#{screenshot}]]}
    end

  ensure
    Capybara.raise_server_errors = true
  end

  config.after(:example, :js) do |example|
    # when a test fails, display any messages in the browser's console
    # but fail don't add the message if the failure is a pending test that got
    # fixed. If we raised the `JSException` the fixed test would be marked as
    # failed again.
    if example.exception && !example.exception.is_a?(RSpec::Core::Pending::PendingExampleFixedError)
      console = page.driver.browser.manage.logs.get(:browser)&.reject { |log| log.message =~ JS_CONSOLE_FILTER }

      if console.present?
        message = "Unexpected browser console output:\n" + console.map(&:message).join("\n")
        raise JSConsoleError, message
      end
    end

    # prevent localStorage from introducing side effects based on test order
    unless ['', 'about:blank', 'data:,'].include? Capybara.current_session.driver.browser.current_url
      execute_script("localStorage.clear();")
    end

    # capybara/rspec already calls Capybara.reset_sessions! in an `after` hook,
    # but `block_and_wait_for_requests_complete` is called before it so by
    # calling it explicitly here, we prevent any new requests from being fired
    # See https://github.com/teamcapybara/capybara/blob/ffb41cfad620de1961bb49b1562a9fa9b28c0903/lib/capybara/rspec.rb#L20-L25
    # We don't reset the session when the example failed, because we need capybara-screenshot to have access to it.
    Capybara.reset_sessions! unless example.exception
    block_and_wait_for_requests_complete
  end
end

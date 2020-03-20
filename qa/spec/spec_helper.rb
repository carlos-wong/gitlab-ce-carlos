# frozen_string_literal: true

require_relative '../qa'
require 'rspec/retry'

if ENV['CI'] && QA::Runtime::Env.knapsack? && !ENV['NO_KNAPSACK']
  require 'knapsack'
  Knapsack::Adapters::RSpecAdapter.bind
end

QA::Runtime::Browser.configure!

QA::Runtime::Scenario.from_env(QA::Runtime::Env.runtime_scenario_attributes) if QA::Runtime::Env.runtime_scenario_attributes

Dir[::File.join(__dir__, "support/helpers/*.rb")].each { |f| require f }
Dir[::File.join(__dir__, "support/shared_contexts/*.rb")].each { |f| require f }
Dir[::File.join(__dir__, "support/shared_examples/*.rb")].each { |f| require f }

RSpec.configure do |config|
  QA::Specs::Helpers::Quarantine.configure_rspec

  config.before do |example|
    QA::Runtime::Logger.debug("\nStarting test: #{example.full_description}\n")
  end

  config.after(:context) do
    if !QA::Runtime::Browser.blank_page? && QA::Page::Main::Menu.perform(&:signed_in?)
      QA::Page::Main::Menu.perform(&:sign_out)
      raise(
        <<~ERROR
          The test left the browser signed in.

          Usually, Capybara prevents this from happening but some things can
          interfere. For example, if it has an `after(:context)` block that logs
          in, the browser will stay logged in and this will cause the next test
          to fail.

          Please make sure the test does not leave the browser signed in.
        ERROR
      )
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.expose_dsl_globally = true
  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # show retry status in spec process
  config.verbose_retry = true

  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  if ENV['CI'] && !QA::Runtime::Env.disable_rspec_retry?
    config.around do |example|
      retry_times = example.metadata.key?(:quarantine) ? 1 : 2
      example.run_with_retry retry: retry_times
    end
  end
end

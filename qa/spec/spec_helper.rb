require_relative '../qa'
require 'rspec/retry'

%w[helpers shared_examples].each do |d|
  Dir[::File.join(__dir__, d, '**', '*.rb')].each { |f| require f }
end

RSpec.configure do |config|
  QA::Specs::Helpers::Quarantine.configure_rspec

  config.before do |example|
    QA::Runtime::Logger.debug("Starting test: #{example.full_description}") if QA::Runtime::Env.debug?
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

  config.around do |example|
    retry_times = example.metadata.keys.include?(:quarantine) ? 1 : 3
    example.run_with_retry retry: retry_times
  end
end

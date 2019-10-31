# frozen_string_literal: true

shared_context 'rack attack cache store' do
  around do |example|
    # Instead of test environment's :null_store so the throttles can increment
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    # Make time-dependent tests deterministic
    Timecop.freeze { example.run }

    Rack::Attack.cache.store = Rails.cache
  end
end

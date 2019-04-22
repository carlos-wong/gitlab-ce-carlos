# frozen_string_literal: true

require 'spec_helper'

describe RepositoryCheck::DispatchWorker do
  subject { described_class.new }

  it 'does nothing when repository checks are disabled' do
    stub_application_setting(repository_checks_enabled: false)

    expect(RepositoryCheck::BatchWorker).not_to receive(:perform_async)

    subject.perform
  end

  it 'does nothing if the exclusive lease is taken' do
    allow(subject).to receive(:try_obtain_lease).and_return(false)

    expect(RepositoryCheck::BatchWorker).not_to receive(:perform_async)

    subject.perform
  end

  it 'dispatches work to RepositoryCheck::BatchWorker' do
    expect(RepositoryCheck::BatchWorker).to receive(:perform_async).at_least(:once)

    subject.perform
  end

  context 'with unhealthy shard' do
    let(:default_shard_name) { 'default' }
    let(:unhealthy_shard_name) { 'unhealthy' }
    let(:default_shard) { Gitlab::HealthChecks::Result.new(true, nil, shard: default_shard_name) }
    let(:unhealthy_shard) { Gitlab::HealthChecks::Result.new(false, '14:Connect Failed', shard: unhealthy_shard_name) }

    before do
      allow(Gitlab::HealthChecks::GitalyCheck).to receive(:readiness).and_return([default_shard, unhealthy_shard])
    end

    it 'only triggers RepositoryCheck::BatchWorker for healthy shards' do
      expect(RepositoryCheck::BatchWorker).to receive(:perform_async).with('default')

      subject.perform
    end
  end
end

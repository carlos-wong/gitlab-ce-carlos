# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Helpers::Runner do
  let(:helper) { Class.new { include API::Ci::Helpers::Runner }.new }

  before do
    allow(helper).to receive(:env).and_return({})
  end

  describe '#current_job' do
    let(:build) { create(:ci_build, :running) }

    it 'handles sticking of a build when a build ID is specified' do
      allow(helper).to receive(:params).and_return(id: build.id)

      expect(Ci::Build.sticking)
        .to receive(:stick_or_unstick_request)
        .with({}, :build, build.id)

      helper.current_job
    end

    it 'does not handle sticking if no build ID was specified' do
      allow(helper).to receive(:params).and_return({})

      expect(Ci::Build.sticking)
        .not_to receive(:stick_or_unstick_request)

      helper.current_job
    end

    it 'returns the build if one could be found' do
      allow(helper).to receive(:params).and_return(id: build.id)

      expect(helper.current_job).to eq(build)
    end
  end

  describe '#current_runner' do
    let(:runner) { create(:ci_runner, token: 'foo') }

    it 'handles sticking of a runner if a token is specified' do
      allow(helper).to receive(:params).and_return(token: runner.token)

      expect(Ci::Runner.sticking)
        .to receive(:stick_or_unstick_request)
        .with({}, :runner, runner.token)

      helper.current_runner
    end

    it 'does not handle sticking if no token was specified' do
      allow(helper).to receive(:params).and_return({})

      expect(Ci::Runner.sticking)
        .not_to receive(:stick_or_unstick_request)

      helper.current_runner
    end

    it 'returns the runner if one could be found' do
      allow(helper).to receive(:params).and_return(token: runner.token)

      expect(helper.current_runner).to eq(runner)
    end
  end

  describe '#track_runner_authentication', :prometheus do
    subject { helper.track_runner_authentication }

    let(:runner) { create(:ci_runner, token: 'foo') }

    it 'increments gitlab_ci_runner_authentication_success_total' do
      allow(helper).to receive(:params).and_return(token: runner.token)

      success_counter = ::Gitlab::Ci::Runner::Metrics.runner_authentication_success_counter
      failure_counter = ::Gitlab::Ci::Runner::Metrics.runner_authentication_failure_counter
      expect { subject }.to change { success_counter.get(runner_type: 'instance_type') }.by(1)
        .and not_change { success_counter.get(runner_type: 'project_type') }
        .and not_change { failure_counter.get }
    end

    it 'increments gitlab_ci_runner_authentication_failure_total' do
      allow(helper).to receive(:params).and_return(token: 'invalid')

      success_counter = ::Gitlab::Ci::Runner::Metrics.runner_authentication_success_counter
      failure_counter = ::Gitlab::Ci::Runner::Metrics.runner_authentication_failure_counter
      expect { subject }.to change { failure_counter.get }.by(1)
        .and not_change { success_counter.get(runner_type: 'instance_type') }
        .and not_change { success_counter.get(runner_type: 'project_type') }
    end
  end
end

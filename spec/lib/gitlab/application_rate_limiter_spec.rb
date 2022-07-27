# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ApplicationRateLimiter, :clean_gitlab_redis_rate_limiting do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:rate_limits) do
    {
      test_action: {
        threshold: 1,
        interval: 2.minutes
      },
      another_action: {
        threshold: -> { 2 },
        interval: -> { 3.minutes }
      }
    }
  end

  subject { described_class }

  before do
    allow(described_class).to receive(:rate_limits).and_return(rate_limits)
  end

  describe '.throttled?' do
    context 'when the key is invalid' do
      context 'is provided as a Symbol' do
        context 'but is not defined in the rate_limits Hash' do
          it 'raises an InvalidKeyError exception' do
            key = :key_not_in_rate_limits_hash

            expect { subject.throttled?(key, scope: [user]) }.to raise_error(Gitlab::ApplicationRateLimiter::InvalidKeyError)
          end
        end
      end

      context 'is provided as a String' do
        context 'and is a String representation of an existing key in rate_limits Hash' do
          it 'raises an InvalidKeyError exception' do
            key = rate_limits.keys[0].to_s

            expect { subject.throttled?(key, scope: [user]) }.to raise_error(Gitlab::ApplicationRateLimiter::InvalidKeyError)
          end
        end

        context 'but is not defined in any form in the rate_limits Hash' do
          it 'raises an InvalidKeyError exception' do
            key = 'key_not_in_rate_limits_hash'

            expect { subject.throttled?(key, scope: [user]) }.to raise_error(Gitlab::ApplicationRateLimiter::InvalidKeyError)
          end
        end
      end
    end

    context 'when the key is valid' do
      it 'records the checked key in request storage', :request_store do
        subject.throttled?(:test_action, scope: [user])

        expect(::Gitlab::Instrumentation::RateLimitingGates.payload)
          .to eq(::Gitlab::Instrumentation::RateLimitingGates::GATES => [:test_action])

        subject.throttled?(:another_action, scope: [user], peek: true)

        expect(::Gitlab::Instrumentation::RateLimitingGates.payload)
          .to eq(::Gitlab::Instrumentation::RateLimitingGates::GATES => [:test_action, :another_action])
      end
    end

    describe 'counting actions once per unique resource' do
      let(:scope) { [user, project] }

      let(:start_time) { Time.current.beginning_of_hour }
      let(:project1) { instance_double(Project, id: '1') }
      let(:project2) { instance_double(Project, id: '2') }

      it 'returns true when unique actioned resources count exceeds threshold' do
        travel_to(start_time) do
          expect(subject.throttled?(:test_action, scope: scope, resource: project1)).to eq(false)
        end

        travel_to(start_time + 1.minute) do
          expect(subject.throttled?(:test_action, scope: scope, resource: project2)).to eq(true)
        end
      end

      it 'returns false when unique actioned resource count does not exceed threshold' do
        travel_to(start_time) do
          expect(subject.throttled?(:test_action, scope: scope, resource: project1)).to eq(false)
        end

        travel_to(start_time + 1.minute) do
          expect(subject.throttled?(:test_action, scope: scope, resource: project1)).to eq(false)
        end
      end

      it 'returns false when interval has elapsed' do
        travel_to(start_time) do
          expect(subject.throttled?(:test_action, scope: scope, resource: project1)).to eq(false)
        end

        travel_to(start_time + 2.minutes) do
          expect(subject.throttled?(:test_action, scope: scope, resource: project2)).to eq(false)
        end
      end
    end

    shared_examples 'throttles based on key and scope' do
      let(:start_time) { Time.current.beginning_of_hour }

      it 'returns true when threshold is exceeded' do
        travel_to(start_time) do
          expect(subject.throttled?(:test_action, scope: scope)).to eq(false)
        end

        travel_to(start_time + 1.minute) do
          expect(subject.throttled?(:test_action, scope: scope)).to eq(true)

          # Assert that it does not affect other actions or scope
          expect(subject.throttled?(:another_action, scope: scope)).to eq(false)
          expect(subject.throttled?(:test_action, scope: [user])).to eq(false)
        end
      end

      it 'returns false when interval has elapsed' do
        travel_to(start_time) do
          expect(subject.throttled?(:test_action, scope: scope)).to eq(false)

          # another_action has a threshold of 2 so we simulate 2 requests
          expect(subject.throttled?(:another_action, scope: scope)).to eq(false)
          expect(subject.throttled?(:another_action, scope: scope)).to eq(false)
        end

        travel_to(start_time + 2.minutes) do
          expect(subject.throttled?(:test_action, scope: scope)).to eq(false)

          # Assert that another_action has its own interval that hasn't elapsed
          expect(subject.throttled?(:another_action, scope: scope)).to eq(true)
        end
      end

      it 'allows peeking at the current state without changing its value' do
        travel_to(start_time) do
          expect(subject.throttled?(:test_action, scope: scope)).to eq(false)
          2.times do
            expect(subject.throttled?(:test_action, scope: scope, peek: true)).to eq(false)
          end
          expect(subject.throttled?(:test_action, scope: scope)).to eq(true)
          expect(subject.throttled?(:test_action, scope: scope, peek: true)).to eq(true)
        end
      end
    end

    context 'when using ActiveRecord models as scope' do
      let(:scope) { [user, project] }

      it_behaves_like 'throttles based on key and scope'
    end

    context 'when using ActiveRecord models and strings as scope' do
      let(:scope) { [project, 'app/controllers/groups_controller.rb'] }

      it_behaves_like 'throttles based on key and scope'
    end
  end

  describe '.peek' do
    it 'peeks at the current state without changing its value' do
      freeze_time do
        expect(subject.peek(:test_action, scope: [user])).to eq(false)
        expect(subject.throttled?(:test_action, scope: [user])).to eq(false)
        2.times do
          expect(subject.peek(:test_action, scope: [user])).to eq(false)
        end
        expect(subject.throttled?(:test_action, scope: [user])).to eq(true)
        expect(subject.peek(:test_action, scope: [user])).to eq(true)
      end
    end
  end

  describe '.log_request' do
    let(:file_path) { 'master/README.md' }
    let(:type) { :raw_blob_request_limit }
    let(:fullpath) { "/#{project.full_path}/raw/#{file_path}" }

    let(:request) do
      double('request', ip: '127.0.0.1', request_method: 'GET', fullpath: fullpath)
    end

    let(:base_attributes) do
      {
        message: 'Application_Rate_Limiter_Request',
        env: type,
        remote_ip: '127.0.0.1',
        request_method: 'GET',
        path: fullpath
      }
    end

    context 'without a current user' do
      let(:current_user) { nil }

      it 'logs information to auth.log' do
        expect(Gitlab::AuthLogger).to receive(:error).with(base_attributes).once

        subject.log_request(request, type, current_user)
      end
    end

    context 'with a current_user' do
      let(:current_user) { user }

      let(:attributes) do
        base_attributes.merge({
                                user_id: current_user.id,
                                username: current_user.username
                              })
      end

      it 'logs information to auth.log' do
        expect(Gitlab::AuthLogger).to receive(:error).with(attributes).once

        subject.log_request(request, type, current_user)
      end
    end
  end

  context 'when interval is 0' do
    let(:rate_limits) { { test_action: { threshold: 1, interval: 0 } } }
    let(:scope) { user }
    let(:start_time) { Time.current.beginning_of_hour }

    it 'returns false' do
      travel_to(start_time) do
        expect(subject.throttled?(:test_action, scope: scope)).to eq(false)
      end

      travel_to(start_time + 1.minute) do
        expect(subject.throttled?(:test_action, scope: scope)).to eq(false)
      end
    end
  end
end

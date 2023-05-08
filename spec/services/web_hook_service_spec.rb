# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHookService, :request_store, :clean_gitlab_redis_shared_state, feature_category: :integrations do
  include StubRequests

  let(:ellipsis) { '…' }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:project_hook) { create(:project_hook, project: project) }

  let(:data) do
    { before: 'oldrev', after: 'newrev', ref: 'ref' }
  end

  let(:service_instance) { described_class.new(project_hook, data, :push_hooks) }

  describe '#initialize' do
    before do
      stub_application_setting(setting_name => setting)
    end

    shared_examples_for 'respects outbound network setting' do
      context 'when local requests are allowed' do
        let(:setting) { true }

        it { expect(hook.request_options[:allow_local_requests]).to be_truthy }
      end

      context 'when local requests are not allowed' do
        let(:setting) { false }

        it { expect(hook.request_options[:allow_local_requests]).to be_falsey }
      end
    end

    context 'when SystemHook' do
      let(:setting_name) { :allow_local_requests_from_system_hooks }
      let(:hook) { described_class.new(build(:system_hook), data, :system_hook) }

      include_examples 'respects outbound network setting'
    end

    context 'when ProjectHook' do
      let(:setting_name) { :allow_local_requests_from_web_hooks_and_services }
      let(:hook) { described_class.new(build(:project_hook), data, :project_hook) }

      include_examples 'respects outbound network setting'
    end
  end

  describe '#disabled?' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.new(hook, data, :push_hooks, force: forced) }

    let(:hook) { double(executable?: executable, allow_local_requests?: false) }

    where(:forced, :executable, :disabled) do
      false | true | false
      false | false | true
      true | true | false
      true | false | false
    end

    with_them do
      it { is_expected.to have_attributes(disabled?: disabled) }
    end
  end

  describe '#execute' do
    let!(:uuid) { SecureRandom.uuid }
    let(:headers) do
      {
        'Content-Type' => 'application/json',
        'User-Agent' => "GitLab/#{Gitlab::VERSION}",
        'X-Gitlab-Event' => 'Push Hook',
        'X-Gitlab-Event-UUID' => uuid,
        'X-Gitlab-Instance' => Gitlab.config.gitlab.base_url
      }
    end

    before do
      # Set a stable value for the `X-Gitlab-Event-UUID` header.
      Gitlab::WebHooks::RecursionDetection.set_request_uuid(uuid)
    end

    context 'when there is an interpolation error' do
      let(:error) { ::WebHook::InterpolationError.new('boom') }

      before do
        stub_full_request(project_hook.url, method: :post)
        allow(project_hook).to receive(:interpolated_url).and_raise(error)
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)

        expect(service_instance).to receive(:log_execution).with(
          execution_duration: (be > 0),
          response: have_attributes(code: 200)
        )

        service_instance.execute
      end
    end

    context 'when there are URL variables' do
      before do
        project_hook.update!(
          url: 'http://example.com/{one}/{two}',
          url_variables: { 'one' => 'a', 'two' => 'b' }
        )
      end

      it 'POSTs to the interpolated URL, and logs the hook.url' do
        stub_full_request(project_hook.interpolated_url, method: :post)

        expect(service_instance).to receive(:queue_log_execution_with_retry).with(
          include(url: project_hook.url),
          :ok
        )

        service_instance.execute

        expect(WebMock)
          .to have_requested(:post, stubbed_hostname(project_hook.interpolated_url)).once
      end

      context 'there is userinfo' do
        before do
          project_hook.update!(
            url: 'http://{foo}:{bar}@example.com',
            url_variables: { 'foo' => 'a', 'bar' => 'b' }
          )
          stub_full_request('http://example.com', method: :post)
        end

        it 'POSTs to the interpolated URL, and logs the hook.url' do
          expect(service_instance).to receive(:queue_log_execution_with_retry).with(
            include(url: project_hook.url),
            :ok
          )

          service_instance.execute

          expect(WebMock)
            .to have_requested(:post, stubbed_hostname('http://example.com'))
            .with(headers: headers.merge('Authorization' => 'Basic YTpi'))
            .once
        end
      end
    end

    context 'when token is defined' do
      before do
        project_hook.token = generate(:token)
      end

      it 'POSTs to the webhook URL' do
        stub_full_request(project_hook.url, method: :post)

        service_instance.execute

        expect(WebMock).to have_requested(:post, stubbed_hostname(project_hook.url)).with(
          headers: headers.merge({ 'X-Gitlab-Token' => project_hook.token })
        ).once
      end
    end

    it 'POSTs the data as JSON and returns expected headers' do
      stub_full_request(project_hook.url, method: :post)

      service_instance.execute

      expect(WebMock).to have_requested(:post, stubbed_hostname(project_hook.url)).with(
        headers: headers
      ).once
    end

    context 'when the data is a Gitlab::DataBuilder::Pipeline' do
      let(:pipeline) { create(:ci_pipeline, project: project) }
      let(:data) { ::Gitlab::DataBuilder::Pipeline.new(pipeline) }

      it 'can log the request payload' do
        stub_full_request(project_hook.url, method: :post)

        # we call this with force to ensure that the logs are written inline,
        # which tests that we can serialize the data to the DB correctly.
        service = described_class.new(project_hook, data, :push_hooks, force: true)

        expect { service.execute }.to change(::WebHookLog, :count).by(1)
      end
    end

    context 'when auth credentials are present' do
      let_it_be(:url) { 'https://example.org' }
      let_it_be(:project_hook) { create(:project_hook, url: 'https://demo:demo@example.org/') }

      it 'uses the credentials' do
        stub_full_request(url, method: :post)

        service_instance.execute

        expect(WebMock).to have_requested(:post, stubbed_hostname(url)).with(
          headers: headers.merge('Authorization' => 'Basic ZGVtbzpkZW1v')
        ).once
      end
    end

    context 'when auth credentials are partial present' do
      let_it_be(:url) { 'https://example.org' }
      let_it_be(:project_hook) { create(:project_hook, url: 'https://demo@example.org/') }

      it 'uses the credentials anyways' do
        stub_full_request(url, method: :post)

        service_instance.execute

        expect(WebMock).to have_requested(:post, stubbed_hostname(url)).with(
          headers: headers.merge('Authorization' => 'Basic ZGVtbzo=')
        ).once
      end
    end

    it 'catches exceptions' do
      stub_full_request(project_hook.url, method: :post).to_raise(StandardError.new('Some error'))

      expect { service_instance.execute }.to raise_error(StandardError)
    end

    it 'does not execute disabled hooks' do
      allow(service_instance).to receive(:disabled?).and_return(true)

      expect(service_instance.execute).to have_attributes(status: :error, message: 'Hook disabled')
    end

    it 'executes and registers the hook with the recursion detection', :aggregate_failures do
      stub_full_request(project_hook.url, method: :post)
      cache_key = Gitlab::WebHooks::RecursionDetection.send(:cache_key_for_hook, project_hook)

      ::Gitlab::Redis::SharedState.with do |redis|
        expect { service_instance.execute }.to change {
          redis.sismember(cache_key, project_hook.id)
        }.to(true)
      end

      expect(WebMock).to have_requested(:post, stubbed_hostname(project_hook.url))
        .with(headers: headers)
        .once
    end

    it 'blocks and logs if a recursive web hook is detected', :aggregate_failures do
      stub_full_request(project_hook.url, method: :post)
      Gitlab::WebHooks::RecursionDetection.register!(project_hook)

      expect(Gitlab::AuthLogger).to receive(:error).with(
        include(
          message: 'Recursive webhook blocked from executing',
          hook_id: project_hook.id,
          hook_type: 'ProjectHook',
          hook_name: 'push_hooks',
          recursion_detection: Gitlab::WebHooks::RecursionDetection.to_log(project_hook),
          'correlation_id' => kind_of(String)
        )
      )

      service_instance.execute

      expect(WebMock).not_to have_requested(:post, stubbed_hostname(project_hook.url))
    end

    it 'blocks and logs if the recursion count limit would be exceeded', :aggregate_failures do
      stub_full_request(project_hook.url, method: :post)
      stub_const("#{Gitlab::WebHooks::RecursionDetection.name}::COUNT_LIMIT", 3)
      previous_hooks = create_list(:project_hook, 3)
      previous_hooks.each { Gitlab::WebHooks::RecursionDetection.register!(_1) }

      expect(Gitlab::AuthLogger).to receive(:error).with(
        include(
          message: 'Recursive webhook blocked from executing',
          hook_id: project_hook.id,
          hook_type: 'ProjectHook',
          hook_name: 'push_hooks',
          recursion_detection: Gitlab::WebHooks::RecursionDetection.to_log(project_hook),
          'correlation_id' => kind_of(String)
        )
      )

      service_instance.execute

      expect(WebMock).not_to have_requested(:post, stubbed_hostname(project_hook.url))
    end

    it 'handles exceptions' do
      exceptions = Gitlab::HTTP::HTTP_ERRORS + [
        Gitlab::Json::LimitedEncoder::LimitExceeded, URI::InvalidURIError
      ]

      allow(Gitlab::WebHooks::RecursionDetection).to receive(:block?).and_return(false)

      exceptions.each do |exception_class|
        exception = exception_class.new('Exception message')
        project_hook.enable!

        stub_full_request(project_hook.url, method: :post).to_raise(exception)

        expect(service_instance.execute).to have_attributes(status: :error, message: exception.to_s)
        expect { service_instance.execute }.not_to raise_error
      end
    end

    context 'when url is not encoded' do
      let_it_be(:project_hook) { create(:project_hook, url: 'http://server.com/my path/') }

      it 'handles exceptions' do
        expect(service_instance.execute).to have_attributes(
          status: :error,
          message: 'bad URI(is not URI?): "http://server.com/my path/"'
        )
        expect { service_instance.execute }.not_to raise_error
      end
    end

    context 'when request body size is too big' do
      it 'does not perform the request' do
        stub_const("#{described_class}::REQUEST_BODY_SIZE_LIMIT", 10.bytes)

        expect(service_instance.execute).to have_attributes(
          status: :error,
          message: 'Gitlab::Json::LimitedEncoder::LimitExceeded'
        )
      end
    end

    it 'handles 200 status code' do
      stub_full_request(project_hook.url, method: :post).to_return(status: 200, body: 'Success')

      expect(service_instance.execute).to have_attributes(
        status: :success,
        payload: { http_status: 200 },
        message: 'Success'
      )
    end

    it 'handles 2xx status codes' do
      stub_full_request(project_hook.url, method: :post).to_return(status: 201, body: 'Success')

      expect(service_instance.execute).to have_attributes(
        status: :success,
        payload: { http_status: 201 },
        message: 'Success'
      )
    end

    context 'execution logging' do
      let(:default_log_data) do
        {
          trigger: 'push_hooks',
          url: project_hook.url,
          interpolated_url: project_hook.interpolated_url,
          request_headers: headers,
          request_data: data,
          response_body: 'Success',
          response_headers: {},
          response_status: 200,
          execution_duration: be > 0,
          internal_error_message: nil
        }
      end

      context 'with success' do
        before do
          stub_full_request(project_hook.url, method: :post).to_return(status: 200, body: 'Success')
        end

        context 'when forced' do
          let(:service_instance) { described_class.new(project_hook, data, :push_hooks, force: true) }

          it 'logs execution inline' do
            expect(::WebHooks::LogExecutionWorker).not_to receive(:perform_async)
            expect(::WebHooks::LogExecutionService)
              .to receive(:new)
              .with(hook: project_hook, log_data: default_log_data, response_category: :ok)
              .and_return(double(execute: nil))

            service_instance.execute
          end
        end

        it 'queues LogExecutionWorker correctly' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data),
              :ok,
              nil
            )

          service_instance.execute
        end

        it 'queues LogExecutionWorker correctly, resulting in a log record (integration-style test)', :sidekiq_inline do
          expect { service_instance.execute }.to change(::WebHookLog, :count).by(1)
        end

        it 'does not log in the service itself' do
          expect { service_instance.execute }.not_to change(::WebHookLog, :count)
        end
      end

      context 'with bad request' do
        before do
          stub_full_request(project_hook.url, method: :post).to_return(status: 400, body: 'Bad request')
        end

        it 'queues LogExecutionWorker correctly' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(
                default_log_data.merge(
                  response_body: 'Bad request',
                  response_status: 400
                )
              ),
              :failed,
              nil
            )

          service_instance.execute
        end
      end

      context 'with exception' do
        before do
          stub_full_request(project_hook.url, method: :post).to_raise(SocketError.new('Some HTTP Post error'))
        end

        it 'queues LogExecutionWorker correctly' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(
                default_log_data.merge(
                  response_body: '',
                  response_status: 'internal error',
                  internal_error_message: 'Some HTTP Post error'
                )
              ),
              :error,
              nil
            )

          service_instance.execute
        end
      end

      context 'with unsafe response body' do
        before do
          stub_full_request(project_hook.url, method: :post).to_return(status: 200, body: "\xBB")
        end

        it 'queues LogExecutionWorker with sanitized response_body' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data.merge(response_body: '')),
              :ok,
              nil
            )

          service_instance.execute
        end
      end

      context 'with oversize response body' do
        let(:oversize_body) { 'a' * (described_class::RESPONSE_BODY_SIZE_LIMIT + 1) }
        let(:stripped_body) { 'a' * (described_class::RESPONSE_BODY_SIZE_LIMIT - ellipsis.bytesize) + ellipsis }

        before do
          stub_full_request(project_hook.url, method: :post).to_return(status: 200, body: oversize_body)
        end

        it 'queues LogExecutionWorker with stripped response_body' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data.merge(response_body: stripped_body)),
              :ok,
              nil
            )

          service_instance.execute
        end
      end

      context 'with massive amount of headers' do
        let(:response_headers) do
          (1..described_class::RESPONSE_HEADERS_COUNT_LIMIT + 1).to_a.to_h do |num|
            ["header-#{num}", SecureRandom.hex(num)]
          end
        end

        let(:expected_response_headers) do
          (1..described_class::RESPONSE_HEADERS_COUNT_LIMIT).to_a.to_h do |num|
            # Capitalized
            ["Header-#{num}", response_headers["header-#{num}"]]
          end
        end

        before do
          stub_full_request(project_hook.url, method: :post).to_return(
            status: 200, body: 'Success', headers: response_headers
          )
        end

        it 'queues LogExecutionWorker with limited amount of headers' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data.merge(response_headers: expected_response_headers)),
              :ok,
              nil
            )

          service_instance.execute
        end
      end

      context 'with oversize header' do
        let(:oversize_header) { 'a' * (described_class::RESPONSE_HEADERS_SIZE_LIMIT + 1) }
        let(:stripped_header) { 'a' * (described_class::RESPONSE_HEADERS_SIZE_LIMIT - ellipsis.bytesize) + ellipsis }
        let(:response_headers) { { 'oversized-header' => oversize_header } }
        let(:expected_response_headers) { { 'Oversized-Header' => stripped_header } }

        before do
          stub_full_request(project_hook.url, method: :post).to_return(
            status: 200, body: 'Success', headers: response_headers
          )
        end

        it 'queues LogExecutionWorker with stripped header value' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data.merge(response_headers: expected_response_headers)),
              :ok,
              nil
            )

          service_instance.execute
        end
      end

      context 'with log data exceeding Sidekiq limit' do
        before do
          stub_full_request(project_hook.url, method: :post).to_return(status: 200, body: 'Success')
        end

        it 'queues LogExecutionWorker with request_data overrided in the second attempt' do
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data),
              :ok,
              nil
            )
            .and_raise(
              Gitlab::SidekiqMiddleware::SizeLimiter::ExceedLimitError.new(WebHooks::LogExecutionWorker, 100, 50)
            )
            .ordered
          expect(WebHooks::LogExecutionWorker).to receive(:perform_async)
            .with(
              project_hook.id,
              hash_including(default_log_data.merge(request_data: WebHookLog::OVERSIZE_REQUEST_DATA)),
              :ok,
              nil
            )
            .and_call_original
            .ordered

          service_instance.execute
        end

        context 'new log data still exceeds limit' do
          before do
            allow(WebHooks::LogExecutionWorker).to receive(:perform_async).and_raise(
              Gitlab::SidekiqMiddleware::SizeLimiter::ExceedLimitError.new(WebHooks::LogExecutionWorker, 100, 50)
            )
          end

          it 'raises an exception' do
            expect do
              service_instance.execute
            end.to raise_error(Gitlab::SidekiqMiddleware::SizeLimiter::ExceedLimitError)
          end
        end
      end
    end
  end

  describe '#async_execute' do
    def expect_to_perform_worker(hook)
      expect(WebHookWorker).to receive(:perform_async).with(hook.id, data, 'push_hooks', an_instance_of(Hash))
    end

    def expect_to_rate_limit(hook, threshold:, throttled: false)
      expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(:web_hook_calls, scope: [hook.parent.root_namespace], threshold: threshold)
        .and_return(throttled)
    end

    context 'when rate limiting is not configured' do
      it 'queues a worker without tracking the call' do
        expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?)
        expect_to_perform_worker(project_hook)

        service_instance.async_execute
      end
    end

    context 'when rate limiting is configured' do
      let_it_be(:threshold) { 3 }
      let_it_be(:plan_limits) { create(:plan_limits, :default_plan, web_hook_calls: threshold) }

      it 'queues a worker and tracks the call' do
        expect_to_rate_limit(project_hook, threshold: threshold)
        expect_to_perform_worker(project_hook)

        service_instance.async_execute
      end

      context 'when the hook is throttled (via mock)' do
        before do
          expect_to_rate_limit(project_hook, threshold: threshold, throttled: true)
        end

        it 'does not queue a worker and logs an error' do
          expect(WebHookWorker).not_to receive(:perform_async)

          expect(Gitlab::AuthLogger).to receive(:error).with(
            include(
              message: 'Webhook rate limit exceeded',
              hook_id: project_hook.id,
              hook_type: 'ProjectHook',
              hook_name: 'push_hooks',
              "correlation_id" => kind_of(String),
              "meta.project" => project.full_path,
              "meta.related_class" => 'ProjectHook',
              "meta.root_namespace" => project.root_namespace.full_path
            )
          )

          service_instance.async_execute
        end
      end

      context 'when the hook is throttled (via Redis)', :clean_gitlab_redis_rate_limiting, :freeze_time do
        before do
          expect_to_perform_worker(project_hook).exactly(threshold).times

          threshold.times { service_instance.async_execute }
        end

        it 'stops queueing workers and logs errors' do
          expect(Gitlab::AuthLogger).to receive(:error).twice

          2.times { service_instance.async_execute }
        end

        it 'still queues workers for other hooks' do
          other_hook = create(:project_hook)

          expect_to_perform_worker(other_hook)

          described_class.new(other_hook, data, :push_hooks).async_execute
        end
      end
    end

    context 'recursion detection' do
      before do
        # Set a request UUID so `RecursionDetection.block?` will query redis.
        Gitlab::WebHooks::RecursionDetection.set_request_uuid(SecureRandom.uuid)
      end

      it 'does not queue a worker and logs an error if the call chain limit would be exceeded' do
        stub_const("#{Gitlab::WebHooks::RecursionDetection.name}::COUNT_LIMIT", 3)
        previous_hooks = create_list(:project_hook, 3)
        previous_hooks.each { Gitlab::WebHooks::RecursionDetection.register!(_1) }

        expect(WebHookWorker).not_to receive(:perform_async)
        expect(Gitlab::AuthLogger).to receive(:error).with(
          include(
            message: 'Recursive webhook blocked from executing',
            hook_id: project_hook.id,
            hook_type: 'ProjectHook',
            hook_name: 'push_hooks',
            recursion_detection: Gitlab::WebHooks::RecursionDetection.to_log(project_hook),
            'correlation_id' => kind_of(String),
            'meta.project' => project.full_path,
            'meta.related_class' => 'ProjectHook',
            'meta.root_namespace' => project.root_namespace.full_path
          )
        )

        service_instance.async_execute
      end

      it 'does not queue a worker and logs an error if a recursive call chain is detected' do
        Gitlab::WebHooks::RecursionDetection.register!(project_hook)

        expect(WebHookWorker).not_to receive(:perform_async)
        expect(Gitlab::AuthLogger).to receive(:error).with(
          include(
            message: 'Recursive webhook blocked from executing',
            hook_id: project_hook.id,
            hook_type: 'ProjectHook',
            hook_name: 'push_hooks',
            recursion_detection: Gitlab::WebHooks::RecursionDetection.to_log(project_hook),
            'correlation_id' => kind_of(String),
            'meta.project' => project.full_path,
            'meta.related_class' => 'ProjectHook',
            'meta.root_namespace' => project.root_namespace.full_path
          )
        )

        service_instance.async_execute
      end
    end

    context 'when hook has custom context attributes' do
      it 'includes the attributes in the worker context' do
        expect(WebHookWorker).to receive(:perform_async) do
          expect(Gitlab::ApplicationContext.current).to include(
            'meta.project' => project_hook.project.full_path,
            'meta.root_namespace' => project.root_ancestor.path,
            'meta.related_class' => 'ProjectHook'
          )
        end

        service_instance.async_execute
      end
    end
  end
end

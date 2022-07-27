# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::API do
  include GroupAPIHelpers

  describe 'Record user last activity in after hook' do
    # It does not matter which endpoint is used because last_activity_on should
    # be updated on every request. `/groups` is used as an example
    # to represent any API endpoint
    let(:user) { create(:user, last_activity_on: Date.yesterday) }

    it 'updates the users last_activity_on to the current date' do
      expect { get api('/groups', user) }.to change { user.reload.last_activity_on }.to(Date.today)
    end
  end

  describe 'User with only read_api scope personal access token' do
    # It does not matter which endpoint is used because this should behave
    # in the same way for every request. `/groups` is used as an example
    # to represent any API endpoint

    context 'when personal access token has only read_api scope' do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:token) { create(:personal_access_token, user: user, scopes: [:read_api]) }

      before_all do
        group.add_owner(user)
      end

      it 'does authorize user for get request' do
        get api('/groups', personal_access_token: token)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does authorize user for head request' do
        head api('/groups', personal_access_token: token)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not authorize user for revoked token' do
        revoked = create(:personal_access_token, :revoked, user: user, scopes: [:read_api])

        get api('/groups', personal_access_token: revoked)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'does not authorize user for post request' do
        params = attributes_for_group_api

        post api("/groups", personal_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'does not authorize user for put request' do
        group_param = { name: 'Test' }

        put api("/groups/#{group.id}", personal_access_token: token), params: group_param

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'does not authorize user for delete request' do
        delete api("/groups/#{group.id}", personal_access_token: token)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'authentication with deploy token' do
    context 'admin mode' do
      let_it_be(:project) { create(:project, :public) }
      let_it_be(:package) { create(:maven_package, project: project, name: project.full_path) }
      let_it_be(:maven_metadatum) { package.maven_metadatum }
      let_it_be(:package_file) { package.package_files.first }
      let_it_be(:deploy_token) { create(:deploy_token) }

      let(:headers_with_deploy_token) do
        {
          Gitlab::Auth::AuthFinders::DEPLOY_TOKEN_HEADER => deploy_token.token
        }
      end

      it 'does not bypass the session' do
        expect(Gitlab::Auth::CurrentUserMode).not_to receive(:bypass_session!)

        get(api("/packages/maven/#{maven_metadatum.path}/#{package_file.file_name}"),
            headers: headers_with_deploy_token)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq('application/octet-stream')
      end
    end
  end

  describe 'logging', :aggregate_failures do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:user) { project.first_owner }

    context 'when the endpoint is handled by the application' do
      context 'when the endpoint supports all possible fields' do
        it 'logs all application context fields and the route' do
          expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
            expect(data.stringify_keys)
              .to include('correlation_id' => an_instance_of(String),
                          'meta.caller_id' => 'GET /api/:version/projects/:id/issues',
                          'meta.remote_ip' => an_instance_of(String),
                          'meta.project' => project.full_path,
                          'meta.root_namespace' => project.namespace.full_path,
                          'meta.user' => user.username,
                          'meta.client_id' => a_string_matching(%r{\Auser/.+}),
                          'meta.feature_category' => 'team_planning',
                          'route' => '/api/:version/projects/:id/issues')
          end

          get(api("/projects/#{project.id}/issues", user))

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      it 'skips context fields that do not apply' do
        expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
          expect(data.stringify_keys)
            .to include('correlation_id' => an_instance_of(String),
                        'meta.caller_id' => 'GET /api/:version/broadcast_messages',
                        'meta.remote_ip' => an_instance_of(String),
                        'meta.client_id' => a_string_matching(%r{\Aip/.+}),
                        'meta.feature_category' => 'onboarding',
                        'route' => '/api/:version/broadcast_messages')

          expect(data.stringify_keys).not_to include('meta.project', 'meta.root_namespace', 'meta.user')
        end

        get(api('/broadcast_messages'))

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when there is an unsupported media type' do
      it 'logs the route and context metadata for the client' do
        expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
          expect(data.stringify_keys)
            .to include('correlation_id' => an_instance_of(String),
                        'meta.remote_ip' => an_instance_of(String),
                        'meta.client_id' => a_string_matching(%r{\Aip/.+}),
                        'route' => '/api/:version/users/:id')

          expect(data.stringify_keys).not_to include('meta.caller_id', 'meta.feature_category', 'meta.user')
        end

        put(api("/users/#{user.id}", user), params: { 'name' => 'Test' }, headers: { 'Content-Type' => 'image/png' })

        expect(response).to have_gitlab_http_status(:unsupported_media_type)
      end
    end

    context 'when there is an OPTIONS request' do
      it 'logs the route and context metadata for the client' do
        expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
          expect(data.stringify_keys)
            .to include('correlation_id' => an_instance_of(String),
                        'meta.remote_ip' => an_instance_of(String),
                        'meta.client_id' => a_string_matching(%r{\Auser/.+}),
                        'meta.user' => user.username,
                        'meta.feature_category' => 'users',
                        'route' => '/api/:version/users')

          expect(data.stringify_keys).not_to include('meta.caller_id')
        end

        options(api('/users', user))

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'when the API version is not matched' do
      it 'logs the route and context metadata for the client' do
        expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
          expect(data.stringify_keys)
            .to include('correlation_id' => an_instance_of(String),
                        'meta.remote_ip' => an_instance_of(String),
                        'meta.client_id' => a_string_matching(%r{\Aip/.+}),
                        'route' => '/api/:version/*path')

          expect(data.stringify_keys).not_to include('meta.caller_id', 'meta.user')
        end

        get('/api/v4_or_is_it')

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when there is an unhandled exception for an anonymous request' do
      it 'logs all application context fields and the route' do
        expect(described_class::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
          expect(data.stringify_keys)
            .to include('correlation_id' => an_instance_of(String),
                        'meta.caller_id' => 'GET /api/:version/broadcast_messages',
                        'meta.remote_ip' => an_instance_of(String),
                        'meta.client_id' => a_string_matching(%r{\Aip/.+}),
                        'meta.feature_category' => 'onboarding',
                        'route' => '/api/:version/broadcast_messages')

          expect(data.stringify_keys).not_to include('meta.project', 'meta.root_namespace', 'meta.user')
        end

        expect(BroadcastMessage).to receive(:all).and_raise('An error!')

        get(api('/broadcast_messages'))

        expect(response).to have_gitlab_http_status(:internal_server_error)
      end
    end
  end

  describe 'Marginalia comments' do
    context 'GET /user/:id' do
      let_it_be(:user) { create(:user) }

      let(:component_map) do
        {
          "application" => "test",
          "endpoint_id" => "GET /api/:version/users/:id"
        }
      end

      subject { ActiveRecord::QueryRecorder.new { get api("/users/#{user.id}", user) } }

      it 'generates a query that includes the expected annotations' do
        expect(subject.log.last).to match(/correlation_id:.*/)

        component_map.each do |component, value|
          expect(subject.log.last).to include("#{component}:#{value}")
        end
      end
    end
  end

  describe 'supported content-types' do
    context 'GET /user/:id.txt' do
      let_it_be(:user) { create(:user) }

      subject { get api("/users/#{user.id}.txt", user) }

      it 'returns application/json' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq('application/json')
        expect(response.body).to include('{"id":')
      end
    end
  end
end

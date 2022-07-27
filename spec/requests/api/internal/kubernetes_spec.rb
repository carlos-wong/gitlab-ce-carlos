# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Kubernetes do
  let(:jwt_auth_headers) do
    jwt_token = JWT.encode({ 'iss' => Gitlab::Kas::JWT_ISSUER }, Gitlab::Kas.secret, 'HS256')

    { Gitlab::Kas::INTERNAL_API_REQUEST_HEADER => jwt_token }
  end

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }

  before do
    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)
  end

  shared_examples 'authorization' do
    context 'not authenticated' do
      it 'returns 401' do
        send_request(headers: { Gitlab::Kas::INTERNAL_API_REQUEST_HEADER => '' })

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'kubernetes_agent_internal_api feature flag disabled' do
      before do
        stub_feature_flags(kubernetes_agent_internal_api: false)
      end

      it 'returns 404' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'agent authentication' do
    it 'returns 401 if Authorization header not sent' do
      send_request

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it 'returns 401 if Authorization is for non-existent agent' do
      send_request(headers: { 'Authorization' => 'Bearer NONEXISTENT' })

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  shared_examples 'agent token tracking' do
    it 'tracks token usage' do
      expect do
        send_request(headers: { 'Authorization' => "Bearer #{agent_token.token}" })
      end.to change { agent_token.reload.read_attribute(:last_used_at) }
    end
  end

  describe 'POST /internal/kubernetes/usage_metrics' do
    def send_request(headers: {}, params: {})
      post api('/internal/kubernetes/usage_metrics'), params: params, headers: headers.reverse_merge(jwt_auth_headers)
    end

    include_examples 'authorization'

    context 'is authenticated for an agent' do
      let!(:agent_token) { create(:cluster_agent_token) }

      it 'returns no_content for valid events' do
        send_request(params: { gitops_sync_count: 10, k8s_api_proxy_request_count: 5 })

        expect(response).to have_gitlab_http_status(:no_content)
      end

      it 'returns no_content for counts of zero' do
        send_request(params: { gitops_sync_count: 0, k8s_api_proxy_request_count: 0 })

        expect(response).to have_gitlab_http_status(:no_content)
      end

      it 'returns 400 for non number' do
        send_request(params: { gitops_sync_count: 'string', k8s_api_proxy_request_count: 1 })

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 for negative number' do
        send_request(params: { gitops_sync_count: -1, k8s_api_proxy_request_count: 1 })

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'POST /internal/kubernetes/agent_configuration' do
    def send_request(headers: {}, params: {})
      post api('/internal/kubernetes/agent_configuration'), params: params, headers: headers.reverse_merge(jwt_auth_headers)
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:agent) { create(:cluster_agent, project: project) }
    let_it_be(:config) do
      {
        ci_access: {
          groups: [
            { id: group.full_path, default_namespace: 'production' }
          ],
          projects: [
            { id: project.full_path, default_namespace: 'staging' }
          ]
        }
      }
    end

    include_examples 'authorization'

    context 'agent exists' do
      it 'configures the agent and returns a 204' do
        send_request(params: { agent_id: agent.id, agent_config: config })

        expect(response).to have_gitlab_http_status(:no_content)
        expect(agent.authorized_groups).to contain_exactly(group)
        expect(agent.authorized_projects).to contain_exactly(project)
      end
    end

    context 'agent does not exist' do
      it 'returns a 404' do
        send_request(params: { agent_id: -1, agent_config: config })

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /internal/kubernetes/agent_info' do
    def send_request(headers: {}, params: {})
      get api('/internal/kubernetes/agent_info'), params: params, headers: headers.reverse_merge(jwt_auth_headers)
    end

    include_examples 'authorization'
    include_examples 'agent authentication'

    context 'an agent is found' do
      let!(:agent_token) { create(:cluster_agent_token) }

      let(:agent) { agent_token.agent }
      let(:project) { agent.project }

      include_examples 'agent token tracking'

      it 'returns expected data', :aggregate_failures do
        send_request(headers: { 'Authorization' => "Bearer #{agent_token.token}" })

        expect(response).to have_gitlab_http_status(:success)

        expect(json_response).to match(
          a_hash_including(
            'project_id' => project.id,
            'agent_id' => agent.id,
            'agent_name' => agent.name,
            'gitaly_info' => a_hash_including(
              'address' => match(/\.socket$/),
              'token' => 'secret',
              'features' => {}
            ),
            'gitaly_repository' => a_hash_including(
              'storage_name' => project.repository_storage,
              'relative_path' => project.disk_path + '.git',
              'gl_repository' => "project-#{project.id}",
              'gl_project_path' => project.full_path
            ),
            'default_branch' => project.default_branch_or_main
          )
        )
      end
    end
  end
end

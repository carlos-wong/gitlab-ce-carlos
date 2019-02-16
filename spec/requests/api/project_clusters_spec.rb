# frozen_string_literal: true

require 'spec_helper'

describe API::ProjectClusters do
  include KubernetesHelpers

  let(:current_user) { create(:user) }
  let(:non_member) { create(:user) }
  let(:project) { create(:project, :repository) }

  before do
    project.add_maintainer(current_user)
  end

  describe 'GET /projects/:id/clusters' do
    let!(:extra_cluster) { create(:cluster, :provided_by_gcp, :project) }

    let!(:clusters) do
      create_list(:cluster, 5, :provided_by_gcp, :project, :production_environment,
                  projects: [project])
    end

    context 'non-authorized user' do
      it 'should respond with 404' do
        get api("/projects/#{project.id}/clusters", non_member)

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'authorized user' do
      before do
        get api("/projects/#{project.id}/clusters", current_user)
      end

      it 'should respond with 200' do
        expect(response).to have_gitlab_http_status(200)
      end

      it 'should include pagination headers' do
        expect(response).to include_pagination_headers
      end

      it 'should only include authorized clusters' do
        cluster_ids = json_response.map { |cluster| cluster['id'] }

        expect(cluster_ids).to match_array(clusters.pluck(:id))
        expect(cluster_ids).not_to include(extra_cluster.id)
      end
    end
  end

  describe 'GET /projects/:id/clusters/:cluster_id' do
    let(:cluster_id) { cluster.id }

    let(:platform_kubernetes) do
      create(:cluster_platform_kubernetes, :configured,
             namespace: 'project-namespace')
    end

    let(:cluster) do
      create(:cluster, :project, :provided_by_gcp,
             platform_kubernetes: platform_kubernetes,
             user: current_user,
             projects: [project])
    end

    context 'non-authorized user' do
      it 'should respond with 404' do
        get api("/projects/#{project.id}/clusters/#{cluster_id}", non_member)

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'authorized user' do
      before do
        get api("/projects/#{project.id}/clusters/#{cluster_id}", current_user)
      end

      it 'returns specific cluster' do
        expect(json_response['id']).to eq(cluster.id)
      end

      it 'returns cluster information' do
        expect(json_response['provider_type']).to eq('gcp')
        expect(json_response['platform_type']).to eq('kubernetes')
        expect(json_response['environment_scope']).to eq('*')
        expect(json_response['cluster_type']).to eq('project_type')
      end

      it 'returns project information' do
        cluster_project = json_response['project']

        expect(cluster_project['id']).to eq(project.id)
        expect(cluster_project['name']).to eq(project.name)
        expect(cluster_project['path']).to eq(project.path)
      end

      it 'returns kubernetes platform information' do
        platform = json_response['platform_kubernetes']

        expect(platform['api_url']).to eq('https://kubernetes.example.com')
        expect(platform['namespace']).to eq('project-namespace')
        expect(platform['ca_cert']).to be_present
      end

      it 'returns user information' do
        user = json_response['user']

        expect(user['id']).to eq(current_user.id)
        expect(user['username']).to eq(current_user.username)
      end

      it 'returns GCP provider information' do
        gcp_provider = json_response['provider_gcp']

        expect(gcp_provider['cluster_id']).to eq(cluster.id)
        expect(gcp_provider['status_name']).to eq('created')
        expect(gcp_provider['gcp_project_id']).to eq('test-gcp-project')
        expect(gcp_provider['zone']).to eq('us-central1-a')
        expect(gcp_provider['machine_type']).to eq('n1-standard-2')
        expect(gcp_provider['num_nodes']).to eq(3)
        expect(gcp_provider['endpoint']).to eq('111.111.111.111')
      end

      context 'when cluster has no provider' do
        let(:cluster) do
          create(:cluster, :project, :provided_by_user,
                 projects: [project])
        end

        it 'should not include GCP provider info' do
          expect(json_response['provider_gcp']).not_to be_present
        end
      end

      context 'with non-existing cluster' do
        let(:cluster_id) { 123 }

        it 'returns 404' do
          expect(response).to have_gitlab_http_status(404)
        end
      end
    end
  end

  shared_context 'kubernetes calls stubbed' do
    before do
      stub_kubeclient_discover(api_url)
      stub_kubeclient_get_namespace(api_url, namespace: namespace)
      stub_kubeclient_get_service_account(api_url, "#{namespace}-service-account", namespace: namespace)
      stub_kubeclient_put_service_account(api_url, "#{namespace}-service-account", namespace: namespace)

      stub_kubeclient_get_secret(
        api_url,
        {
          metadata_name: "#{namespace}-token",
          token: Base64.encode64('sample-token'),
          namespace: namespace
        }
      )

      stub_kubeclient_put_secret(api_url, "#{namespace}-token", namespace: namespace)
      stub_kubeclient_get_role_binding(api_url, "gitlab-#{namespace}", namespace: namespace)
      stub_kubeclient_put_role_binding(api_url, "gitlab-#{namespace}", namespace: namespace)
    end
  end

  describe 'POST /projects/:id/clusters/user' do
    include_context 'kubernetes calls stubbed'

    let(:api_url) { 'https://kubernetes.example.com' }
    let(:namespace) { project.path }
    let(:authorization_type) { 'rbac' }

    let(:platform_kubernetes_attributes) do
      {
        api_url: api_url,
        token: 'sample-token',
        namespace: namespace,
        authorization_type: authorization_type
      }
    end

    let(:cluster_params) do
      {
        name: 'test-cluster',
        platform_kubernetes_attributes: platform_kubernetes_attributes
      }
    end

    context 'non-authorized user' do
      it 'should respond with 404' do
        post api("/projects/#{project.id}/clusters/user", non_member), params: cluster_params

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'authorized user' do
      before do
        post api("/projects/#{project.id}/clusters/user", current_user), params: cluster_params
      end

      context 'with valid params' do
        it 'should respond with 201' do
          expect(response).to have_gitlab_http_status(201)
        end

        it 'should create a new Cluster::Cluster' do
          cluster_result = Clusters::Cluster.find(json_response["id"])
          platform_kubernetes = cluster_result.platform

          expect(cluster_result).to be_user
          expect(cluster_result).to be_kubernetes
          expect(cluster_result.project).to eq(project)
          expect(cluster_result.name).to eq('test-cluster')
          expect(platform_kubernetes.rbac?).to be_truthy
          expect(platform_kubernetes.api_url).to eq(api_url)
          expect(platform_kubernetes.namespace).to eq(namespace)
          expect(platform_kubernetes.token).to eq('sample-token')
        end
      end

      context 'when user does not indicate authorization type' do
        let(:platform_kubernetes_attributes) do
          {
            api_url: api_url,
            token: 'sample-token',
            namespace: namespace
          }
        end

        it 'defaults to RBAC' do
          cluster_result = Clusters::Cluster.find(json_response['id'])

          expect(cluster_result.platform_kubernetes.rbac?).to be_truthy
        end
      end

      context 'when user sets authorization type as ABAC' do
        let(:authorization_type) { 'abac' }

        it 'should create an ABAC cluster' do
          cluster_result = Clusters::Cluster.find(json_response['id'])

          expect(cluster_result.platform.abac?).to be_truthy
        end
      end

      context 'with invalid params' do
        let(:namespace) { 'invalid_namespace' }

        it 'should respond with 400' do
          expect(response).to have_gitlab_http_status(400)
        end

        it 'should not create a new Clusters::Cluster' do
          expect(project.reload.clusters).to be_empty
        end

        it 'should return validation errors' do
          expect(json_response['message']['platform_kubernetes.namespace'].first).to be_present
        end
      end
    end

    context 'when user tries to add multiple clusters' do
      before do
        create(:cluster, :provided_by_gcp, :project,
               projects: [project])

        post api("/projects/#{project.id}/clusters/user", current_user), params: cluster_params
      end

      it 'should respond with 403' do
        expect(response).to have_gitlab_http_status(403)
      end

      it 'should return an appropriate message' do
        expect(json_response['message']).to include('Instance does not support multiple Kubernetes clusters')
      end
    end
  end

  describe 'PUT /projects/:id/clusters/:cluster_id' do
    include_context 'kubernetes calls stubbed'

    let(:api_url) { 'https://kubernetes.example.com' }
    let(:namespace) { 'new-namespace' }
    let(:platform_kubernetes_attributes) { { namespace: namespace } }

    let(:update_params) do
      {
        platform_kubernetes_attributes: platform_kubernetes_attributes
      }
    end

    let!(:kubernetes_namespace) do
      create(:cluster_kubernetes_namespace,
             cluster: cluster,
             project: project)
    end

    let(:cluster) do
      create(:cluster, :project, :provided_by_gcp,
             projects: [project])
    end

    context 'non-authorized user' do
      it 'should respond with 404' do
        put api("/projects/#{project.id}/clusters/#{cluster.id}", non_member), params: update_params

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'authorized user' do
      before do
        put api("/projects/#{project.id}/clusters/#{cluster.id}", current_user), params: update_params

        cluster.reload
      end

      context 'with valid params' do
        it 'should respond with 200' do
          expect(response).to have_gitlab_http_status(200)
        end

        it 'should update cluster attributes' do
          expect(cluster.platform_kubernetes.namespace).to eq('new-namespace')
          expect(cluster.kubernetes_namespace.namespace).to eq('new-namespace')
        end
      end

      context 'with invalid params' do
        let(:namespace) { 'invalid_namespace' }

        it 'should respond with 400' do
          expect(response).to have_gitlab_http_status(400)
        end

        it 'should not update cluster attributes' do
          expect(cluster.platform_kubernetes.namespace).not_to eq('invalid_namespace')
          expect(cluster.kubernetes_namespace.namespace).not_to eq('invalid_namespace')
        end

        it 'should return validation errors' do
          expect(json_response['message']['platform_kubernetes.namespace'].first).to match('can contain only lowercase letters')
        end
      end

      context 'with a GCP cluster' do
        context 'when user tries to change GCP specific fields' do
          let(:platform_kubernetes_attributes) do
            {
              api_url: 'https://new-api-url.com',
              token: 'new-sample-token'
            }
          end

          it 'should respond with 400' do
            expect(response).to have_gitlab_http_status(400)
          end

          it 'should return validation error' do
            expect(json_response['message']['platform_kubernetes.base'].first).to eq('Cannot modify managed Kubernetes cluster')
          end
        end

        context 'when user tries to change namespace' do
          let(:namespace) { 'new-namespace' }

          it 'should respond with 200' do
            expect(response).to have_gitlab_http_status(200)
          end
        end
      end

      context 'with an user cluster' do
        let(:api_url) { 'https://new-api-url.com' }

        let(:cluster) do
          create(:cluster, :project, :provided_by_user,
                 projects: [project])
        end

        let(:platform_kubernetes_attributes) do
          {
            api_url: api_url,
            namespace: 'new-namespace',
            token: 'new-sample-token'
          }
        end

        let(:update_params) do
          {
            name: 'new-name',
            platform_kubernetes_attributes: platform_kubernetes_attributes
          }
        end

        it 'should respond with 200' do
          expect(response).to have_gitlab_http_status(200)
        end

        it 'should update platform kubernetes attributes' do
          platform_kubernetes = cluster.platform_kubernetes

          expect(cluster.name).to eq('new-name')
          expect(platform_kubernetes.namespace).to eq('new-namespace')
          expect(platform_kubernetes.api_url).to eq('https://new-api-url.com')
          expect(platform_kubernetes.token).to eq('new-sample-token')
        end
      end

      context 'with a cluster that does not belong to user' do
        let(:cluster) { create(:cluster, :project, :provided_by_user) }

        it 'should respond with 404' do
          expect(response).to have_gitlab_http_status(404)
        end
      end
    end
  end

  describe 'DELETE /projects/:id/clusters/:cluster_id' do
    let(:cluster_params) { { cluster_id: cluster.id } }

    let(:cluster) do
      create(:cluster, :project, :provided_by_gcp,
             projects: [project])
    end

    context 'non-authorized user' do
      it 'should respond with 404' do
        delete api("/projects/#{project.id}/clusters/#{cluster.id}", non_member), params: cluster_params

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'authorized user' do
      before do
        delete api("/projects/#{project.id}/clusters/#{cluster.id}", current_user), params: cluster_params
      end

      it 'should respond with 204' do
        expect(response).to have_gitlab_http_status(204)
      end

      it 'should delete the cluster' do
        expect(Clusters::Cluster.exists?(id: cluster.id)).to be_falsy
      end

      context 'with a cluster that does not belong to user' do
        let(:cluster) { create(:cluster, :project, :provided_by_user) }

        it 'should respond with 404' do
          expect(response).to have_gitlab_http_status(404)
        end
      end
    end
  end
end

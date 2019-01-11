# frozen_string_literal: true

require 'spec_helper'

describe Clusters::Gcp::Kubernetes::CreateOrUpdateNamespaceService, '#execute' do
  include KubernetesHelpers

  let(:cluster) { create(:cluster, :project, :provided_by_gcp) }
  let(:platform) { cluster.platform }
  let(:api_url) { 'https://kubernetes.example.com' }
  let(:project) { cluster.project }
  let(:cluster_project) { cluster.cluster_project }
  let(:namespace) { "#{project.path}-#{project.id}" }

  subject do
    described_class.new(
      cluster: cluster,
      kubernetes_namespace: kubernetes_namespace
    ).execute
  end

  before do
    stub_kubeclient_discover(api_url)
    stub_kubeclient_get_namespace(api_url)
    stub_kubeclient_get_service_account_error(api_url, 'gitlab')
    stub_kubeclient_create_service_account(api_url)
    stub_kubeclient_get_secret_error(api_url, 'gitlab-token')
    stub_kubeclient_create_secret(api_url)

    stub_kubeclient_get_role_binding(api_url, "gitlab-#{namespace}", namespace: namespace)
    stub_kubeclient_put_role_binding(api_url, "gitlab-#{namespace}", namespace: namespace)
    stub_kubeclient_get_namespace(api_url, namespace: namespace)
    stub_kubeclient_get_service_account_error(api_url, "#{namespace}-service-account", namespace: namespace)
    stub_kubeclient_create_service_account(api_url, namespace: namespace)
    stub_kubeclient_create_secret(api_url, namespace: namespace)
    stub_kubeclient_put_secret(api_url, "#{namespace}-token", namespace: namespace)

    stub_kubeclient_get_secret(
      api_url,
      {
        metadata_name: "#{namespace}-token",
        token: Base64.encode64('sample-token'),
        namespace: namespace
      }
    )
  end

  shared_examples 'successful creation of kubernetes namespace' do
    it 'creates a Clusters::KubernetesNamespace' do
      expect do
        subject
      end.to change(Clusters::KubernetesNamespace, :count).by(1)
    end

    it 'creates project service account' do
      expect_any_instance_of(Clusters::Gcp::Kubernetes::CreateOrUpdateServiceAccountService).to receive(:execute).once

      subject
    end

    it 'configures kubernetes token' do
      subject

      kubernetes_namespace.reload
      expect(kubernetes_namespace.namespace).to eq(namespace)
      expect(kubernetes_namespace.service_account_name).to eq("#{namespace}-service-account")
      expect(kubernetes_namespace.encrypted_service_account_token).to be_present
    end
  end

  context 'group clusters' do
    let(:cluster) { create(:cluster, :group, :provided_by_gcp) }
    let(:group) { cluster.group }
    let(:project) { create(:project, group: group) }

    context 'when kubernetes namespace is not persisted' do
      let(:kubernetes_namespace) do
        build(:cluster_kubernetes_namespace,
              cluster: cluster,
              project: project)
      end

      it_behaves_like 'successful creation of kubernetes namespace'
    end
  end

  context 'project clusters' do
    context 'when kubernetes namespace is not persisted' do
      let(:kubernetes_namespace) do
        build(:cluster_kubernetes_namespace,
              cluster: cluster,
              project: cluster_project.project,
              cluster_project: cluster_project)
      end

      it_behaves_like 'successful creation of kubernetes namespace'
    end

    context 'when there is a Kubernetes Namespace associated' do
      let(:namespace) { 'new-namespace' }

      let(:kubernetes_namespace) do
        create(:cluster_kubernetes_namespace,
               cluster: cluster,
               project: cluster_project.project,
               cluster_project: cluster_project)
      end

      before do
        platform.update_column(:namespace, 'new-namespace')
      end

      it 'does not create any Clusters::KubernetesNamespace' do
        subject

        expect(cluster.kubernetes_namespace).to eq(kubernetes_namespace)
      end

      it 'creates project service account' do
        expect_any_instance_of(Clusters::Gcp::Kubernetes::CreateOrUpdateServiceAccountService).to receive(:execute).once

        subject
      end

      it 'updates Clusters::KubernetesNamespace' do
        subject

        kubernetes_namespace.reload

        expect(kubernetes_namespace.namespace).to eq(namespace)
        expect(kubernetes_namespace.service_account_name).to eq("#{namespace}-service-account")
        expect(kubernetes_namespace.encrypted_service_account_token).to be_present
      end
    end
  end
end

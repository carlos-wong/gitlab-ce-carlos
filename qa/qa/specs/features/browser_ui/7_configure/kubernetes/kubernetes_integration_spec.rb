# frozen_string_literal: true

module QA
  context 'Configure' do
    describe 'Kubernetes Cluster Integration', :orchestrated, :kubernetes, :requires_admin do
      context 'Project Clusters' do
        let(:cluster) { Service::KubernetesCluster.new(provider_class: Service::ClusterProvider::K3s).create! }
        let(:project) do
          Resource::Project.fabricate_via_api! do |project|
            project.name = 'project-with-k8s'
            project.description = 'Project with Kubernetes cluster integration'
          end
        end

        before do
          Flow::Login.sign_in
        end

        after do
          cluster.remove!
        end

        it 'can create and associate a project cluster', :smoke, quarantine: { type: :new } do
          Resource::KubernetesCluster.fabricate_via_browser_ui! do |k8s_cluster|
            k8s_cluster.project = project
            k8s_cluster.cluster = cluster
          end

          project.visit!

          Page::Project::Menu.perform(&:go_to_operations_kubernetes)

          Page::Project::Operations::Kubernetes::Index.perform do |index|
            expect(index).to have_cluster(cluster)
          end
        end
      end
    end
  end
end

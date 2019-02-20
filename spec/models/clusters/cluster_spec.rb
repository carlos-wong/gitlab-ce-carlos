# frozen_string_literal: true

require 'spec_helper'

describe Clusters::Cluster do
  it_behaves_like 'having unique enum values'

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:cluster_projects) }
  it { is_expected.to have_many(:projects) }
  it { is_expected.to have_many(:cluster_groups) }
  it { is_expected.to have_many(:groups) }
  it { is_expected.to have_one(:provider_gcp) }
  it { is_expected.to have_one(:platform_kubernetes) }
  it { is_expected.to have_one(:application_helm) }
  it { is_expected.to have_one(:application_ingress) }
  it { is_expected.to have_one(:application_prometheus) }
  it { is_expected.to have_one(:application_runner) }
  it { is_expected.to have_many(:kubernetes_namespaces) }
  it { is_expected.to have_one(:kubernetes_namespace) }
  it { is_expected.to have_one(:cluster_project) }

  it { is_expected.to delegate_method(:status).to(:provider) }
  it { is_expected.to delegate_method(:status_reason).to(:provider) }
  it { is_expected.to delegate_method(:status_name).to(:provider) }
  it { is_expected.to delegate_method(:on_creation?).to(:provider) }
  it { is_expected.to delegate_method(:active?).to(:platform_kubernetes).with_prefix }
  it { is_expected.to delegate_method(:rbac?).to(:platform_kubernetes).with_prefix }
  it { is_expected.to delegate_method(:available?).to(:application_helm).with_prefix }
  it { is_expected.to delegate_method(:available?).to(:application_ingress).with_prefix }
  it { is_expected.to delegate_method(:available?).to(:application_prometheus).with_prefix }
  it { is_expected.to delegate_method(:available?).to(:application_knative).with_prefix }
  it { is_expected.to delegate_method(:external_ip).to(:application_ingress).with_prefix }

  it { is_expected.to respond_to :project }

  describe '.enabled' do
    subject { described_class.enabled }

    let!(:cluster) { create(:cluster, enabled: true) }

    before do
      create(:cluster, enabled: false)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '.disabled' do
    subject { described_class.disabled }

    let!(:cluster) { create(:cluster, enabled: false) }

    before do
      create(:cluster, enabled: true)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '.user_provided' do
    subject { described_class.user_provided }

    let!(:cluster) { create(:cluster, :provided_by_user) }

    before do
      create(:cluster, :provided_by_gcp)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '.gcp_provided' do
    subject { described_class.gcp_provided }

    let!(:cluster) { create(:cluster, :provided_by_gcp) }

    before do
      create(:cluster, :provided_by_user)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '.gcp_installed' do
    subject { described_class.gcp_installed }

    let!(:cluster) { create(:cluster, :provided_by_gcp) }

    before do
      create(:cluster, :providing_by_gcp)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '.missing_kubernetes_namespace' do
    let!(:cluster) { create(:cluster, :provided_by_gcp, :project) }
    let(:project) { cluster.project }
    let(:kubernetes_namespaces) { project.kubernetes_namespaces }

    subject do
      described_class.joins(:projects).where(projects: { id: project.id }).missing_kubernetes_namespace(kubernetes_namespaces)
    end

    it { is_expected.to contain_exactly(cluster) }

    context 'kubernetes namespace exists' do
      before do
        create(:cluster_kubernetes_namespace, project: project, cluster: cluster)
      end

      it { is_expected.to be_empty }
    end
  end

  describe 'validations' do
    subject { cluster.valid? }

    context 'when validates name' do
      context 'when provided by user' do
        let!(:cluster) { build(:cluster, :provided_by_user, name: name) }

        context 'when name is empty' do
          let(:name) { '' }

          it { is_expected.to be_falsey }
        end

        context 'when name is nil' do
          let(:name) { nil }

          it { is_expected.to be_falsey }
        end

        context 'when name is present' do
          let(:name) { 'cluster-name-1' }

          it { is_expected.to be_truthy }
        end
      end

      context 'when provided by gcp' do
        let!(:cluster) { build(:cluster, :provided_by_gcp, name: name) }

        context 'when name is shorter than 1' do
          let(:name) { '' }

          it { is_expected.to be_falsey }
        end

        context 'when name is longer than 63' do
          let(:name) { 'a' * 64 }

          it { is_expected.to be_falsey }
        end

        context 'when name includes invalid character' do
          let(:name) { '!!!!!!' }

          it { is_expected.to be_falsey }
        end

        context 'when name is present' do
          let(:name) { 'cluster-name-1' }

          it { is_expected.to be_truthy }
        end

        context 'when record is persisted' do
          let(:name) { 'cluster-name-1' }

          before do
            cluster.save!
          end

          context 'when name is changed' do
            before do
              cluster.name = 'new-cluster-name'
            end

            it { is_expected.to be_falsey }
          end

          context 'when name is same' do
            before do
              cluster.name = name
            end

            it { is_expected.to be_truthy }
          end
        end
      end
    end

    context 'when validates restrict_modification' do
      context 'when creation is on going' do
        let!(:cluster) { create(:cluster, :providing_by_gcp) }

        it { expect(cluster.update(enabled: false)).to be_falsey }
      end

      context 'when creation is done' do
        let!(:cluster) { create(:cluster, :provided_by_gcp) }

        it { expect(cluster.update(enabled: false)).to be_truthy }
      end
    end

    describe 'cluster_type validations' do
      let(:instance_cluster) { create(:cluster, :instance) }
      let(:group_cluster) { create(:cluster, :group) }
      let(:project_cluster) { create(:cluster, :project) }

      it 'validates presence' do
        cluster = build(:cluster, :project, cluster_type: nil)

        expect(cluster).not_to be_valid
        expect(cluster.errors.full_messages).to include("Cluster type can't be blank")
      end

      context 'project_type cluster' do
        it 'does not allow setting group' do
          project_cluster.groups << build(:group)

          expect(project_cluster).not_to be_valid
          expect(project_cluster.errors.full_messages).to include('Cluster cannot have groups assigned')
        end
      end

      context 'group_type cluster' do
        it 'does not allow setting project' do
          group_cluster.projects << build(:project)

          expect(group_cluster).not_to be_valid
          expect(group_cluster.errors.full_messages).to include('Cluster cannot have projects assigned')
        end
      end

      context 'instance_type cluster' do
        it 'does not allow setting group' do
          instance_cluster.groups << build(:group)

          expect(instance_cluster).not_to be_valid
          expect(instance_cluster.errors.full_messages).to include('Cluster cannot have groups assigned')
        end

        it 'does not allow setting project' do
          instance_cluster.projects << build(:project)

          expect(instance_cluster).not_to be_valid
          expect(instance_cluster.errors.full_messages).to include('Cluster cannot have projects assigned')
        end
      end
    end

    describe 'domain validation' do
      let(:cluster) { build(:cluster) }

      subject { cluster }

      context 'when cluster has domain' do
        let(:cluster) { build(:cluster, :with_domain) }

        it { is_expected.to be_valid }
      end

      context 'when cluster is not a valid hostname' do
        let(:cluster) { build(:cluster, domain: 'http://not.a.valid.hostname') }

        it 'should add an error on domain' do
          expect(subject).not_to be_valid
          expect(subject.errors[:domain].first).to eq('contains invalid characters (valid characters: [a-z0-9\\-])')
        end
      end

      context 'when cluster does not have a domain' do
        it { is_expected.to be_valid }
      end
    end
  end

  describe '.ancestor_clusters_for_clusterable' do
    let(:group_cluster) { create(:cluster, :provided_by_gcp, :group) }
    let(:group) { group_cluster.group }
    let(:hierarchy_order) { :desc }
    let(:clusterable) { project }

    subject do
      described_class.ancestor_clusters_for_clusterable(clusterable, hierarchy_order: hierarchy_order)
    end

    context 'when project does not belong to this group' do
      let(:project) { create(:project, group: create(:group)) }

      it 'returns nothing' do
        is_expected.to be_empty
      end
    end

    context 'when group has a configured kubernetes cluster' do
      let(:project) { create(:project, group: group) }

      it 'returns the group cluster' do
        is_expected.to eq([group_cluster])
      end
    end

    context 'when sub-group has configured kubernetes cluster', :nested_groups do
      let(:sub_group_cluster) { create(:cluster, :provided_by_gcp, :group) }
      let(:sub_group) { sub_group_cluster.group }
      let(:project) { create(:project, group: sub_group) }

      before do
        sub_group.update!(parent: group)
      end

      it 'returns clusters in order, descending the hierachy' do
        is_expected.to eq([group_cluster, sub_group_cluster])
      end

      it 'avoids N+1 queries' do
        another_project = create(:project)
        control_count = ActiveRecord::QueryRecorder.new do
          described_class.ancestor_clusters_for_clusterable(another_project, hierarchy_order: hierarchy_order)
        end.count

        cluster2 = create(:cluster, :provided_by_gcp, :group)
        child2 = cluster2.group
        child2.update!(parent: sub_group)
        project = create(:project, group: child2)

        expect do
          described_class.ancestor_clusters_for_clusterable(project, hierarchy_order: hierarchy_order)
        end.not_to exceed_query_limit(control_count)
      end

      context 'for a group' do
        let(:clusterable) { sub_group }

        it 'returns clusters in order for a group' do
          is_expected.to eq([group_cluster])
        end
      end
    end

    context 'scope chaining' do
      let(:project) { create(:project, group: group) }

      subject { described_class.none.ancestor_clusters_for_clusterable(project) }

      it 'returns nothing' do
        is_expected.to be_empty
      end
    end
  end

  describe '#provider' do
    subject { cluster.provider }

    context 'when provider is gcp' do
      let(:cluster) { create(:cluster, :provided_by_gcp) }

      it 'returns a provider' do
        is_expected.to eq(cluster.provider_gcp)
        expect(subject.class.name.deconstantize).to eq(Clusters::Providers.to_s)
      end
    end

    context 'when provider is user' do
      let(:cluster) { create(:cluster, :provided_by_user) }

      it { is_expected.to be_nil }
    end
  end

  describe '#platform' do
    subject { cluster.platform }

    context 'when platform is kubernetes' do
      let(:cluster) { create(:cluster, :provided_by_user) }

      it 'returns a platform' do
        is_expected.to eq(cluster.platform_kubernetes)
        expect(subject.class.name.deconstantize).to eq(Clusters::Platforms.to_s)
      end
    end
  end

  describe '#all_projects' do
    let(:project) { create(:project) }
    let(:cluster) { create(:cluster, projects: [project]) }

    subject { cluster.all_projects }

    context 'project cluster' do
      it 'returns project' do
        is_expected.to eq([project])
      end
    end

    context 'group cluster' do
      let(:cluster) { create(:cluster, :group) }
      let(:group) { cluster.group }
      let(:project) { create(:project, group: group) }
      let(:subgroup) { create(:group, parent: group) }
      let(:subproject) { create(:project, group: subgroup) }

      it 'returns all projects for group' do
        is_expected.to contain_exactly(project, subproject)
      end
    end
  end

  describe '#first_project' do
    subject { cluster.first_project }

    context 'when cluster belongs to a project' do
      let(:cluster) { create(:cluster, :project) }
      let(:project) { Clusters::Project.find_by_cluster_id(cluster.id).project }

      it { is_expected.to eq(project) }
    end

    context 'when cluster does not belong to projects' do
      let(:cluster) { create(:cluster) }

      it { is_expected.to be_nil }
    end
  end

  describe '#group' do
    subject { cluster.group }

    context 'when cluster belongs to a group' do
      let(:cluster) { create(:cluster, :group) }
      let(:group) { cluster.groups.first }

      it { is_expected.to eq(group) }
    end

    context 'when cluster does not belong to any group' do
      let(:cluster) { create(:cluster) }

      it { is_expected.to be_nil }
    end
  end

  describe '#applications' do
    set(:cluster) { create(:cluster) }

    subject { cluster.applications }

    context 'when none of applications are created' do
      it 'returns a list of a new objects' do
        is_expected.not_to be_empty
      end
    end

    context 'when applications are created' do
      let!(:helm) { create(:clusters_applications_helm, cluster: cluster) }
      let!(:ingress) { create(:clusters_applications_ingress, cluster: cluster) }
      let!(:cert_manager) { create(:clusters_applications_cert_managers, cluster: cluster) }
      let!(:prometheus) { create(:clusters_applications_prometheus, cluster: cluster) }
      let!(:runner) { create(:clusters_applications_runner, cluster: cluster) }
      let!(:jupyter) { create(:clusters_applications_jupyter, cluster: cluster) }
      let!(:knative) { create(:clusters_applications_knative, cluster: cluster) }

      it 'returns a list of created applications' do
        is_expected.to contain_exactly(helm, ingress, cert_manager, prometheus, runner, jupyter, knative)
      end
    end
  end

  describe '#created?' do
    let(:cluster) { create(:cluster, :provided_by_gcp) }

    subject { cluster.created? }

    context 'when status_name is :created' do
      before do
        allow(cluster).to receive_message_chain(:provider, :status_name).and_return(:created)
      end

      it { is_expected.to eq(true) }
    end

    context 'when status_name is not :created' do
      before do
        allow(cluster).to receive_message_chain(:provider, :status_name).and_return(:creating)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#allow_user_defined_namespace?' do
    let(:cluster) { create(:cluster, :provided_by_gcp) }

    subject { cluster.allow_user_defined_namespace? }

    context 'project type cluster' do
      it { is_expected.to be_truthy }
    end

    context 'group type cluster' do
      let(:cluster) { create(:cluster, :provided_by_gcp, :group) }

      it { is_expected.to be_falsey }
    end

    context 'instance type cluster' do
      let(:cluster) { create(:cluster, :provided_by_gcp, :instance) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#kube_ingress_domain' do
    let(:cluster) { create(:cluster, :provided_by_gcp) }

    subject { cluster.kube_ingress_domain }

    context 'with domain set in cluster' do
      let(:cluster) { create(:cluster, :provided_by_gcp, :with_domain) }

      it { is_expected.to eq(cluster.domain) }
    end

    context 'with no domain on cluster' do
      context 'with a project cluster' do
        let(:cluster) { create(:cluster, :project, :provided_by_gcp) }
        let(:project) { cluster.project }

        context 'with domain set at instance level' do
          before do
            stub_application_setting(auto_devops_domain: 'global_domain.com')

            it { is_expected.to eq('global_domain.com') }
          end
        end

        context 'with domain set on ProjectAutoDevops' do
          before do
            auto_devops = project.build_auto_devops(domain: 'legacy-ado-domain.com')
            auto_devops.save
          end

          it { is_expected.to eq('legacy-ado-domain.com') }
        end

        context 'with domain set as environment variable on project' do
          before do
            variable = project.variables.build(key: 'AUTO_DEVOPS_DOMAIN', value: 'project-ado-domain.com')
            variable.save
          end

          it { is_expected.to eq('project-ado-domain.com') }
        end

        context 'with domain set as environment variable on the group project' do
          let(:group) { create(:group) }

          before do
            project.update(parent_id: group.id)
            variable = group.variables.build(key: 'AUTO_DEVOPS_DOMAIN', value: 'group-ado-domain.com')
            variable.save
          end

          it { is_expected.to eq('group-ado-domain.com') }
        end
      end

      context 'with a group cluster' do
        let(:cluster) { create(:cluster, :group, :provided_by_gcp) }

        context 'with domain set as environment variable for the group' do
          let(:group) { cluster.group }

          before do
            variable = group.variables.build(key: 'AUTO_DEVOPS_DOMAIN', value: 'group-ado-domain.com')
            variable.save
          end

          it { is_expected.to eq('group-ado-domain.com') }
        end
      end
    end
  end

  describe '#predefined_variables' do
    subject { cluster.predefined_variables }

    context 'with an instance domain' do
      let(:cluster) { create(:cluster, :provided_by_gcp) }

      before do
        stub_application_setting(auto_devops_domain: 'global_domain.com')
      end

      it 'should include KUBE_INGRESS_BASE_DOMAIN' do
        expect(subject.to_hash).to include(KUBE_INGRESS_BASE_DOMAIN: 'global_domain.com')
      end
    end

    context 'with a cluster domain' do
      let(:cluster) { create(:cluster, :provided_by_gcp, domain: 'example.com') }

      it 'should include KUBE_INGRESS_BASE_DOMAIN' do
        expect(subject.to_hash).to include(KUBE_INGRESS_BASE_DOMAIN: 'example.com')
      end
    end

    context 'with no domain' do
      let(:cluster) { create(:cluster, :provided_by_gcp, :project) }

      it 'should return an empty array' do
        expect(subject.to_hash).to be_empty
      end
    end
  end
end

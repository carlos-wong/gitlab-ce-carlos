# frozen_string_literal: true

require 'spec_helper'

describe GroupPolicy do
  include_context 'GroupPolicy context'

  context 'public group with no user' do
    let(:group) { create(:group, :public) }
    let(:current_user) { nil }

    it do
      expect_allowed(:read_group)
      expect_allowed(*read_group_permissions)
      expect_disallowed(:upload_file)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
      expect_disallowed(:read_namespace)
    end
  end

  context 'with no user and public project' do
    let(:project) { create(:project, :public) }
    let(:current_user) { nil }

    before do
      create(:project_group_link, project: project, group: group)
    end

    it { expect_disallowed(:read_group) }
    it { expect_disallowed(*read_group_permissions) }
  end

  context 'with foreign user and public project' do
    let(:project) { create(:project, :public) }
    let(:current_user) { create(:user) }

    before do
      create(:project_group_link, project: project, group: group)
    end

    it { expect_disallowed(:read_group) }
    it { expect_disallowed(*read_group_permissions) }
  end

  context 'has projects' do
    let(:current_user) { create(:user) }
    let(:project) { create(:project, namespace: group) }

    before do
      project.add_developer(current_user)
    end

    it { expect_allowed(*read_group_permissions) }

    context 'in subgroups' do
      let(:subgroup) { create(:group, :private, parent: group) }
      let(:project) { create(:project, namespace: subgroup) }

      it { expect_allowed(*read_group_permissions) }
    end
  end

  context 'guests' do
    let(:current_user) { guest }

    it do
      expect_allowed(*read_group_permissions)
      expect_allowed(*guest_permissions)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'reporter' do
    let(:current_user) { reporter }

    it do
      expect_allowed(*read_group_permissions)
      expect_allowed(*guest_permissions)
      expect_allowed(*reporter_permissions)
      expect_disallowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'developer' do
    let(:current_user) { developer }

    it do
      expect_allowed(*read_group_permissions)
      expect_allowed(*guest_permissions)
      expect_allowed(*reporter_permissions)
      expect_allowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  context 'maintainer' do
    let(:current_user) { maintainer }

    context 'with subgroup_creation level set to maintainer' do
      before_all do
        group.update(subgroup_creation_level: ::Gitlab::Access::MAINTAINER_SUBGROUP_ACCESS)
      end

      it 'allows every maintainer permission plus creating subgroups' do
        create_subgroup_permission = [:create_subgroup]
        updated_maintainer_permissions =
          maintainer_permissions + create_subgroup_permission
        updated_owner_permissions =
          owner_permissions - create_subgroup_permission

        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*updated_maintainer_permissions)
        expect_disallowed(*updated_owner_permissions)
      end
    end

    context 'with subgroup_creation_level set to owner' do
      it 'allows every maintainer permission' do
        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end
  end

  context 'owner' do
    let(:current_user) { owner }

    it do
      expect_allowed(*read_group_permissions)
      expect_allowed(*guest_permissions)
      expect_allowed(*reporter_permissions)
      expect_allowed(*developer_permissions)
      expect_allowed(*maintainer_permissions)
      expect_allowed(*owner_permissions)
    end
  end

  context 'admin' do
    let(:current_user) { admin }

    it do
      expect_allowed(*read_group_permissions)
      expect_allowed(*guest_permissions)
      expect_allowed(*reporter_permissions)
      expect_allowed(*developer_permissions)
      expect_allowed(*maintainer_permissions)
      expect_allowed(*owner_permissions)
    end
  end

  describe 'private nested group use the highest access level from the group and inherited permissions' do
    let_it_be(:nested_group) do
      create(:group, :private, :owner_subgroup_creation_only, parent: group)
    end

    before_all do
      nested_group.add_guest(guest)
      nested_group.add_guest(reporter)
      nested_group.add_guest(developer)
      nested_group.add_guest(maintainer)

      group.owners.destroy_all # rubocop: disable DestroyAll

      group.add_guest(owner)
      nested_group.add_owner(owner)
    end

    subject { described_class.new(current_user, nested_group) }

    context 'with no user' do
      let(:current_user) { nil }

      it do
        expect_disallowed(*read_group_permissions)
        expect_disallowed(*guest_permissions)
        expect_disallowed(*reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'guests' do
      let(:current_user) { guest }

      it do
        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_disallowed(*reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'reporter' do
      let(:current_user) { reporter }

      it do
        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'developer' do
      let(:current_user) { developer }

      it do
        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_disallowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'maintainer' do
      let(:current_user) { maintainer }

      it do
        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end

    context 'owner' do
      let(:current_user) { owner }

      it do
        expect_allowed(*read_group_permissions)
        expect_allowed(*guest_permissions)
        expect_allowed(*reporter_permissions)
        expect_allowed(*developer_permissions)
        expect_allowed(*maintainer_permissions)
        expect_allowed(*owner_permissions)
      end
    end
  end

  describe 'change_share_with_group_lock' do
    context 'when the current_user owns the group' do
      let(:current_user) { owner }

      context 'when the group share_with_group_lock is enabled' do
        let(:group) { create(:group, share_with_group_lock: true, parent: parent) }

        before do
          group.add_owner(owner)
        end

        context 'when the parent group share_with_group_lock is enabled' do
          context 'when the group has a grandparent' do
            let(:parent) { create(:group, share_with_group_lock: true, parent: grandparent) }

            context 'when the grandparent share_with_group_lock is enabled' do
              let(:grandparent) { create(:group, share_with_group_lock: true) }

              context 'when the current_user owns the parent' do
                before do
                  parent.add_owner(current_user)
                end

                context 'when the current_user owns the grandparent' do
                  before do
                    grandparent.add_owner(current_user)
                  end

                  it { expect_allowed(:change_share_with_group_lock) }
                end

                context 'when the current_user does not own the grandparent' do
                  it { expect_disallowed(:change_share_with_group_lock) }
                end
              end

              context 'when the current_user does not own the parent' do
                it { expect_disallowed(:change_share_with_group_lock) }
              end
            end

            context 'when the grandparent share_with_group_lock is disabled' do
              let(:grandparent) { create(:group) }

              context 'when the current_user owns the parent' do
                before do
                  parent.add_owner(current_user)
                end

                it { expect_allowed(:change_share_with_group_lock) }
              end

              context 'when the current_user does not own the parent' do
                it { expect_disallowed(:change_share_with_group_lock) }
              end
            end
          end

          context 'when the group does not have a grandparent' do
            let(:parent) { create(:group, share_with_group_lock: true) }

            context 'when the current_user owns the parent' do
              before do
                parent.add_owner(current_user)
              end

              it { expect_allowed(:change_share_with_group_lock) }
            end

            context 'when the current_user does not own the parent' do
              it { expect_disallowed(:change_share_with_group_lock) }
            end
          end
        end

        context 'when the parent group share_with_group_lock is disabled' do
          let(:parent) { create(:group) }

          it { expect_allowed(:change_share_with_group_lock) }
        end
      end

      context 'when the group share_with_group_lock is disabled' do
        it { expect_allowed(:change_share_with_group_lock) }
      end
    end

    context 'when the current_user does not own the group' do
      let(:current_user) { create(:user) }

      it { expect_disallowed(:change_share_with_group_lock) }
    end
  end

  context 'transfer_projects' do
    shared_examples_for 'allowed to transfer projects' do
      before do
        group.update(project_creation_level: project_creation_level)
      end

      it { is_expected.to be_allowed(:transfer_projects) }
    end

    shared_examples_for 'not allowed to transfer projects' do
      before do
        group.update(project_creation_level: project_creation_level)
      end

      it { is_expected.to be_disallowed(:transfer_projects) }
    end

    context 'reporter' do
      let(:current_user) { reporter }

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::NO_ONE_PROJECT_ACCESS }
      end

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS }
      end

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS }
      end
    end

    context 'developer' do
      let(:current_user) { developer }

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::NO_ONE_PROJECT_ACCESS }
      end

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS }
      end

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS }
      end
    end

    context 'maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::NO_ONE_PROJECT_ACCESS }
      end

      it_behaves_like 'allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS }
      end

      it_behaves_like 'allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS }
      end
    end

    context 'owner' do
      let(:current_user) { owner }

      it_behaves_like 'not allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::NO_ONE_PROJECT_ACCESS }
      end

      it_behaves_like 'allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS }
      end

      it_behaves_like 'allowed to transfer projects' do
        let(:project_creation_level) { ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS }
      end
    end
  end

  context "create_projects" do
    context 'when group has no project creation level set' do
      before_all do
        group.update(project_creation_level: nil)
      end

      context 'reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:create_projects) }
      end

      context 'maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:create_projects) }
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:create_projects) }
      end
    end

    context 'when group has project creation level set to no one' do
      before_all do
        group.update(project_creation_level: ::Gitlab::Access::NO_ONE_PROJECT_ACCESS)
      end

      context 'reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:create_projects) }
      end
    end

    context 'when group has project creation level set to maintainer only' do
      before_all do
        group.update(project_creation_level: ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS)
      end

      context 'reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:create_projects) }
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:create_projects) }
      end
    end

    context 'when group has project creation level set to developers + maintainer' do
      before_all do
        group.update(project_creation_level: ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS)
      end

      context 'reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:create_projects) }
      end

      context 'developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:create_projects) }
      end

      context 'maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:create_projects) }
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:create_projects) }
      end
    end
  end

  context "create_subgroup" do
    context 'when group has subgroup creation level set to owner' do
      before_all do
        group.update(subgroup_creation_level: ::Gitlab::Access::OWNER_SUBGROUP_ACCESS)
      end

      context 'reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:create_subgroup) }
      end

      context 'developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:create_subgroup) }
      end

      context 'maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:create_subgroup) }
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:create_subgroup) }
      end
    end

    context 'when group has subgroup creation level set to maintainer' do
      before_all do
        group.update(subgroup_creation_level: ::Gitlab::Access::MAINTAINER_SUBGROUP_ACCESS)
      end

      context 'reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:create_subgroup) }
      end

      context 'developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:create_subgroup) }
      end

      context 'maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:create_subgroup) }
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:create_subgroup) }
      end
    end
  end

  it_behaves_like 'clusterable policies' do
    let(:clusterable) { create(:group) }
    let(:cluster) do
      create(:cluster,
             :provided_by_gcp,
             :group,
             groups: [clusterable])
    end
  end

  describe 'update_max_artifacts_size' do
    let(:group) { create(:group, :public) }

    context 'when no user' do
      let(:current_user) { nil }

      it { expect_disallowed(:update_max_artifacts_size) }
    end

    context 'admin' do
      let(:current_user) { admin }

      it { expect_allowed(:update_max_artifacts_size) }
    end

    %w(guest reporter developer maintainer owner).each do |role|
      context role do
        let(:current_user) { send(role) }

        it { expect_disallowed(:update_max_artifacts_size) }
      end
    end
  end
end

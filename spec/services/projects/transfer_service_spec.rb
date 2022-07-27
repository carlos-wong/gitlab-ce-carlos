# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TransferService do
  include GitHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group_integration) { create(:integrations_slack, :group, group: group, webhook: 'http://group.slack.com') }

  let(:project) { create(:project, :repository, :legacy_storage, namespace: user.namespace) }
  let(:target) { group }
  let(:executor) { user }

  subject(:execute_transfer) { described_class.new(project, executor).execute(target).tap { project.reload } }

  context 'with npm packages' do
    before do
      group.add_owner(user)
    end

    subject(:transfer_service) { described_class.new(project, user) }

    let!(:package) { create(:npm_package, project: project) }

    context 'with a root namespace change' do
      it 'does not allow the transfer' do
        expect(transfer_service.execute(group)).to be false
        expect(project.errors[:new_namespace]).to include("Root namespace can't be updated if project has NPM packages")
      end
    end

    context 'without a root namespace change' do
      let(:root) { create(:group) }
      let(:group) { create(:group, parent: root) }
      let(:other_group) { create(:group, parent: root) }
      let(:project) { create(:project, :repository, namespace: group) }

      before do
        other_group.add_owner(user)
      end

      it 'does allow the transfer' do
        expect(transfer_service.execute(other_group)).to be true
        expect(project.errors[:new_namespace]).to be_empty
      end
    end
  end

  context 'namespace -> namespace' do
    before do
      allow_next_instance_of(Gitlab::UploadsTransfer) do |service|
        allow(service).to receive(:move_project).and_return(true)
      end

      group.add_owner(user)
    end

    it 'updates the namespace' do
      transfer_result = execute_transfer

      expect(transfer_result).to be_truthy
      expect(project.namespace).to eq(group)
    end

    context 'when project has an associated project namespace' do
      it 'keeps project namespace in sync with project' do
        transfer_result = execute_transfer

        expect(transfer_result).to be_truthy

        project_namespace_in_sync(group)
      end

      context 'when project is transferred to a deeper nested group' do
        let(:parent_group) { create(:group) }
        let(:sub_group) { create(:group, parent: parent_group) }
        let(:sub_sub_group) { create(:group, parent: sub_group) }
        let(:group) { sub_sub_group }

        it 'keeps project namespace in sync with project' do
          transfer_result = execute_transfer

          expect(transfer_result).to be_truthy

          project_namespace_in_sync(sub_sub_group)
        end
      end
    end
  end

  context 'project in a group -> a personal namespace', :enable_admin_mode do
    let(:project) { create(:project, :repository, :legacy_storage, group: group) }
    let(:target) { user.namespace }
    # We need to use an admin user as the executor because
    # only an admin user has required permissions to transfer projects
    # under _all_ the different circumstances specified below.
    let(:executor) { create(:user, :admin) }

    it 'executes the transfer to personal namespace successfully' do
      execute_transfer

      expect(project.namespace).to eq(user.namespace)
    end

    context 'the owner of the namespace does not have a direct membership in the project residing in the group' do
      it 'creates a project membership record for the owner of the namespace, with OWNER access level, after the transfer' do
        execute_transfer

        expect(project.members.owners.find_by(user_id: user.id)).to be_present
      end
    end

    context 'the owner of the namespace has a direct membership in the project residing in the group' do
      context 'that membership has an access level of OWNER' do
        before do
          project.add_owner(user)
        end

        it 'retains the project membership record for the owner of the namespace, with OWNER access level, after the transfer' do
          execute_transfer

          expect(project.members.owners.find_by(user_id: user.id)).to be_present
        end
      end

      context 'that membership has an access level that is not OWNER' do
        before do
          project.add_developer(user)
        end

        it 'updates the project membership record for the owner of the namespace, to OWNER access level, after the transfer' do
          execute_transfer

          expect(project.members.owners.find_by(user_id: user.id)).to be_present
        end
      end
    end
  end

  context 'when transfer succeeds' do
    before do
      group.add_owner(user)
    end

    it 'sends notifications' do
      expect_any_instance_of(NotificationService).to receive(:project_was_moved)

      execute_transfer
    end

    it 'invalidates the user\'s personal_project_count cache' do
      expect(user).to receive(:invalidate_personal_projects_count)

      execute_transfer
    end

    it 'executes system hooks' do
      expect_next_instance_of(described_class) do |service|
        expect(service).to receive(:execute_system_hooks)
      end

      execute_transfer
    end

    it 'moves the disk path', :aggregate_failures do
      old_path = project.repository.disk_path
      old_full_path = project.repository.full_path

      execute_transfer

      project.reload_repository!

      expect(project.repository.disk_path).not_to eq(old_path)
      expect(project.repository.full_path).not_to eq(old_full_path)
      expect(project.disk_path).not_to eq(old_path)
      expect(project.disk_path).to start_with(group.path)
    end

    it 'updates project full path in .git/config' do
      execute_transfer

      expect(rugged_config['gitlab.fullpath']).to eq "#{group.full_path}/#{project.path}"
    end

    it 'updates storage location' do
      execute_transfer

      expect(project.project_repository).to have_attributes(
        disk_path: "#{group.full_path}/#{project.path}",
        shard_name: project.repository_storage
      )
    end

    context 'with a project integration' do
      let_it_be_with_reload(:project) { create(:project, namespace: user.namespace) }
      let_it_be(:instance_integration) { create(:integrations_slack, :instance) }
      let_it_be(:project_integration) { create(:integrations_slack, project: project) }

      context 'when it inherits from instance_integration' do
        before do
          project_integration.update!(inherit_from_id: instance_integration.id, webhook: instance_integration.webhook)
        end

        it 'replaces inherited integrations', :aggregate_failures do
          expect { execute_transfer }
            .to change(Integration, :count).by(0)
            .and change { project.slack_integration.webhook }.to eq(group_integration.webhook)
        end
      end

      context 'with a custom integration' do
        it 'does not update the integrations' do
          expect { execute_transfer }.not_to change { project.slack_integration.webhook }
        end
      end
    end

    context 'when project has pending builds', :sidekiq_inline do
      let!(:other_project) { create(:project) }
      let!(:pending_build) { create(:ci_pending_build, project: project.reload) }
      let!(:unrelated_pending_build) { create(:ci_pending_build, project: other_project) }

      before do
        group.reload
      end

      it 'updates pending builds for the project', :aggregate_failures do
        execute_transfer

        pending_build.reload
        unrelated_pending_build.reload

        expect(pending_build.namespace_id).to eq(group.id)
        expect(pending_build.namespace_traversal_ids).to eq(group.traversal_ids)
        expect(unrelated_pending_build.namespace_id).to eq(other_project.namespace_id)
        expect(unrelated_pending_build.namespace_traversal_ids).to eq(other_project.namespace.traversal_ids)
      end
    end
  end

  context 'when transfer fails' do
    let!(:original_path) { project_path(project) }

    def attempt_project_transfer(&block)
      expect do
        execute_transfer
      end.to raise_error(ActiveRecord::ActiveRecordError)
    end

    before do
      group.add_owner(user)

      expect_any_instance_of(Labels::TransferService).to receive(:execute).and_raise(ActiveRecord::StatementInvalid, "PG ERROR")
    end

    def project_path(project)
      Gitlab::GitalyClient::StorageSettings.allow_disk_access do
        project.repository.path_to_repo
      end
    end

    def current_path
      project_path(project)
    end

    it 'rolls back repo location' do
      attempt_project_transfer

      expect(project.repository.raw.exists?).to be(true)
      expect(original_path).to eq current_path
    end

    it 'rolls back project full path in .git/config' do
      attempt_project_transfer

      expect(rugged_config['gitlab.fullpath']).to eq project.full_path
    end

    it "doesn't send move notifications" do
      expect_any_instance_of(NotificationService).not_to receive(:project_was_moved)

      attempt_project_transfer
    end

    it "doesn't run system hooks" do
      attempt_project_transfer do |service|
        expect(service).not_to receive(:execute_system_hooks)
      end
    end

    it 'does not update storage location' do
      attempt_project_transfer

      expect(project.project_repository).to have_attributes(
        disk_path: project.disk_path,
        shard_name: project.repository_storage
      )
    end

    context 'when project has pending builds', :sidekiq_inline do
      let!(:other_project) { create(:project) }
      let!(:pending_build) { create(:ci_pending_build, project: project.reload) }
      let!(:unrelated_pending_build) { create(:ci_pending_build, project: other_project) }

      it 'does not update pending builds for the project', :aggregate_failures do
        attempt_project_transfer

        pending_build.reload
        unrelated_pending_build.reload

        expect(pending_build.namespace_id).to eq(project.namespace_id)
        expect(pending_build.namespace_traversal_ids).to eq(project.namespace.traversal_ids)
        expect(unrelated_pending_build.namespace_id).to eq(other_project.namespace_id)
        expect(unrelated_pending_build.namespace_traversal_ids).to eq(other_project.namespace.traversal_ids)
      end
    end

    context 'when project has an associated project namespace' do
      it 'keeps project namespace in sync with project' do
        attempt_project_transfer

        project_namespace_in_sync(user.namespace)
      end
    end
  end

  context 'namespace -> no namespace' do
    let(:group) { nil }

    it 'does not allow the project transfer' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.namespace).to eq(user.namespace)
      expect(project.errors.messages[:new_namespace].first).to eq 'Please select a new namespace for your project.'
    end

    context 'when project has an associated project namespace' do
      it 'keeps project namespace in sync with project' do
        transfer_result = execute_transfer

        expect(transfer_result).to be false

        project_namespace_in_sync(user.namespace)
      end
    end
  end

  context 'disallow transferring of project with tags' do
    let(:container_repository) { create(:container_repository) }

    before do
      stub_container_registry_config(enabled: true)
      stub_container_registry_tags(repository: :any, tags: ['tag'])
      project.container_repositories << container_repository
    end

    it 'does not allow the project transfer' do
      expect(execute_transfer).to eq false
    end
  end

  context 'namespace -> not allowed namespace' do
    it 'does not allow the project transfer' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.namespace).to eq(user.namespace)
    end
  end

  context 'namespace which contains orphan repository with same projects path name' do
    let(:raw_fake_repo) { Gitlab::Git::Repository.new('default', File.join(group.full_path, "#{project.path}.git"), nil, nil) }

    before do
      group.add_owner(user)

      raw_fake_repo.create_repository
    end

    after do
      raw_fake_repo.remove
    end

    it 'does not allow the project transfer' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.namespace).to eq(user.namespace)
      expect(project.errors[:new_namespace]).to include('Cannot move project')
    end
  end

  context 'target namespace containing the same project name' do
    before do
      group.add_owner(user)
      create(:project, name: project.name, group: group, path: 'other')
    end

    it 'does not allow the project transfer' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.namespace).to eq(user.namespace)
      expect(project.errors[:new_namespace]).to include('Project with same name or path in target namespace already exists')
    end
  end

  context 'target namespace containing the same project path' do
    before do
      group.add_owner(user)
      create(:project, name: 'other-name', path: project.path, group: group)
    end

    it 'does not allow the project transfer' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.namespace).to eq(user.namespace)
      expect(project.errors[:new_namespace]).to include('Project with same name or path in target namespace already exists')
    end
  end

  context 'target namespace matches current namespace' do
    let(:group) { user.namespace }

    it 'does not allow project transfer' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.namespace).to eq(user.namespace)
      expect(project.errors[:new_namespace]).to include('Project is already in this namespace.')
    end
  end

  context 'when user does not own the project' do
    let(:project) { create(:project, :repository, :legacy_storage) }

    before do
      project.add_developer(user)
    end

    it 'does not allow project transfer to the target namespace' do
      transfer_result = execute_transfer

      expect(transfer_result).to eq false
      expect(project.errors[:new_namespace]).to include("You don't have permission to transfer this project.")
    end
  end

  context 'when user can create projects in the target namespace' do
    let(:group) { create(:group, project_creation_level: ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS) }

    context 'but has only developer permissions in the target namespace' do
      before do
        group.add_developer(user)
      end

      it 'does not allow project transfer to the target namespace' do
        transfer_result = execute_transfer

        expect(transfer_result).to eq false
        expect(project.namespace).to eq(user.namespace)
        expect(project.errors[:new_namespace]).to include("You don't have permission to transfer projects into that namespace.")
      end
    end
  end

  context 'visibility level' do
    let(:group) { create(:group, :internal) }

    before do
      group.add_owner(user)
    end

    context 'when namespace visibility level < project visibility level' do
      let(:project) { create(:project, :public, :repository, namespace: user.namespace) }

      before do
        execute_transfer
      end

      it { expect(project.visibility_level).to eq(group.visibility_level) }
    end

    context 'when namespace visibility level > project visibility level' do
      let(:project) { create(:project, :private, :repository, namespace: user.namespace) }

      before do
        execute_transfer
      end

      it { expect(project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE) }
    end
  end

  context 'shared Runners group level configurations' do
    using RSpec::Parameterized::TableSyntax

    where(:project_shared_runners_enabled, :shared_runners_setting, :expected_shared_runners_enabled) do
      true  | :disabled_and_unoverridable | false
      false | :disabled_and_unoverridable | false
      true  | :disabled_with_override     | true
      false | :disabled_with_override     | false
      true  | :shared_runners_enabled     | true
      false | :shared_runners_enabled     | false
    end

    with_them do
      let(:project) { create(:project, :public, :repository, namespace: user.namespace, shared_runners_enabled: project_shared_runners_enabled) }
      let(:group) { create(:group, shared_runners_setting) }

      it 'updates shared runners based on the parent group' do
        group.add_owner(user)

        expect(execute_transfer).to eq(true)

        expect(project.shared_runners_enabled).to eq(expected_shared_runners_enabled)
      end
    end
  end

  context 'missing group labels applied to issues or merge requests' do
    it 'delegates transfer to Labels::TransferService' do
      group.add_owner(user)

      expect_next_instance_of(Labels::TransferService, user, project.group, project) do |labels_transfer_service|
        expect(labels_transfer_service).to receive(:execute).once.and_call_original
      end

      execute_transfer
    end
  end

  context 'missing group milestones applied to issues or merge requests' do
    it 'delegates transfer to Milestones::TransferService' do
      group.add_owner(user)

      expect_next_instance_of(Milestones::TransferService, user, project.group, project) do |milestones_transfer_service|
        expect(milestones_transfer_service).to receive(:execute).once.and_call_original
      end

      execute_transfer
    end
  end

  context 'when hashed storage in use' do
    let!(:project) { create(:project, :repository, namespace: user.namespace) }
    let!(:old_disk_path) { project.repository.disk_path }

    before do
      group.add_owner(user)
    end

    it 'does not move the disk path', :aggregate_failures do
      new_full_path = "#{group.full_path}/#{project.path}"

      execute_transfer

      project.reload_repository!

      expect(project.repository).to have_attributes(
        disk_path: old_disk_path,
        full_path: new_full_path
      )
      expect(project.disk_path).to eq(old_disk_path)
    end

    it 'does not move the disk path when the transfer fails', :aggregate_failures do
      old_full_path = project.full_path

      expect_next_instance_of(described_class) do |service|
        allow(service).to receive(:execute_system_hooks).and_raise('foo')
      end

      expect { execute_transfer }.to raise_error('foo')

      project.reload_repository!

      expect(project.repository).to have_attributes(
        disk_path: old_disk_path,
        full_path: old_full_path
      )
      expect(project.disk_path).to eq(old_disk_path)
    end
  end

  describe 'refreshing project authorizations' do
    let(:old_group) { create(:group) }
    let!(:project) { create(:project, namespace: old_group) }
    let(:member_of_old_group) { create(:user) }
    let(:group) { create(:group) }
    let(:member_of_new_group) { create(:user) }

    before do
      old_group.add_developer(member_of_old_group)
      group.add_maintainer(member_of_new_group)

      # Add the executing user as owner in both groups, so that
      # transfer can be executed.
      old_group.add_owner(user)
      group.add_owner(user)
    end

    it 'calls AuthorizedProjectUpdate::ProjectRecalculateWorker to update project authorizations' do
      expect(AuthorizedProjectUpdate::ProjectRecalculateWorker)
        .to receive(:perform_async).with(project.id)

      execute_transfer
    end

    it 'calls AuthorizedProjectUpdate::UserRefreshFromReplicaWorker with a delay to update project authorizations' do
      user_ids = [user.id, member_of_old_group.id, member_of_new_group.id].map { |id| [id] }

      expect(AuthorizedProjectUpdate::UserRefreshFromReplicaWorker).to(
        receive(:bulk_perform_in)
          .with(1.hour,
                user_ids,
                batch_delay: 30.seconds, batch_size: 100)
      )

      subject
    end

    it 'refreshes the permissions of the members of the old and new namespace', :sidekiq_inline do
      expect { execute_transfer }
        .to change { member_of_old_group.authorized_projects.include?(project) }.from(true).to(false)
        .and change { member_of_new_group.authorized_projects.include?(project) }.from(false).to(true)
    end
  end

  describe 'transferring a design repository' do
    subject { described_class.new(project, user) }

    before do
      group.add_owner(user)
    end

    def design_repository
      project.design_repository
    end

    it 'does not create a design repository' do
      expect(subject.execute(group)).to be true

      project.clear_memoization(:design_repository)

      expect(design_repository.exists?).to be false
    end

    describe 'when the project has a design repository' do
      let(:project_repo_path) { "#{project.path}#{::Gitlab::GlRepository::DESIGN.path_suffix}" }
      let(:old_full_path) { "#{user.namespace.full_path}/#{project_repo_path}" }
      let(:new_full_path) { "#{group.full_path}/#{project_repo_path}" }

      context 'with legacy storage' do
        let(:project) { create(:project, :repository, :legacy_storage, :design_repo, namespace: user.namespace) }

        it 'moves the repository' do
          expect(subject.execute(group)).to be true

          project.clear_memoization(:design_repository)

          expect(design_repository).to have_attributes(
            disk_path: new_full_path,
            full_path: new_full_path
          )
        end

        it 'does not move the repository when an error occurs', :aggregate_failures do
          allow(subject).to receive(:execute_system_hooks).and_raise('foo')
          expect { subject.execute(group) }.to raise_error('foo')

          project.clear_memoization(:design_repository)

          expect(design_repository).to have_attributes(
            disk_path: old_full_path,
            full_path: old_full_path
          )
        end
      end

      context 'with hashed storage' do
        let(:project) { create(:project, :repository, namespace: user.namespace) }

        it 'does not move the repository' do
          old_disk_path = design_repository.disk_path

          expect(subject.execute(group)).to be true

          project.clear_memoization(:design_repository)

          expect(design_repository).to have_attributes(
            disk_path: old_disk_path,
            full_path: new_full_path
          )
        end

        it 'does not move the repository when an error occurs' do
          old_disk_path = design_repository.disk_path

          allow(subject).to receive(:execute_system_hooks).and_raise('foo')
          expect { subject.execute(group) }.to raise_error('foo')

          project.clear_memoization(:design_repository)

          expect(design_repository).to have_attributes(
            disk_path: old_disk_path,
            full_path: old_full_path
          )
        end
      end
    end
  end

  context 'handling issue contacts' do
    let_it_be(:root_group) { create(:group) }

    let(:project) { create(:project, group: root_group) }

    before do
      root_group.add_owner(user)
      target.add_owner(user)
      create_list(:issue_customer_relations_contact, 2, :for_issue, issue: create(:issue, project: project))
    end

    context 'with the same root_ancestor' do
      let(:target) { create(:group, parent: root_group) }

      it 'retains issue contacts' do
        expect { execute_transfer }.not_to change { CustomerRelations::IssueContact.count }
      end
    end

    context 'with a different root_ancestor' do
      it 'deletes issue contacts' do
        expect { execute_transfer }.to change { CustomerRelations::IssueContact.count }.by(-2)
      end
    end
  end

  def rugged_config
    rugged_repo(project.repository).config
  end

  def project_namespace_in_sync(group)
    project.reload
    expect(project.namespace).to eq(group)
    expect(project.project_namespace.visibility_level).to eq(project.visibility_level)
    expect(project.project_namespace.path).to eq(project.path)
    expect(project.project_namespace.parent).to eq(project.namespace)
    expect(project.project_namespace.traversal_ids).to eq([*project.namespace.traversal_ids, project.project_namespace.id])
  end
end

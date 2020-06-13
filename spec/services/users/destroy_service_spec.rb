# frozen_string_literal: true

require 'spec_helper'

describe Users::DestroyService do
  describe "Deletes a user and all their personal projects" do
    let!(:user)      { create(:user) }
    let!(:admin)     { create(:admin) }
    let!(:namespace) { user.namespace }
    let!(:project)   { create(:project, namespace: namespace) }
    let(:service)    { described_class.new(admin) }
    let(:gitlab_shell) { Gitlab::Shell.new }

    context 'no options are given' do
      it 'deletes the user' do
        user_data = service.execute(user)

        expect { user_data['email'].to eq(user.email) }
        expect { User.find(user.id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { Namespace.find(namespace.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'deletes user associations in batches' do
        expect(user).to receive(:destroy_dependent_associations_in_batches)

        service.execute(user)
      end

      it 'does not include snippets when deleting in batches' do
        expect(user).to receive(:destroy_dependent_associations_in_batches).with({ exclude: [:snippets] })

        service.execute(user)
      end

      it 'will delete the project' do
        expect_next_instance_of(Projects::DestroyService) do |destroy_service|
          expect(destroy_service).to receive(:execute).once.and_return(true)
        end

        service.execute(user)
      end

      it 'calls the bulk snippet destroy service for the user personal snippets' do
        repo1 = create(:personal_snippet, :repository, author: user).snippet_repository
        repo2 = create(:project_snippet, :repository, author: user).snippet_repository
        repo3 = create(:project_snippet, :repository, project: project, author: user).snippet_repository

        aggregate_failures do
          expect(gitlab_shell.repository_exists?(repo1.shard_name, repo1.disk_path + '.git')).to be_truthy
          expect(gitlab_shell.repository_exists?(repo2.shard_name, repo2.disk_path + '.git')).to be_truthy
          expect(gitlab_shell.repository_exists?(repo3.shard_name, repo3.disk_path + '.git')).to be_truthy
        end

        # Call made when destroying user personal projects
        expect(Snippets::BulkDestroyService).to receive(:new)
          .with(admin, project.snippets).and_call_original

        # Call to remove user personal snippets and for
        # project snippets where projects are not user personal
        # ones
        expect(Snippets::BulkDestroyService).to receive(:new)
          .with(admin, user.snippets).and_call_original

        service.execute(user)

        aggregate_failures do
          expect(gitlab_shell.repository_exists?(repo1.shard_name, repo1.disk_path + '.git')).to be_falsey
          expect(gitlab_shell.repository_exists?(repo2.shard_name, repo2.disk_path + '.git')).to be_falsey
          expect(gitlab_shell.repository_exists?(repo3.shard_name, repo3.disk_path + '.git')).to be_falsey
        end
      end

      context 'when an error is raised deleting snippets' do
        it 'does not delete user' do
          snippet = create(:personal_snippet, :repository, author: user)

          bulk_service = double
          allow(Snippets::BulkDestroyService).to receive(:new).and_call_original
          allow(Snippets::BulkDestroyService).to receive(:new).with(admin, user.snippets).and_return(bulk_service)
          allow(bulk_service).to receive(:execute).and_return(ServiceResponse.error(message: 'foo'))

          aggregate_failures do
            expect { service.execute(user) }
              .to raise_error(Users::DestroyService::DestroyError, 'foo' )
            expect(snippet.reload).not_to be_nil
            expect(gitlab_shell.repository_exists?(snippet.repository_storage, snippet.disk_path + '.git')).to be_truthy
          end
        end
      end
    end

    context 'projects in pending_delete' do
      before do
        project.pending_delete = true
        project.save
      end

      it 'destroys a project in pending_delete' do
        expect_next_instance_of(Projects::DestroyService) do |destroy_service|
          expect(destroy_service).to receive(:execute).once.and_return(true)
        end

        service.execute(user)

        expect { Project.find(project.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "a deleted user's issues" do
      let(:project) { create(:project) }

      before do
        project.add_developer(user)
      end

      context "for an issue the user was assigned to" do
        let!(:issue) { create(:issue, project: project, assignees: [user]) }

        before do
          service.execute(user)
        end

        it 'does not delete issues the user is assigned to' do
          expect(Issue.find_by_id(issue.id)).to be_present
        end

        it 'migrates the issue so that it is "Unassigned"' do
          migrated_issue = Issue.find_by_id(issue.id)

          expect(migrated_issue.assignees).to be_empty
        end
      end
    end

    context "a deleted user's merge_requests" do
      let(:project) { create(:project, :repository) }

      before do
        project.add_developer(user)
      end

      context "for an merge request the user was assigned to" do
        let!(:merge_request) { create(:merge_request, source_project: project, assignees: [user]) }

        before do
          service.execute(user)
        end

        it 'does not delete merge requests the user is assigned to' do
          expect(MergeRequest.find_by_id(merge_request.id)).to be_present
        end

        it 'migrates the merge request so that it is "Unassigned"' do
          migrated_merge_request = MergeRequest.find_by_id(merge_request.id)

          expect(migrated_merge_request.assignees).to be_empty
        end
      end
    end

    context "solo owned groups present" do
      let(:solo_owned)  { create(:group) }
      let(:member)      { create(:group_member) }
      let(:user)        { member.user }

      before do
        solo_owned.group_members = [member]
      end

      it 'returns the user with attached errors' do
        expect(service.execute(user)).to be(user)
        expect(user.errors.full_messages).to eq([
          'You must transfer ownership or delete groups before you can remove user'
        ])
      end

      it 'does not delete the user' do
        service.execute(user)
        expect(User.find(user.id)).to eq user
      end
    end

    context "deletions with solo owned groups" do
      let(:solo_owned)      { create(:group) }
      let(:member)          { create(:group_member) }
      let(:user)            { member.user }

      before do
        solo_owned.group_members = [member]
        service.execute(user, delete_solo_owned_groups: true)
      end

      it 'deletes solo owned groups' do
        expect { Project.find(solo_owned.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'deletes the user' do
        expect { User.find(user.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "deletion permission checks" do
      it 'does not delete the user when user is not an admin' do
        other_user = create(:user)

        expect { described_class.new(other_user).execute(user) }.to raise_error(Gitlab::Access::AccessDeniedError)
        expect(User.exists?(user.id)).to be(true)
      end

      it 'allows admins to delete anyone' do
        described_class.new(admin).execute(user)

        expect(User.exists?(user.id)).to be(false)
      end

      it 'allows users to delete their own account' do
        described_class.new(user).execute(user)

        expect(User.exists?(user.id)).to be(false)
      end
    end

    context "migrating associated records" do
      let!(:issue)     { create(:issue, author: user) }

      it 'delegates to the `MigrateToGhostUser` service to move associated records to the ghost user' do
        expect_any_instance_of(Users::MigrateToGhostUserService).to receive(:execute).once.and_call_original

        service.execute(user)

        expect(issue.reload.author).to be_ghost
      end

      it 'does not run `MigrateToGhostUser` if hard_delete option is given' do
        expect_any_instance_of(Users::MigrateToGhostUserService).not_to receive(:execute)

        service.execute(user, hard_delete: true)

        expect(Issue.exists?(issue.id)).to be_falsy
      end
    end

    describe "user personal's repository removal" do
      context 'storages' do
        before do
          perform_enqueued_jobs { service.execute(user) }
        end

        context 'legacy storage' do
          let!(:project) { create(:project, :empty_repo, :legacy_storage, namespace: user.namespace) }

          it 'removes repository' do
            expect(gitlab_shell.repository_exists?(project.repository_storage, "#{project.disk_path}.git")).to be_falsey
          end
        end

        context 'hashed storage' do
          let!(:project) { create(:project, :empty_repo, namespace: user.namespace) }

          it 'removes repository' do
            expect(gitlab_shell.repository_exists?(project.repository_storage, "#{project.disk_path}.git")).to be_falsey
          end
        end
      end

      context 'repository removal status is taken into account' do
        it 'raises exception' do
          expect_next_instance_of(::Projects::DestroyService) do |destroy_service|
            expect(destroy_service).to receive(:execute).and_return(false)
          end

          expect { service.execute(user) }
            .to raise_error(Users::DestroyService::DestroyError, "Project #{project.id} can't be deleted" )
        end
      end
    end

    describe "calls the before/after callbacks" do
      it 'of project_members' do
        expect_any_instance_of(ProjectMember).to receive(:run_callbacks).with(:find).once
        expect_any_instance_of(ProjectMember).to receive(:run_callbacks).with(:initialize).once
        expect_any_instance_of(ProjectMember).to receive(:run_callbacks).with(:destroy).once

        service.execute(user)
      end

      it 'of group_members' do
        group_member = create(:group_member)
        group_member.group.group_members.create(user: user, access_level: 40)

        expect_any_instance_of(GroupMember).to receive(:run_callbacks).with(:find).once
        expect_any_instance_of(GroupMember).to receive(:run_callbacks).with(:initialize).once
        expect_any_instance_of(GroupMember).to receive(:run_callbacks).with(:destroy).once

        service.execute(user)
      end
    end
  end
end

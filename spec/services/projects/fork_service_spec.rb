# frozen_string_literal: true

require 'spec_helper'

describe Projects::ForkService do
  include ProjectForksHelper

  shared_examples 'forks count cache refresh' do
    it 'flushes the forks count cache of the source project', :clean_gitlab_redis_cache do
      expect(from_project.forks_count).to be_zero

      fork_project(from_project, to_user)

      expect(from_project.forks_count).to eq(1)
    end
  end

  context 'when forking a new project' do
    describe 'fork by user' do
      before do
        @from_user = create(:user)
        @from_namespace = @from_user.namespace
        avatar = fixture_file_upload("spec/fixtures/dk.png", "image/png")
        @from_project = create(:project,
                               :repository,
                               creator_id: @from_user.id,
                               namespace: @from_namespace,
                               star_count: 107,
                               avatar: avatar,
                               description: 'wow such project')
        @to_user = create(:user)
        @to_namespace = @to_user.namespace
        @from_project.add_user(@to_user, :developer)
      end

      context 'fork project' do
        context 'when forker is a guest' do
          before do
            @guest = create(:user)
            @from_project.add_user(@guest, :guest)
          end
          subject { fork_project(@from_project, @guest) }

          it { is_expected.not_to be_persisted }
          it { expect(subject.errors[:forked_from_project_id]).to eq(['is forbidden']) }

          it 'does not create a fork network' do
            expect { subject }.not_to change { @from_project.reload.fork_network }
          end
        end

        it_behaves_like 'forks count cache refresh' do
          let(:from_project) { @from_project }
          let(:to_user) { @to_user }
        end

        describe "successfully creates project in the user namespace" do
          let(:to_project) { fork_project(@from_project, @to_user, namespace: @to_user.namespace) }

          it { expect(to_project).to be_persisted }
          it { expect(to_project.errors).to be_empty }
          it { expect(to_project.owner).to eq(@to_user) }
          it { expect(to_project.namespace).to eq(@to_user.namespace) }
          it { expect(to_project.star_count).to be_zero }
          it { expect(to_project.description).to eq(@from_project.description) }
          it { expect(to_project.avatar.file).to be_exists }
          it { expect(to_project.ci_config_path).to eq(@from_project.ci_config_path) }

          # This test is here because we had a bug where the from-project lost its
          # avatar after being forked.
          # https://gitlab.com/gitlab-org/gitlab-foss/issues/26158
          it "after forking the from-project still has its avatar" do
            # If we do not fork the project first we cannot detect the bug.
            expect(to_project).to be_persisted

            expect(@from_project.avatar.file).to be_exists
          end

          it_behaves_like 'forks count cache refresh' do
            let(:from_project) { @from_project }
            let(:to_user) { @to_user }
          end

          it 'creates a fork network with the new project and the root project set' do
            to_project
            fork_network = @from_project.reload.fork_network

            expect(fork_network).not_to be_nil
            expect(fork_network.root_project).to eq(@from_project)
            expect(fork_network.projects).to contain_exactly(@from_project, to_project)
          end

          it 'imports the repository of the forked project', :sidekiq_might_not_need_inline do
            to_project = fork_project(@from_project, @to_user, repository: true)

            expect(to_project.empty_repo?).to be_falsy
          end
        end

        context 'creating a fork of a fork' do
          let(:from_forked_project) { fork_project(@from_project, @to_user) }
          let(:other_namespace) do
            group = create(:group)
            group.add_owner(@to_user)
            group
          end
          let(:to_project) { fork_project(from_forked_project, @to_user, namespace: other_namespace) }

          it 'sets the root of the network to the root project' do
            expect(to_project.fork_network.root_project).to eq(@from_project)
          end

          it 'sets the forked_from_project on the membership' do
            expect(to_project.fork_network_member.forked_from_project).to eq(from_forked_project)
          end

          it_behaves_like 'forks count cache refresh' do
            let(:from_project) { from_forked_project }
            let(:to_user) { @to_user }
          end
        end
      end

      context 'project already exists' do
        it "fails due to validation, not transaction failure" do
          @existing_project = create(:project, :repository, creator_id: @to_user.id, name: @from_project.name, namespace: @to_namespace)
          @to_project = fork_project(@from_project, @to_user, namespace: @to_namespace)
          expect(@existing_project).to be_persisted

          expect(@to_project).not_to be_persisted
          expect(@to_project.errors[:name]).to eq(['has already been taken'])
          expect(@to_project.errors[:path]).to eq(['has already been taken'])
        end
      end

      context 'repository in legacy storage already exists' do
        let(:fake_repo_path) { File.join(TestEnv.repos_path, @to_user.namespace.full_path, "#{@from_project.path}.git") }
        let(:params) { { namespace: @to_user.namespace } }

        before do
          stub_application_setting(hashed_storage_enabled: false)
          TestEnv.create_bare_repository(fake_repo_path)
        end

        after do
          FileUtils.rm_rf(fake_repo_path)
        end

        subject { fork_project(@from_project, @to_user, params) }

        it 'does not allow creation' do
          expect(subject).not_to be_persisted
          expect(subject.errors.messages).to have_key(:base)
          expect(subject.errors.messages[:base].first).to match('There is already a repository with that name on disk')
        end

        context 'when repository disk validation is explicitly skipped' do
          let(:params) { super().merge(skip_disk_validation: true) }

          it 'allows fork project creation' do
            expect(subject).to be_persisted
            expect(subject.errors.messages).to be_empty
          end
        end
      end

      context 'GitLab CI is enabled' do
        it "forks and enables CI for fork" do
          @from_project.enable_ci
          @to_project = fork_project(@from_project, @to_user)
          expect(@to_project.builds_enabled?).to be_truthy
        end
      end

      context "CI/CD settings" do
        let(:to_project) { fork_project(@from_project, @to_user) }

        context "when origin has git depth specified" do
          before do
            @from_project.update(ci_default_git_depth: 42)
          end

          it "inherits default_git_depth from the origin project" do
            expect(to_project.ci_default_git_depth).to eq(42)
          end
        end

        context "when origin does not define git depth" do
          before do
            @from_project.update!(ci_default_git_depth: nil)
          end

          it "the fork has git depth set to 0" do
            expect(to_project.ci_default_git_depth).to eq(0)
          end
        end
      end

      context "when project has restricted visibility level" do
        context "and only one visibility level is restricted" do
          before do
            @from_project.update(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
            stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::INTERNAL])
          end

          it "creates fork with lowest level" do
            forked_project = fork_project(@from_project, @to_user)

            expect(forked_project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
          end
        end

        context "and all visibility levels are restricted" do
          before do
            stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC, Gitlab::VisibilityLevel::INTERNAL, Gitlab::VisibilityLevel::PRIVATE])
          end

          it "creates fork with private visibility levels" do
            forked_project = fork_project(@from_project, @to_user)

            expect(forked_project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
          end
        end
      end

      context 'when forking is disabled' do
        before do
          @from_project.project_feature.update_attribute(
            :forking_access_level, ProjectFeature::DISABLED)
        end

        it 'fails' do
          to_project = fork_project(@from_project, @to_user, namespace: @to_user.namespace)

          expect(to_project.errors[:forked_from_project_id]).to eq(['is forbidden'])
        end
      end
    end

    describe 'fork to namespace' do
      before do
        @group_owner = create(:user)
        @developer   = create(:user)
        @project     = create(:project, :repository,
                              creator_id: @group_owner.id,
                              star_count: 777,
                              description: 'Wow, such a cool project!',
                              ci_config_path: 'debian/salsa-ci.yml')
        @group = create(:group)
        @group.add_user(@group_owner, GroupMember::OWNER)
        @group.add_user(@developer,   GroupMember::DEVELOPER)
        @project.add_user(@developer,   :developer)
        @project.add_user(@group_owner, :developer)
        @opts = { namespace: @group }
      end

      context 'fork project for group' do
        it 'group owner successfully forks project into the group' do
          to_project = fork_project(@project, @group_owner, @opts)

          expect(to_project).to                be_persisted
          expect(to_project.errors).to         be_empty
          expect(to_project.owner).to          eq(@group)
          expect(to_project.namespace).to      eq(@group)
          expect(to_project.name).to           eq(@project.name)
          expect(to_project.path).to           eq(@project.path)
          expect(to_project.description).to    eq(@project.description)
          expect(to_project.ci_config_path).to eq(@project.ci_config_path)
          expect(to_project.star_count).to     be_zero
        end
      end

      context 'fork project for group when user not owner' do
        it 'group developer fails to fork project into the group' do
          to_project = fork_project(@project, @developer, @opts)

          expect(to_project.errors[:namespace]).to eq(['is not valid'])
        end
      end

      context 'project already exists in group' do
        it 'fails due to validation, not transaction failure' do
          existing_project = create(:project, :repository,
                                    name: @project.name,
                                    namespace: @group)
          to_project = fork_project(@project, @group_owner, @opts)
          expect(existing_project.persisted?).to be_truthy
          expect(to_project.errors[:name]).to eq(['has already been taken'])
          expect(to_project.errors[:path]).to eq(['has already been taken'])
        end
      end

      context 'when the namespace has a lower visibility level than the project' do
        it 'creates the project with the lower visibility level' do
          public_project = create(:project, :public)
          private_group = create(:group, :private)
          group_owner = create(:user)
          private_group.add_owner(group_owner)

          forked_project = fork_project(public_project, group_owner, namespace: private_group)

          expect(forked_project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
        end
      end
    end
  end

  context 'when a project is already forked' do
    it 'creates a new poolresository after the project is moved to a new shard' do
      project = create(:project, :public, :repository)
      fork_before_move = fork_project(project)

      # Stub everything required to move a project to a Gitaly shard that does not exist
      stub_storage_settings('test_second_storage' => { 'path' => TestEnv::SECOND_STORAGE_PATH })
      allow_any_instance_of(Gitlab::Git::Repository).to receive(:create_repository)
        .and_return(true)
      allow_any_instance_of(Gitlab::Git::Repository).to receive(:replicate)
      allow_any_instance_of(Gitlab::Git::Repository).to receive(:checksum)
        .and_return(::Gitlab::Git::BLANK_SHA)

      Projects::UpdateRepositoryStorageService.new(project).execute('test_second_storage')
      fork_after_move = fork_project(project)
      pool_repository_before_move = PoolRepository.joins(:shard)
                                      .where(source_project: project, shards: { name: 'default' }).first
      pool_repository_after_move = PoolRepository.joins(:shard)
                                     .where(source_project: project, shards: { name: 'test_second_storage' }).first

      expect(fork_before_move.pool_repository).to eq(pool_repository_before_move)
      expect(fork_after_move.pool_repository).to eq(pool_repository_after_move)
    end
  end

  context 'when forking with object pools' do
    let(:fork_from_project) { create(:project, :public) }
    let(:forker) { create(:user) }

    before do
      stub_feature_flags(object_pools: true)
    end

    context 'when no pool exists' do
      it 'creates a new object pool' do
        forked_project = fork_project(fork_from_project, forker)

        expect(forked_project.pool_repository).to eq(fork_from_project.pool_repository)
      end
    end

    context 'when a pool already exists' do
      let!(:pool_repository) { create(:pool_repository, source_project: fork_from_project) }

      it 'joins the object pool' do
        forked_project = fork_project(fork_from_project, forker)

        expect(forked_project.pool_repository).to eq(fork_from_project.pool_repository)
      end
    end
  end

  context 'when linking fork to an existing project' do
    let(:fork_from_project) { create(:project, :public) }
    let(:fork_to_project) { create(:project, :public) }
    let(:user) do
      create(:user).tap { |u| fork_to_project.add_maintainer(u) }
    end

    subject { described_class.new(fork_from_project, user) }

    def forked_from_project(project)
      project.fork_network_member&.forked_from_project
    end

    context 'if project is already forked' do
      it 'does not create fork relation' do
        allow(fork_to_project).to receive(:forked?).and_return(true)
        expect(forked_from_project(fork_to_project)).to be_nil
        expect(subject.execute(fork_to_project)).to be_nil
        expect(forked_from_project(fork_to_project)).to be_nil
      end
    end

    context 'if project is not forked' do
      it 'creates fork relation' do
        expect(fork_to_project.forked?).to be_falsy
        expect(forked_from_project(fork_to_project)).to be_nil

        subject.execute(fork_to_project)

        fork_to_project.reload

        expect(fork_to_project.forked?).to be true
        expect(forked_from_project(fork_to_project)).to eq fork_from_project
        expect(fork_to_project.forked_from_project).to eq fork_from_project
      end

      it 'flushes the forks count cache of the source project' do
        expect(fork_from_project.forks_count).to be_zero

        subject.execute(fork_to_project)

        expect(fork_from_project.forks_count).to eq(1)
      end

      context 'if the fork is not allowed' do
        let(:fork_from_project) { create(:project, :private) }

        it 'does not delete the LFS objects' do
          create(:lfs_objects_project, project: fork_to_project)

          expect { subject.execute(fork_to_project) }
            .not_to change { fork_to_project.lfs_objects_projects.size }
        end
      end
    end
  end

  describe '#valid_fork_targets' do
    let(:finder_mock) { instance_double('ForkTargetsFinder', execute: ['finder_return_value']) }
    let(:current_user) { instance_double('User') }
    let(:project) { instance_double('Project') }

    before do
      allow(ForkTargetsFinder).to receive(:new).with(project, current_user).and_return(finder_mock)
    end

    it 'returns whatever finder returns' do
      expect(described_class.new(project, current_user).valid_fork_targets).to eq ['finder_return_value']
    end
  end

  describe '#valid_fork_target?' do
    subject { described_class.new(project, user, params).valid_fork_target? }

    let(:project) { Project.new }
    let(:params) { {} }

    context 'when current user is an admin' do
      let(:user) { build(:user, :admin) }

      it { is_expected.to be_truthy }
    end

    context 'when current_user is not an admin' do
      let(:user) { create(:user) }

      let(:finder_mock) { instance_double('ForkTargetsFinder', execute: [user.namespace]) }
      let(:project) { create(:project) }

      before do
        allow(ForkTargetsFinder).to receive(:new).with(project, user).and_return(finder_mock)
      end

      context 'when target namespace is in valid fork targets' do
        let(:params) { { namespace: user.namespace } }

        it { is_expected.to be_truthy }
      end

      context 'when target namespace is not in valid fork targets' do
        let(:params) { { namespace: create(:group) } }

        it { is_expected.to be_falsey }
      end
    end
  end
end

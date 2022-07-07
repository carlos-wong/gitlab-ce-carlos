# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Runners do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:group_guest) { create(:user) }
  let_it_be(:group_reporter) { create(:user) }
  let_it_be(:group_developer) { create(:user) }
  let_it_be(:group_maintainer) { create(:user) }

  let_it_be(:project) { create(:project, creator_id: user.id) }
  let_it_be(:project2) { create(:project, creator_id: user.id) }

  let_it_be(:group) { create(:group).tap { |group| group.add_owner(user) } }
  let_it_be(:subgroup) { create(:group, parent: group) }

  let_it_be(:shared_runner, reload: true) { create(:ci_runner, :instance, description: 'Shared runner') }
  let_it_be(:project_runner, reload: true) { create(:ci_runner, :project, description: 'Project runner', projects: [project]) }
  let_it_be(:two_projects_runner) { create(:ci_runner, :project, description: 'Two projects runner', projects: [project, project2]) }
  let_it_be(:group_runner_a) { create(:ci_runner, :group, description: 'Group runner A', groups: [group]) }
  let_it_be(:group_runner_b) { create(:ci_runner, :group, description: 'Group runner B', groups: [subgroup]) }

  before_all do
    group.add_guest(group_guest)
    group.add_reporter(group_reporter)
    group.add_developer(group_developer)
    group.add_maintainer(group_maintainer)
    project.add_maintainer(user)
    project2.add_maintainer(user)
    project.add_reporter(user2)
  end

  describe 'GET /runners' do
    context 'authorized user' do
      it 'returns response status and headers' do
        get api('/runners', user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
      end

      it 'returns user available runners' do
        get api('/runners', user)

        expect(json_response).to match_array [
          a_hash_including('description' => 'Project runner'),
          a_hash_including('description' => 'Two projects runner'),
          a_hash_including('description' => 'Group runner A'),
          a_hash_including('description' => 'Group runner B')
        ]
      end

      it 'filters runners by scope' do
        create(:ci_runner, :project, :inactive, description: 'Inactive project runner', projects: [project])

        get api('/runners?scope=paused', user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers

        expect(json_response).to match_array [
          a_hash_including('description' => 'Inactive project runner')
        ]
      end

      it 'avoids filtering if scope is invalid' do
        get api('/runners?scope=unknown', user)
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'filters runners by type' do
        get api('/runners?type=project_type', user)

        expect(json_response).to match_array [
          a_hash_including('description' => 'Project runner'),
          a_hash_including('description' => 'Two projects runner')
        ]
      end

      it 'does not filter by invalid type' do
        get api('/runners?type=bogus', user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'with an inactive runner' do
        let_it_be(:runner) { create(:ci_runner, :project, :inactive, description: 'Inactive project runner', projects: [project]) }

        it 'filters runners by paused state' do
          get api('/runners?paused=true', user)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Inactive project runner')
          ]
        end

        it 'filters runners by status' do
          get api('/runners?status=paused', user)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Inactive project runner')
          ]
        end
      end

      it 'does not filter by invalid status' do
        get api('/runners?status=bogus', user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'filters runners by tag_list' do
        create(:ci_runner, :project, description: 'Runner tagged with tag1 and tag2', projects: [project], tag_list: %w[tag1 tag2])
        create(:ci_runner, :project, description: 'Runner tagged with tag2', projects: [project], tag_list: ['tag2'])

        get api('/runners?tag_list=tag1,tag2', user)

        expect(json_response).to match_array [
          a_hash_including('description' => 'Runner tagged with tag1 and tag2', 'active' => true, 'paused' => false)
        ]
      end
    end

    context 'unauthorized user' do
      it 'does not return runners' do
        get api('/runners')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /runners/all' do
    context 'authorized user' do
      context 'with admin privileges' do
        it 'returns response status and headers' do
          get api('/runners/all', admin)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
        end

        it 'returns all runners' do
          get api('/runners/all', admin)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Project runner', 'is_shared' => false, 'active' => true, 'paused' => false, 'runner_type' => 'project_type'),
            a_hash_including('description' => 'Two projects runner', 'is_shared' => false, 'runner_type' => 'project_type'),
            a_hash_including('description' => 'Group runner A', 'is_shared' => false, 'runner_type' => 'group_type'),
            a_hash_including('description' => 'Group runner B', 'is_shared' => false, 'runner_type' => 'group_type'),
            a_hash_including('description' => 'Shared runner', 'is_shared' => true, 'runner_type' => 'instance_type')
          ]
        end

        it 'filters runners by scope' do
          get api('/runners/all?scope=shared', admin)

          shared = json_response.all? { |r| r['is_shared'] }
          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response[0]).to have_key('ip_address')
          expect(shared).to be_truthy
        end

        it 'filters runners by scope' do
          get api('/runners/all?scope=specific', admin)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers

          expect(json_response).to match_array [
            a_hash_including('description' => 'Project runner'),
            a_hash_including('description' => 'Two projects runner'),
            a_hash_including('description' => 'Group runner A'),
            a_hash_including('description' => 'Group runner B')
          ]
        end

        it 'avoids filtering if scope is invalid' do
          get api('/runners/all?scope=unknown', admin)
          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'filters runners by project type' do
          get api('/runners/all?type=project_type', admin)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Project runner'),
            a_hash_including('description' => 'Two projects runner')
          ]
        end

        it 'filters runners by group type' do
          get api('/runners/all?type=group_type', admin)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Group runner A'),
            a_hash_including('description' => 'Group runner B')
          ]
        end

        it 'does not filter by invalid type' do
          get api('/runners/all?type=bogus', admin)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        context 'with an inactive runner' do
          let_it_be(:runner) { create(:ci_runner, :project, :inactive, description: 'Inactive project runner', projects: [project]) }

          it 'filters runners by status' do
            get api('/runners/all?paused=true', admin)

            expect(json_response).to match_array [
              a_hash_including('description' => 'Inactive project runner')
            ]
          end

          it 'filters runners by status' do
            get api('/runners/all?status=paused', admin)

            expect(json_response).to match_array [
              a_hash_including('description' => 'Inactive project runner')
            ]
          end
        end

        it 'does not filter by invalid status' do
          get api('/runners/all?status=bogus', admin)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'filters runners by tag_list' do
          create(:ci_runner, :project, description: 'Runner tagged with tag1 and tag2', projects: [project], tag_list: %w[tag1 tag2])
          create(:ci_runner, :project, description: 'Runner tagged with tag2', projects: [project], tag_list: ['tag2'])

          get api('/runners/all?tag_list=tag1,tag2', admin)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Runner tagged with tag1 and tag2')
          ]
        end
      end

      context 'without admin privileges' do
        it 'does not return runners list' do
          get api('/runners/all', user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'unauthorized user' do
      it 'does not return runners' do
        get api('/runners')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /runners/:id' do
    context 'admin user' do
      context 'when runner is shared' do
        it "returns runner's details" do
          get api("/runners/#{shared_runner.id}", admin)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['description']).to eq(shared_runner.description)
          expect(json_response['maximum_timeout']).to be_nil
          expect(json_response['status']).to eq("not_connected")
          expect(json_response['active']).to eq(true)
          expect(json_response['paused']).to eq(false)
        end
      end

      context 'when runner is not shared' do
        context 'when unused runner is present' do
          let!(:unused_project_runner) { create(:ci_runner, :project, :without_projects) }

          it 'deletes unused runner' do
            expect do
              delete api("/runners/#{unused_project_runner.id}", admin)

              expect(response).to have_gitlab_http_status(:no_content)
            end.to change { ::Ci::Runner.project_type.count }.by(-1)
          end
        end

        it "returns runner's details" do
          get api("/runners/#{project_runner.id}", admin)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['description']).to eq(project_runner.description)
        end

        it "returns the project's details for a project runner" do
          get api("/runners/#{project_runner.id}", admin)

          expect(json_response['projects'].first['id']).to eq(project.id)
        end
      end

      it 'returns 404 if runner does not exist' do
        get api('/runners/0', admin)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the runner is a group runner' do
      it "returns the runner's details" do
        get api("/runners/#{group_runner_a.id}", admin)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['description']).to eq(group_runner_a.description)
        expect(json_response['groups'].first['id']).to eq(group.id)
      end
    end

    context "runner project's administrative user" do
      context 'when runner is not shared' do
        it "returns runner's details" do
          get api("/runners/#{project_runner.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['description']).to eq(project_runner.description)
        end
      end

      context 'when runner is shared' do
        it "returns runner's details" do
          get api("/runners/#{shared_runner.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['description']).to eq(shared_runner.description)
        end
      end
    end

    context 'other authorized user' do
      it "does not return project runner's details" do
        get api("/runners/#{project_runner.id}", user2)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthorized user' do
      it "does not return project runner's details" do
        get api("/runners/#{project_runner.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /runners/:id' do
    context 'admin user' do
      # see https://gitlab.com/gitlab-org/gitlab-foss/issues/48625
      context 'single parameter update' do
        it 'runner description' do
          description = shared_runner.description
          update_runner(shared_runner.id, admin, description: "#{description}_updated")

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.description).to eq("#{description}_updated")
        end

        it 'runner active state' do
          active = shared_runner.active
          update_runner(shared_runner.id, admin, active: !active)

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.active).to eq(!active)
        end

        it 'runner paused state' do
          active = shared_runner.active
          update_runner(shared_runner.id, admin, paused: active)

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.active).to eq(!active)
        end

        it 'runner tag list' do
          update_runner(shared_runner.id, admin, tag_list: ['ruby2.1', 'pgsql', 'mysql'])

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.tag_list).to include('ruby2.1', 'pgsql', 'mysql')
        end

        it 'unrelated runner attribute on an existing runner with too many tags' do
          # This test ensures that it is possible to update any attribute on a runner that currently fails the
          # validation that ensures that there aren't too many tags associated with a runner
          existing_invalid_shared_runner = build(:ci_runner, :instance, tag_list: (1..::Ci::Runner::TAG_LIST_MAX_LENGTH + 1).map { |i| "tag#{i}" } )
          existing_invalid_shared_runner.save!(validate: false)

          active = existing_invalid_shared_runner.active
          update_runner(existing_invalid_shared_runner.id, admin, paused: active)

          expect(response).to have_gitlab_http_status(:ok)
          expect(existing_invalid_shared_runner.reload.active).to eq(!active)
        end

        it 'runner untagged flag' do
          # Ensure tag list is non-empty before setting untagged to false.
          update_runner(shared_runner.id, admin, tag_list: ['ruby2.1', 'pgsql', 'mysql'])
          update_runner(shared_runner.id, admin, run_untagged: 'false')

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.run_untagged?).to be(false)
        end

        it 'runner unlocked flag' do
          update_runner(shared_runner.id, admin, locked: 'true')

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.locked?).to be(true)
        end

        it 'runner access level' do
          update_runner(shared_runner.id, admin, access_level: 'ref_protected')

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.ref_protected?).to be_truthy
        end

        it 'runner maximum timeout' do
          update_runner(shared_runner.id, admin, maximum_timeout: 1234)

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.reload.maximum_timeout).to eq(1234)
        end

        it 'fails with no parameters' do
          put api("/runners/#{shared_runner.id}", admin)

          shared_runner.reload
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when runner is shared' do
        it 'updates runner' do
          description = shared_runner.description
          active = shared_runner.active
          runner_queue_value = shared_runner.ensure_runner_queue_value

          update_runner(shared_runner.id, admin, description: "#{description}_updated",
                                                 active: !active,
                                                 tag_list: ['ruby2.1', 'pgsql', 'mysql'],
                                                 run_untagged: 'false',
                                                 locked: 'true',
                                                 access_level: 'ref_protected',
                                                 maximum_timeout: 1234)
          shared_runner.reload

          expect(response).to have_gitlab_http_status(:ok)
          expect(shared_runner.description).to eq("#{description}_updated")
          expect(shared_runner.active).to eq(!active)
          expect(shared_runner.tag_list).to include('ruby2.1', 'pgsql', 'mysql')
          expect(shared_runner.run_untagged?).to be(false)
          expect(shared_runner.locked?).to be(true)
          expect(shared_runner.ref_protected?).to be_truthy
          expect(shared_runner.ensure_runner_queue_value)
            .not_to eq(runner_queue_value)
          expect(shared_runner.maximum_timeout).to eq(1234)
        end
      end

      context 'when runner is not shared' do
        it 'updates runner' do
          description = project_runner.description
          runner_queue_value = project_runner.ensure_runner_queue_value

          update_runner(project_runner.id, admin, description: 'test')
          project_runner.reload

          expect(response).to have_gitlab_http_status(:ok)
          expect(project_runner.description).to eq('test')
          expect(project_runner.description).not_to eq(description)
          expect(project_runner.ensure_runner_queue_value)
            .not_to eq(runner_queue_value)
        end
      end

      it 'returns 404 if runner does not exist' do
        update_runner(0, admin, description: 'test')

        expect(response).to have_gitlab_http_status(:not_found)
      end

      def update_runner(id, user, args)
        put api("/runners/#{id}", user), params: args
      end
    end

    context 'authorized user' do
      context 'when runner is shared' do
        it 'does not update runner' do
          put api("/runners/#{shared_runner.id}", user), params: { description: 'test' }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when runner is not shared' do
        it 'does not update project runner without access to it' do
          put api("/runners/#{project_runner.id}", user2), params: { description: 'test' }

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'updates project runner with access to it' do
          description = project_runner.description
          put api("/runners/#{project_runner.id}", admin), params: { description: 'test' }
          project_runner.reload

          expect(response).to have_gitlab_http_status(:ok)
          expect(project_runner.description).to eq('test')
          expect(project_runner.description).not_to eq(description)
        end
      end
    end

    context 'unauthorized user' do
      it 'does not delete project runner' do
        put api("/runners/#{project_runner.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /runners/:id' do
    context 'admin user' do
      context 'when runner is shared' do
        it 'deletes runner' do
          expect_next_instance_of(Ci::Runners::UnregisterRunnerService, shared_runner, admin) do |service|
            expect(service).to receive(:execute).once.and_call_original
          end

          expect do
            delete api("/runners/#{shared_runner.id}", admin)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { ::Ci::Runner.instance_type.count }.by(-1)
        end

        it_behaves_like '412 response' do
          let(:request) { api("/runners/#{shared_runner.id}", admin) }
        end
      end

      context 'when runner is not shared' do
        it 'deletes used project runner' do
          expect_next_instance_of(Ci::Runners::UnregisterRunnerService, project_runner, admin) do |service|
            expect(service).to receive(:execute).once.and_call_original
          end

          expect do
            delete api("/runners/#{project_runner.id}", admin)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { ::Ci::Runner.project_type.count }.by(-1)
        end
      end

      it 'returns 404 if runner does not exist' do
        allow_next_instance_of(Ci::Runners::UnregisterRunnerService) do |service|
          expect(service).not_to receive(:execute)
        end

        delete api('/runners/0', admin)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'authorized user' do
      context 'when runner is shared' do
        it 'does not delete runner' do
          delete api("/runners/#{shared_runner.id}", user)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when runner is not shared' do
        it 'does not delete runner without access to it' do
          delete api("/runners/#{project_runner.id}", user2)
          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'does not delete project runner with more than one associated project' do
          delete api("/runners/#{two_projects_runner.id}", user)
          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'deletes project runner for one owned project' do
          expect do
            delete api("/runners/#{project_runner.id}", user)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { ::Ci::Runner.project_type.count }.by(-1)
        end

        it 'does not delete group runner with guest access' do
          delete api("/runners/#{group_runner_a.id}", group_guest)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'does not delete group runner with reporter access' do
          delete api("/runners/#{group_runner_a.id}", group_reporter)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'does not delete group runner with developer access' do
          delete api("/runners/#{group_runner_a.id}", group_developer)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'does not delete group runner with maintainer access' do
          delete api("/runners/#{group_runner_a.id}", group_maintainer)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'deletes owned group runner with owner access' do
          expect do
            delete api("/runners/#{group_runner_a.id}", user)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { ::Ci::Runner.group_type.count }.by(-1)
        end

        it 'deletes inherited group runner with owner access' do
          expect do
            delete api("/runners/#{group_runner_b.id}", user)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { ::Ci::Runner.group_type.count }.by(-1)
        end

        it_behaves_like '412 response' do
          let(:request) { api("/runners/#{project_runner.id}", user) }
        end
      end
    end

    context 'unauthorized user' do
      it 'does not delete project runner' do
        allow_next_instance_of(Ci::Runners::UnregisterRunnerService) do |service|
          expect(service).not_to receive(:execute)
        end

        delete api("/runners/#{project_runner.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /runners/:id/reset_authentication_token' do
    context 'admin user' do
      it 'resets shared runner authentication token' do
        expect do
          post api("/runners/#{shared_runner.id}/reset_authentication_token", admin)

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq({ 'token' => shared_runner.reload.token, 'token_expires_at' => nil })
        end.to change { shared_runner.reload.token }
      end

      it 'returns 404 if runner does not exist' do
        post api('/runners/0/reset_authentication_token', admin)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'authorized user' do
      it 'does not reset project runner authentication token without access to it' do
        expect do
          post api("/runners/#{project_runner.id}/reset_authentication_token", user2)
          expect(response).to have_gitlab_http_status(:forbidden)
        end.not_to change { project_runner.reload.token }
      end

      it 'resets project runner authentication token for owned project' do
        expect do
          post api("/runners/#{project_runner.id}/reset_authentication_token", user)

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq({ 'token' => project_runner.reload.token, 'token_expires_at' => nil })
        end.to change { project_runner.reload.token }
      end

      it 'does not reset group runner authentication token with guest access' do
        expect do
          post api("/runners/#{group_runner_a.id}/reset_authentication_token", group_guest)

          expect(response).to have_gitlab_http_status(:forbidden)
        end.not_to change { group_runner_a.reload.token }
      end

      it 'does not reset group runner authentication token with reporter access' do
        expect do
          post api("/runners/#{group_runner_a.id}/reset_authentication_token", group_reporter)

          expect(response).to have_gitlab_http_status(:forbidden)
        end.not_to change { group_runner_a.reload.token }
      end

      it 'does not reset group runner authentication token with developer access' do
        expect do
          post api("/runners/#{group_runner_a.id}/reset_authentication_token", group_developer)

          expect(response).to have_gitlab_http_status(:forbidden)
        end.not_to change { group_runner_a.reload.token }
      end

      it 'does not reset group runner authentication token with maintainer access' do
        expect do
          post api("/runners/#{group_runner_a.id}/reset_authentication_token", group_maintainer)

          expect(response).to have_gitlab_http_status(:forbidden)
        end.not_to change { group_runner_a.reload.token }
      end

      it 'resets group runner authentication token with owner access' do
        expect do
          post api("/runners/#{group_runner_a.id}/reset_authentication_token", user)

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq({ 'token' => group_runner_a.reload.token, 'token_expires_at' => nil })
        end.to change { group_runner_a.reload.token }
      end

      it 'resets group runner authentication token with owner access with expiration time', :freeze_time do
        expect(group_runner_a.reload.token_expires_at).to be_nil

        group.update!(runner_token_expiration_interval: 5.days)

        expect do
          post api("/runners/#{group_runner_a.id}/reset_authentication_token", user)
          group_runner_a.reload

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq({ 'token' => group_runner_a.token, 'token_expires_at' => group_runner_a.token_expires_at.iso8601(3) })
          expect(group_runner_a.token_expires_at).to eq(5.days.from_now)
        end.to change { group_runner_a.reload.token }
      end
    end

    context 'unauthorized user' do
      it 'does not reset authentication token' do
        expect do
          post api("/runners/#{shared_runner.id}/reset_authentication_token")

          expect(response).to have_gitlab_http_status(:unauthorized)
        end.not_to change { shared_runner.reload.token }
      end
    end
  end

  describe 'GET /runners/:id/jobs' do
    let_it_be(:job_1) { create(:ci_build) }
    let_it_be(:job_2) { create(:ci_build, :running, runner: shared_runner, project: project) }
    let_it_be(:job_3) { create(:ci_build, :failed, runner: shared_runner, project: project) }
    let_it_be(:job_4) { create(:ci_build, :running, runner: project_runner, project: project) }
    let_it_be(:job_5) { create(:ci_build, :failed, runner: project_runner, project: project) }

    context 'admin user' do
      context 'when runner exists' do
        context 'when runner is shared' do
          it 'return jobs' do
            get api("/runners/#{shared_runner.id}/jobs", admin)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to include_pagination_headers

            expect(json_response).to be_an(Array)
            expect(json_response.length).to eq(2)
          end
        end

        context 'when runner is specific' do
          it 'return jobs' do
            get api("/runners/#{project_runner.id}/jobs", admin)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to include_pagination_headers

            expect(json_response).to be_an(Array)
            expect(json_response.length).to eq(2)
          end

          context 'when user does not have authorization to see all jobs' do
            it 'shows only jobs it has permission to see' do
              create(:ci_build, :running, runner: two_projects_runner, project: project)
              create(:ci_build, :running, runner: two_projects_runner, project: project2)

              project.add_guest(user2)
              project2.add_maintainer(user2)
              get api("/runners/#{two_projects_runner.id}/jobs", user2)

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to include_pagination_headers

              expect(json_response).to be_an(Array)
              expect(json_response.length).to eq(1)
            end
          end
        end

        context 'when valid status is provided' do
          it 'return filtered jobs' do
            get api("/runners/#{project_runner.id}/jobs?status=failed", admin)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to include_pagination_headers

            expect(json_response).to be_an(Array)
            expect(json_response.length).to eq(1)
            expect(json_response.first).to include('id' => job_5.id)
          end
        end

        context 'when valid order_by is provided' do
          context 'when sort order is not specified' do
            it 'return jobs in descending order' do
              get api("/runners/#{project_runner.id}/jobs?order_by=id", admin)

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to include_pagination_headers

              expect(json_response).to be_an(Array)
              expect(json_response.length).to eq(2)
              expect(json_response.first).to include('id' => job_5.id)
            end
          end

          context 'when sort order is specified as asc' do
            it 'return jobs sorted in ascending order' do
              get api("/runners/#{project_runner.id}/jobs?order_by=id&sort=asc", admin)

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to include_pagination_headers

              expect(json_response).to be_an(Array)
              expect(json_response.length).to eq(2)
              expect(json_response.first).to include('id' => job_4.id)
            end
          end
        end

        context 'when invalid status is provided' do
          it 'return 400' do
            get api("/runners/#{project_runner.id}/jobs?status=non-existing", admin)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when invalid order_by is provided' do
          it 'return 400' do
            get api("/runners/#{project_runner.id}/jobs?order_by=non-existing", admin)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when invalid sort is provided' do
          it 'return 400' do
            get api("/runners/#{project_runner.id}/jobs?sort=non-existing", admin)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context "when runner doesn't exist" do
        it 'returns 404' do
          get api('/runners/0/jobs', admin)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context "runner project's administrative user" do
      context 'when runner exists' do
        context 'when runner is shared' do
          it 'returns 403' do
            get api("/runners/#{shared_runner.id}/jobs", user)

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when runner is specific' do
          it 'return jobs' do
            get api("/runners/#{project_runner.id}/jobs", user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to include_pagination_headers

            expect(json_response).to be_an(Array)
            expect(json_response.length).to eq(2)
          end
        end

        context 'when valid status is provided' do
          it 'return filtered jobs' do
            get api("/runners/#{project_runner.id}/jobs?status=failed", user)

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to include_pagination_headers

            expect(json_response).to be_an(Array)
            expect(json_response.length).to eq(1)
            expect(json_response.first).to include('id' => job_5.id)
          end
        end

        context 'when invalid status is provided' do
          it 'return 400' do
            get api("/runners/#{project_runner.id}/jobs?status=non-existing", user)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context "when runner doesn't exist" do
        it 'returns 404' do
          get api('/runners/0/jobs', user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'other authorized user' do
      it 'does not return jobs' do
        get api("/runners/#{project_runner.id}/jobs", user2)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthorized user' do
      it 'does not return jobs' do
        get api("/runners/#{project_runner.id}/jobs")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  shared_examples_for 'unauthorized access to runners list' do
    context 'authorized user without maintainer privileges' do
      it "does not return group's runners" do
        get api("/#{entity_type}/#{entity.id}/runners", user2)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthorized user' do
      it "does not return project's runners" do
        get api("/#{entity_type}/#{entity.id}/runners")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /projects/:id/runners' do
    context 'authorized user with maintainer privileges' do
      it 'returns response status and headers' do
        get api('/runners/all', admin)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
      end

      it 'returns all runners' do
        get api("/projects/#{project.id}/runners", user)

        expect(json_response).to match_array [
          a_hash_including('description' => 'Project runner', 'active' => true, 'paused' => false),
          a_hash_including('description' => 'Two projects runner', 'active' => true, 'paused' => false),
          a_hash_including('description' => 'Shared runner', 'active' => true, 'paused' => false)
        ]
      end

      it 'filters runners by scope' do
        get api("/projects/#{project.id}/runners?scope=specific", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers

        expect(json_response).to match_array [
          a_hash_including('description' => 'Project runner'),
          a_hash_including('description' => 'Two projects runner')
        ]
      end

      it 'avoids filtering if scope is invalid' do
        get api("/projects/#{project.id}/runners?scope=unknown", user)
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'filters runners by type' do
        get api("/projects/#{project.id}/runners?type=project_type", user)

        expect(json_response).to match_array [
          a_hash_including('description' => 'Project runner'),
          a_hash_including('description' => 'Two projects runner')
        ]
      end

      it 'does not filter by invalid type' do
        get api("/projects/#{project.id}/runners?type=bogus", user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'with an inactive runner' do
        let_it_be(:runner) { create(:ci_runner, :project, :inactive, description: 'Inactive project runner', projects: [project]) }

        it 'filters runners by status' do
          get api("/projects/#{project.id}/runners?paused=true", user)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Inactive project runner')
          ]
        end

        it 'filters runners by status' do
          get api("/projects/#{project.id}/runners?status=paused", user)

          expect(json_response).to match_array [
            a_hash_including('description' => 'Inactive project runner')
          ]
        end
      end

      it 'does not filter by invalid status' do
        get api("/projects/#{project.id}/runners?status=bogus", user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'filters runners by tag_list' do
        create(:ci_runner, :project, description: 'Runner tagged with tag1 and tag2', projects: [project], tag_list: %w[tag1 tag2])
        create(:ci_runner, :project, description: 'Runner tagged with tag2', projects: [project], tag_list: ['tag2'])

        get api("/projects/#{project.id}/runners?tag_list=tag1,tag2", user)

        expect(json_response).to match_array [
          a_hash_including('description' => 'Runner tagged with tag1 and tag2')
        ]
      end
    end

    it_behaves_like 'unauthorized access to runners list' do
      let(:entity_type) { 'projects' }
      let(:entity) { project }
    end
  end

  describe 'GET /groups/:id/runners' do
    context 'authorized user with maintainer privileges' do
      it 'returns all runners' do
        get api("/groups/#{group.id}/runners", user)

        expect(json_response).to match_array([
          a_hash_including('description' => 'Group runner A', 'active' => true, 'paused' => false),
          a_hash_including('description' => 'Shared runner', 'active' => true, 'paused' => false)
        ])
      end

      context 'filter by type' do
        it 'returns record when valid and present' do
          get api("/groups/#{group.id}/runners?type=group_type", user)

          expect(json_response).to match_array([
            a_hash_including('description' => 'Group runner A')
          ])
        end

        it 'returns instance runners when instance_type is specified' do
          get api("/groups/#{group.id}/runners?type=instance_type", user)

          expect(json_response).to match_array([
            a_hash_including('description' => 'Shared runner')
          ])
        end

        # TODO: Remove in %15.0 (https://gitlab.com/gitlab-org/gitlab/-/issues/351466)
        it 'returns empty result when type does not match' do
          get api("/groups/#{group.id}/runners?type=project_type", user)

          expect(json_response).to be_empty
        end

        it 'does not filter by invalid type' do
          get api("/groups/#{group.id}/runners?type=bogus", user)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with an inactive runner' do
        let_it_be(:runner) { create(:ci_runner, :group, :inactive, description: 'Inactive group runner', groups: [group]) }

        it 'returns runners by paused state' do
          get api("/groups/#{group.id}/runners?paused=true", user)

          expect(json_response).to match_array([
            a_hash_including('description' => 'Inactive group runner')
          ])
        end

        context 'filter runners by status' do
          it 'returns runners by valid status' do
            get api("/groups/#{group.id}/runners?status=paused", user)

            expect(json_response).to match_array([
              a_hash_including('description' => 'Inactive group runner')
            ])
          end

          it 'does not filter by invalid status' do
            get api("/groups/#{group.id}/runners?status=bogus", user)

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      it 'filters runners by tag_list' do
        create(:ci_runner, :group, description: 'Runner tagged with tag1 and tag2', groups: [group], tag_list: %w[tag1 tag2])
        create(:ci_runner, :group, description: 'Runner tagged with tag2', groups: [group], tag_list: %w[tag1])

        get api("/groups/#{group.id}/runners?tag_list=tag1,tag2", user)

        expect(json_response).to match_array([
          a_hash_including('description' => 'Runner tagged with tag1 and tag2')
        ])
      end
    end

    it_behaves_like 'unauthorized access to runners list' do
      let(:entity_type) { 'groups' }
      let(:entity) { group }
    end
  end

  describe 'POST /projects/:id/runners' do
    context 'authorized user' do
      let_it_be(:project_runner2) { create(:ci_runner, :project, projects: [project2]) }

      it 'enables specific runner' do
        expect do
          post api("/projects/#{project.id}/runners", user), params: { runner_id: project_runner2.id }
        end.to change { project.runners.count }.by(+1)
        expect(response).to have_gitlab_http_status(:created)
      end

      it 'avoids changes when enabling already enabled runner' do
        expect do
          post api("/projects/#{project.id}/runners", user), params: { runner_id: project_runner.id }
        end.to change { project.runners.count }.by(0)
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'does not enable locked runner' do
        project_runner2.update!(locked: true)

        expect do
          post api("/projects/#{project.id}/runners", user), params: { runner_id: project_runner2.id }
        end.to change { project.runners.count }.by(0)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'does not enable shared runner' do
        post api("/projects/#{project.id}/runners", user), params: { runner_id: shared_runner.id }

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'does not enable group runner' do
        post api("/projects/#{project.id}/runners", user), params: { runner_id: group_runner_a.id }

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'user is admin' do
        context 'when project runner is used' do
          let!(:new_project_runner) { create(:ci_runner, :project) }

          it 'enables any specific runner' do
            expect do
              post api("/projects/#{project.id}/runners", admin), params: { runner_id: new_project_runner.id }
            end.to change { project.runners.count }.by(+1)
            expect(response).to have_gitlab_http_status(:created)
          end

          context 'when it exceeds the application limits' do
            before do
              create(:plan_limits, :default_plan, ci_registered_project_runners: 1)
            end

            it 'does not enable specific runner' do
              expect do
                post api("/projects/#{project.id}/runners", admin), params: { runner_id: new_project_runner.id }
              end.not_to change { project.runners.count }
              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end

        it 'enables a instance type runner' do
          expect do
            post api("/projects/#{project.id}/runners", admin), params: { runner_id: shared_runner.id }
          end.to change { project.runners.count }.by(1)

          expect(shared_runner.reload).not_to be_instance_type
          expect(response).to have_gitlab_http_status(:created)
        end
      end

      it 'raises an error when no runner_id param is provided' do
        post api("/projects/#{project.id}/runners", admin)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'user is not admin' do
      let!(:new_project_runner) { create(:ci_runner, :project) }

      it 'does not enable runner without access to' do
        post api("/projects/#{project.id}/runners", user), params: { runner_id: new_project_runner.id }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'authorized user without permissions' do
      it 'does not enable runner' do
        post api("/projects/#{project.id}/runners", user2)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthorized user' do
      it 'does not enable runner' do
        post api("/projects/#{project.id}/runners")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /projects/:id/runners/:runner_id' do
    context 'authorized user' do
      context 'when runner have more than one associated projects' do
        it "disables project's runner" do
          expect do
            delete api("/projects/#{project.id}/runners/#{two_projects_runner.id}", user)

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { project.runners.count }.by(-1)
        end

        it_behaves_like '412 response' do
          let(:request) { api("/projects/#{project.id}/runners/#{two_projects_runner.id}", user) }
        end
      end

      context 'when runner have one associated projects' do
        it "does not disable project's runner" do
          expect do
            delete api("/projects/#{project.id}/runners/#{project_runner.id}", user)
          end.to change { project.runners.count }.by(0)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      it 'returns 404 is runner is not found' do
        delete api("/projects/#{project.id}/runners/0", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'authorized user without permissions' do
      it "does not disable project's runner" do
        delete api("/projects/#{project.id}/runners/#{project_runner.id}", user2)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthorized user' do
      it "does not disable project's runner" do
        delete api("/projects/#{project.id}/runners/#{project_runner.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end
end

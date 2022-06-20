# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.runner(id)' do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, :admin) }
  let_it_be(:group) { create(:group) }

  let_it_be(:active_instance_runner) do
    create(:ci_runner, :instance, description: 'Runner 1', contacted_at: 2.hours.ago,
           active: true, version: 'adfe156', revision: 'a', locked: true, ip_address: '127.0.0.1', maximum_timeout: 600,
           access_level: 0, tag_list: %w[tag1 tag2], run_untagged: true, executor_type: :custom)
  end

  let_it_be(:inactive_instance_runner) do
    create(:ci_runner, :instance, description: 'Runner 2', contacted_at: 1.day.ago, active: false,
           version: 'adfe157', revision: 'b', ip_address: '10.10.10.10', access_level: 1, run_untagged: true)
  end

  let_it_be(:active_group_runner) do
    create(:ci_runner, :group, groups: [group], description: 'Group runner 1', contacted_at: 2.hours.ago,
           active: true, version: 'adfe156', revision: 'a', locked: true, ip_address: '127.0.0.1', maximum_timeout: 600,
           access_level: 0, tag_list: %w[tag1 tag2], run_untagged: true, executor_type: :shell)
  end

  let_it_be(:active_project_runner) { create(:ci_runner, :project) }

  before do
    allow(Gitlab::Ci::RunnerUpgradeCheck.instance).to receive(:check_runner_upgrade_status)
  end

  shared_examples 'runner details fetch' do
    let(:query) do
      wrap_fields(query_graphql_path(query_path, all_graphql_fields_for('CiRunner')))
    end

    let(:query_path) do
      [
        [:runner, { id: runner.to_global_id.to_s }]
      ]
    end

    it 'retrieves expected fields' do
      post_graphql(query, current_user: user)

      runner_data = graphql_data_at(:runner)
      expect(runner_data).not_to be_nil

      expect(runner_data).to match a_hash_including(
        'id' => runner.to_global_id.to_s,
        'description' => runner.description,
        'createdAt' => runner.created_at&.iso8601,
        'contactedAt' => runner.contacted_at&.iso8601,
        'version' => runner.version,
        'shortSha' => runner.short_sha,
        'revision' => runner.revision,
        'locked' => false,
        'active' => runner.active,
        'paused' => !runner.active,
        'status' => runner.status('14.5').to_s.upcase,
        'maximumTimeout' => runner.maximum_timeout,
        'accessLevel' => runner.access_level.to_s.upcase,
        'runUntagged' => runner.run_untagged,
        'ipAddress' => runner.ip_address,
        'runnerType' => runner.instance_type? ? 'INSTANCE_TYPE' : 'PROJECT_TYPE',
        'executorName' => runner.executor_type&.dasherize,
        'jobCount' => 0,
        'jobs' => a_hash_including("count" => 0, "nodes" => [], "pageInfo" => anything),
        'projectCount' => nil,
        'adminUrl' => "http://localhost/admin/runners/#{runner.id}",
        'userPermissions' => {
          'readRunner' => true,
          'updateRunner' => true,
          'deleteRunner' => true
        }
      )
      expect(runner_data['tagList']).to match_array runner.tag_list
    end
  end

  shared_examples 'retrieval with no admin url' do
    let(:query) do
      wrap_fields(query_graphql_path(query_path, all_graphql_fields_for('CiRunner')))
    end

    let(:query_path) do
      [
        [:runner, { id: runner.to_global_id.to_s }]
      ]
    end

    it 'retrieves expected fields' do
      post_graphql(query, current_user: user)

      runner_data = graphql_data_at(:runner)
      expect(runner_data).not_to be_nil

      expect(runner_data).to match a_hash_including(
        'id' => runner.to_global_id.to_s,
        'adminUrl' => nil
      )
      expect(runner_data['tagList']).to match_array runner.tag_list
    end
  end

  shared_examples 'retrieval by unauthorized user' do
    let(:query) do
      wrap_fields(query_graphql_path(query_path, all_graphql_fields_for('CiRunner')))
    end

    let(:query_path) do
      [
        [:runner, { id: runner.to_global_id.to_s }]
      ]
    end

    it 'returns null runner' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:runner)).to be_nil
    end
  end

  describe 'for active runner' do
    let(:runner) { active_instance_runner }

    it_behaves_like 'runner details fetch'

    context 'when tagList is not requested' do
      let(:query) do
        wrap_fields(query_graphql_path(query_path, 'id'))
      end

      let(:query_path) do
        [
          [:runner, { id: runner.to_global_id.to_s }]
        ]
      end

      it 'does not retrieve tagList' do
        post_graphql(query, current_user: user)

        runner_data = graphql_data_at(:runner)
        expect(runner_data).not_to be_nil
        expect(runner_data).not_to include('tagList')
      end
    end
  end

  describe 'for project runner' do
    using RSpec::Parameterized::TableSyntax

    where(is_locked: [true, false])

    with_them do
      let(:project_runner) do
        create(:ci_runner, :project, description: 'Runner 3', contacted_at: 1.day.ago, active: false, locked: is_locked,
               version: 'adfe157', revision: 'b', ip_address: '10.10.10.10', access_level: 1, run_untagged: true)
      end

      let(:query) do
        wrap_fields(query_graphql_path(query_path, all_graphql_fields_for('CiRunner')))
      end

      let(:query_path) do
        [
          [:runner, { id: project_runner.to_global_id.to_s }]
        ]
      end

      it 'retrieves correct locked value' do
        post_graphql(query, current_user: user)

        runner_data = graphql_data_at(:runner)

        expect(runner_data).to match a_hash_including(
          'id' => project_runner.to_global_id.to_s,
          'locked' => is_locked
        )
      end
    end
  end

  describe 'for inactive runner' do
    let(:runner) { inactive_instance_runner }

    it_behaves_like 'runner details fetch'
  end

  describe 'for group runner request' do
    let(:query) do
      %(
        query {
          runner(id: "#{active_group_runner.to_global_id}") {
            groups {
              nodes {
                id
              }
            }
          }
        }
      )
    end

    it 'retrieves groups field with expected value' do
      post_graphql(query, current_user: user)

      runner_data = graphql_data_at(:runner, :groups)
      expect(runner_data).to eq 'nodes' => [{ 'id' => group.to_global_id.to_s }]
    end
  end

  describe 'for runner with status' do
    let_it_be(:stale_runner) { create(:ci_runner, description: 'Stale runner 1', created_at: 3.months.ago) }
    let_it_be(:never_contacted_instance_runner) { create(:ci_runner, description: 'Missing runner 1', created_at: 1.month.ago, contacted_at: nil) }

    let(:status_fragment) do
      %(
        status
        legacyStatusWithExplicitVersion: status(legacyMode: "14.5")
        newStatus: status(legacyMode: null)
      )
    end

    let(:query) do
      %(
        query {
          staleRunner: runner(id: "#{stale_runner.to_global_id}") { #{status_fragment} }
          pausedRunner: runner(id: "#{inactive_instance_runner.to_global_id}") { #{status_fragment} }
          neverContactedInstanceRunner: runner(id: "#{never_contacted_instance_runner.to_global_id}") { #{status_fragment} }
        }
      )
    end

    it 'retrieves status fields with expected values' do
      post_graphql(query, current_user: user)

      stale_runner_data = graphql_data_at(:stale_runner)
      expect(stale_runner_data).to match a_hash_including(
        'status' => 'NOT_CONNECTED',
        'legacyStatusWithExplicitVersion' => 'NOT_CONNECTED',
        'newStatus' => 'STALE'
      )

      paused_runner_data = graphql_data_at(:paused_runner)
      expect(paused_runner_data).to match a_hash_including(
        'status' => 'PAUSED',
        'legacyStatusWithExplicitVersion' => 'PAUSED',
        'newStatus' => 'OFFLINE'
      )

      never_contacted_instance_runner_data = graphql_data_at(:never_contacted_instance_runner)
      expect(never_contacted_instance_runner_data).to match a_hash_including(
        'status' => 'NOT_CONNECTED',
        'legacyStatusWithExplicitVersion' => 'NOT_CONNECTED',
        'newStatus' => 'NEVER_CONTACTED'
      )
    end
  end

  describe 'for multiple runners' do
    let_it_be(:project1) { create(:project, :test_repo) }
    let_it_be(:project2) { create(:project, :test_repo) }
    let_it_be(:project_runner1) { create(:ci_runner, :project, projects: [project1, project2], description: 'Runner 1') }
    let_it_be(:project_runner2) { create(:ci_runner, :project, projects: [], description: 'Runner 2') }

    let!(:job) { create(:ci_build, runner: project_runner1) }

    context 'requesting projects and counts for projects and jobs' do
      let(:jobs_fragment) do
        %(
          jobs {
            count
            nodes {
              id
              status
            }
          }
        )
      end

      let(:query) do
        %(
          query {
            projectRunner1: runner(id: "#{project_runner1.to_global_id}") {
              projectCount
              jobCount
              #{jobs_fragment}
              projects {
                nodes {
                  id
                }
              }
            }
            projectRunner2: runner(id: "#{project_runner2.to_global_id}") {
              projectCount
              jobCount
              #{jobs_fragment}
              projects {
                nodes {
                  id
                }
              }
            }
            activeInstanceRunner: runner(id: "#{active_instance_runner.to_global_id}") {
              projectCount
              jobCount
              #{jobs_fragment}
              projects {
                nodes {
                  id
                }
              }
            }
          }
        )
      end

      before do
        project_runner2.runner_projects.clear

        post_graphql(query, current_user: user)
      end

      it 'retrieves expected fields' do
        runner1_data = graphql_data_at(:project_runner1)
        runner2_data = graphql_data_at(:project_runner2)
        runner3_data = graphql_data_at(:active_instance_runner)

        expect(runner1_data).to match a_hash_including(
          'jobCount' => 1,
          'jobs' => a_hash_including(
            "count" => 1,
            "nodes" => [{ "id" => job.to_global_id.to_s, "status" => job.status.upcase }]
          ),
          'projectCount' => 2,
          'projects' => {
            'nodes' => [
              { 'id' => project1.to_global_id.to_s },
              { 'id' => project2.to_global_id.to_s }
            ]
          })
        expect(runner2_data).to match a_hash_including(
          'jobCount' => 0,
          'jobs' => nil, # returning jobs not allowed for more than 1 runner (see RunnerJobsResolver)
          'projectCount' => 0,
          'projects' => {
            'nodes' => []
          })
        expect(runner3_data).to match a_hash_including(
          'jobCount' => 0,
          'jobs' => nil, # returning jobs not allowed for more than 1 runner (see RunnerJobsResolver)
          'projectCount' => nil,
          'projects' => nil)
      end
    end
  end

  describe 'by regular user' do
    let(:user) { create(:user) }

    context 'on instance runner' do
      let(:runner) { active_instance_runner }

      it_behaves_like 'retrieval by unauthorized user'
    end

    context 'on group runner' do
      let(:runner) { active_group_runner }

      it_behaves_like 'retrieval by unauthorized user'
    end

    context 'on project runner' do
      let(:runner) { active_project_runner }

      it_behaves_like 'retrieval by unauthorized user'
    end
  end

  describe 'by non-admin user' do
    let(:user) { create(:user) }

    before do
      group.add_user(user, Gitlab::Access::OWNER)
    end

    it_behaves_like 'retrieval with no admin url' do
      let(:runner) { active_group_runner }
    end
  end

  describe 'by unauthenticated user' do
    let(:user) { nil }

    it_behaves_like 'retrieval by unauthorized user' do
      let(:runner) { active_instance_runner }
    end
  end

  describe 'Query limits' do
    def runner_query(runner)
      <<~SINGLE
        runner(id: "#{runner.to_global_id}") {
          #{all_graphql_fields_for('CiRunner', excluded: excluded_fields)}
        }
      SINGLE
    end

    # Currently excluding a known N+1 issue, see https://gitlab.com/gitlab-org/gitlab/-/issues/334759
    let(:excluded_fields) { %w[jobCount] }

    let(:single_query) do
      <<~QUERY
        {
          active: #{runner_query(active_instance_runner)}
        }
      QUERY
    end

    let(:double_query) do
      <<~QUERY
        {
          active: #{runner_query(active_instance_runner)}
          inactive: #{runner_query(inactive_instance_runner)}
        }
      QUERY
    end

    it 'does not execute more queries per runner', :aggregate_failures do
      # warm-up license cache and so on:
      post_graphql(single_query, current_user: user)

      control = ActiveRecord::QueryRecorder.new { post_graphql(single_query, current_user: user) }

      expect { post_graphql(double_query, current_user: user) }
        .not_to exceed_query_limit(control)
      expect(graphql_data_at(:active)).not_to be_nil
      expect(graphql_data_at(:inactive)).not_to be_nil
    end
  end
end

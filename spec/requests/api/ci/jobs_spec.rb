# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Jobs do
  include HttpBasicAuthHelpers
  include DependencyProxyHelpers

  using RSpec::Parameterized::TableSyntax
  include HttpIOHelpers

  let_it_be(:project, reload: true) do
    create(:project, :repository, public_builds: false)
  end

  let_it_be(:pipeline, reload: true) do
    create(:ci_pipeline, project: project,
                         sha: project.commit.id,
                         ref: project.default_branch)
  end

  let(:user) { create(:user) }
  let(:api_user) { user }
  let(:reporter) { create(:project_member, :reporter, project: project).user }
  let(:guest) { create(:project_member, :guest, project: project).user }

  let(:running_job) do
    create(:ci_build, :running, project: project,
                                user: user,
                                pipeline: pipeline,
                                artifacts_expire_at: 1.day.since)
  end

  let!(:job) do
    create(:ci_build, :success, :tags, pipeline: pipeline,
                                artifacts_expire_at: 1.day.since)
  end

  before do
    project.add_developer(user)
  end

  shared_examples 'returns common pipeline data' do
    it 'returns common pipeline data' do
      expect(json_response['pipeline']).not_to be_empty
      expect(json_response['pipeline']['id']).to eq jobx.pipeline.id
      expect(json_response['pipeline']['project_id']).to eq jobx.pipeline.project_id
      expect(json_response['pipeline']['ref']).to eq jobx.pipeline.ref
      expect(json_response['pipeline']['sha']).to eq jobx.pipeline.sha
      expect(json_response['pipeline']['status']).to eq jobx.pipeline.status
    end
  end

  shared_examples 'returns common job data' do
    it 'returns common job data' do
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(jobx.id)
      expect(json_response['status']).to eq(jobx.status)
      expect(json_response['stage']).to eq(jobx.stage)
      expect(json_response['name']).to eq(jobx.name)
      expect(json_response['ref']).to eq(jobx.ref)
      expect(json_response['tag']).to eq(jobx.tag)
      expect(json_response['coverage']).to eq(jobx.coverage)
      expect(json_response['allow_failure']).to eq(jobx.allow_failure)
      expect(Time.parse(json_response['created_at'])).to be_like_time(jobx.created_at)
      expect(Time.parse(json_response['started_at'])).to be_like_time(jobx.started_at)
      expect(Time.parse(json_response['artifacts_expire_at'])).to be_like_time(jobx.artifacts_expire_at)
      expect(json_response['artifacts_file']).to be_nil
      expect(json_response['artifacts']).to be_an Array
      expect(json_response['artifacts']).to be_empty
      expect(json_response['web_url']).to be_present
    end
  end

  shared_examples 'returns unauthorized' do
    it 'returns unauthorized' do
      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  describe 'GET /job' do
    shared_context 'with auth headers' do
      let(:headers_with_token) { header }
      let(:params_with_token) { {} }
    end

    shared_context 'with auth params' do
      let(:headers_with_token) { {} }
      let(:params_with_token) { param }
    end

    shared_context 'without auth' do
      let(:headers_with_token) { {} }
      let(:params_with_token) { {} }
    end

    before do |example|
      unless example.metadata[:skip_before_request]
        get api('/job'), headers: headers_with_token, params: params_with_token
      end
    end

    context 'when token is valid but not CI_JOB_TOKEN' do
      let(:token) { create(:personal_access_token, user: user) }

      include_context 'with auth headers' do
        let(:header) { { 'Private-Token' => token.token } }
      end

      it 'returns not found' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with job token authentication header' do
      include_context 'with auth headers' do
        let(:header) { { API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => running_job.token } }
      end

      it_behaves_like 'returns common job data' do
        let(:jobx) { running_job }
      end

      it 'returns specific job data' do
        expect(json_response['finished_at']).to be_nil
      end

      it_behaves_like 'returns common pipeline data' do
        let(:jobx) { running_job }
      end
    end

    context 'with job token authentication params' do
      include_context 'with auth params' do
        let(:param) { { job_token: running_job.token } }
      end

      it_behaves_like 'returns common job data' do
        let(:jobx) { running_job }
      end

      it 'returns specific job data' do
        expect(json_response['finished_at']).to be_nil
      end

      it_behaves_like 'returns common pipeline data' do
        let(:jobx) { running_job }
      end
    end

    context 'with non running job' do
      include_context 'with auth headers' do
        let(:header) { { API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => job.token } }
      end

      it_behaves_like 'returns unauthorized'
    end

    context 'with basic auth header' do
      let(:personal_access_token) { create(:personal_access_token, user: user) }
      let(:token) { personal_access_token.token}

      include_context 'with auth headers' do
        let(:header) { { Gitlab::Auth::AuthFinders::PRIVATE_TOKEN_HEADER => token } }
      end

      it 'does not return a job' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'without authentication' do
      include_context 'without auth'

      it_behaves_like 'returns unauthorized'
    end
  end

  describe 'GET /job/allowed_agents' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_agent) { create(:cluster_agent, project: create(:project, group: group)) }
    let_it_be(:group_authorization) { create(:agent_group_authorization, agent: group_agent, group: group) }
    let_it_be(:project_agent) { create(:cluster_agent, project: project) }

    before(:all) do
      project.update!(group: group_authorization.group)
    end

    let(:implicit_authorization) { Clusters::Agents::ImplicitAuthorization.new(agent: project_agent) }

    let(:headers) { { API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => job.token } }
    let(:job) { create(:ci_build, :artifacts, pipeline: pipeline, user: api_user, status: job_status) }
    let(:job_status) { 'running' }
    let(:params) { {} }

    subject do
      get api('/job/allowed_agents'), headers: headers, params: params
    end

    before do
      subject
    end

    context 'when token is valid and user is authorized' do
      shared_examples_for 'valid allowed_agents request' do
        it 'returns agent info', :aggregate_failures do
          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response.dig('job', 'id')).to eq(job.id)
          expect(json_response.dig('pipeline', 'id')).to eq(job.pipeline_id)
          expect(json_response.dig('project', 'id')).to eq(job.project_id)
          expect(json_response.dig('project', 'groups')).to match_array([{ 'id' => group_authorization.group.id }])
          expect(json_response.dig('user', 'id')).to eq(api_user.id)
          expect(json_response.dig('user', 'username')).to eq(api_user.username)
          expect(json_response.dig('user', 'roles_in_project')).to match_array %w(guest reporter developer)
          expect(json_response).not_to include('environment')
          expect(json_response['allowed_agents']).to match_array([
            {
              'id' => implicit_authorization.agent_id,
              'config_project' => hash_including('id' => implicit_authorization.agent.project_id),
              'configuration' => implicit_authorization.config
            },
            {
              'id' => group_authorization.agent_id,
              'config_project' => hash_including('id' => group_authorization.agent.project_id),
              'configuration' => group_authorization.config
            }
          ])
        end
      end

      it_behaves_like 'valid allowed_agents request'

      context 'when deployment' do
        let(:job) { create(:ci_build, :artifacts, :with_deployment, environment: 'production', pipeline: pipeline, user: api_user, status: job_status) }

        it 'includes environment slug' do
          expect(json_response.dig('environment', 'slug')).to eq('production')
        end
      end

      context 'when passing the token as params' do
        let(:headers) { {} }
        let(:params) { { job_token: job.token } }

        it_behaves_like 'valid allowed_agents request'
      end
    end

    context 'when user is anonymous' do
      let(:api_user) { nil }

      it 'returns unauthorized' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when token is invalid because job has finished' do
      let(:job_status) { 'success' }

      it 'returns unauthorized' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when token is invalid' do
      let(:headers) { { API::Ci::Helpers::Runner::JOB_TOKEN_HEADER => 'bad_token' } }

      it 'returns unauthorized' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when token is valid but not CI_JOB_TOKEN' do
      let(:token) { create(:personal_access_token, user: user) }
      let(:headers) { { 'Private-Token' => token.token } }

      it 'returns not found' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /projects/:id/jobs' do
    let(:query) { {} }

    before do |example|
      unless example.metadata[:skip_before_request]
        get api("/projects/#{project.id}/jobs", api_user), params: query
      end
    end

    context 'authorized user' do
      it 'returns project jobs' do
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
      end

      it 'returns correct values' do
        expect(json_response).not_to be_empty
        expect(json_response.first['commit']['id']).to eq project.commit.id
        expect(Time.parse(json_response.first['artifacts_expire_at'])).to be_like_time(job.artifacts_expire_at)
        expect(json_response.first['tag_list'].sort).to eq job.tag_list.sort
      end

      context 'without artifacts and trace' do
        it 'returns no artifacts nor trace data' do
          json_job = json_response.first

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_job['artifacts_file']).to be_nil
          expect(json_job['artifacts']).to be_an Array
          expect(json_job['artifacts']).to be_empty
        end
      end

      it_behaves_like 'a job with artifacts and trace' do
        let(:api_endpoint) { "/projects/#{project.id}/jobs" }
      end

      it 'returns pipeline data' do
        json_job = json_response.first

        expect(json_job['pipeline']).not_to be_empty
        expect(json_job['pipeline']['id']).to eq job.pipeline.id
        expect(json_job['pipeline']['ref']).to eq job.pipeline.ref
        expect(json_job['pipeline']['sha']).to eq job.pipeline.sha
        expect(json_job['pipeline']['status']).to eq job.pipeline.status
      end

      it 'avoids N+1 queries', :skip_before_request do
        first_build = create(:ci_build, :trace_artifact, :artifacts, :test_reports, pipeline: pipeline)
        first_build.runner = create(:ci_runner)
        first_build.user = create(:user)
        first_build.save!

        control_count = ActiveRecord::QueryRecorder.new { go }.count

        second_pipeline = create(:ci_empty_pipeline, project: project, sha: project.commit.id, ref: project.default_branch)
        second_build = create(:ci_build, :trace_artifact, :artifacts, :test_reports, pipeline: second_pipeline)
        second_build.runner = create(:ci_runner)
        second_build.user = create(:user)
        second_build.save!

        expect { go }.not_to exceed_query_limit(control_count)
      end

      context 'filter project with one scope element' do
        let(:query) { { 'scope' => 'pending' } }

        it do
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
        end
      end

      context 'filter project with array of scope elements' do
        let(:query) { { scope: %w(pending running) } }

        it do
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
        end
      end

      context 'respond 400 when scope contains invalid state' do
        let(:query) { { scope: %w(unknown running) } }

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end
    end

    context 'unauthorized user' do
      context 'when user is not logged in' do
        let(:api_user) { nil }

        it 'does not return project jobs' do
          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when user is guest' do
        let(:api_user) { guest }

        it 'does not return project jobs' do
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    def go
      get api("/projects/#{project.id}/jobs", api_user), params: query
    end
  end

  describe 'GET /projects/:id/jobs/:job_id' do
    before do |example|
      unless example.metadata[:skip_before_request]
        get api("/projects/#{project.id}/jobs/#{job.id}", api_user)
      end
    end

    context 'authorized user' do
      it_behaves_like 'returns common job data' do
        let(:jobx) { job }
      end

      it 'returns specific job data' do
        expect(Time.parse(json_response['finished_at'])).to be_like_time(job.finished_at)
        expect(json_response['duration']).to eq(job.duration)
      end

      it_behaves_like 'a job with artifacts and trace', result_is_array: false do
        let(:api_endpoint) { "/projects/#{project.id}/jobs/#{second_job.id}" }
      end

      it_behaves_like 'returns common pipeline data' do
        let(:jobx) { job }
      end
    end

    context 'unauthorized user' do
      let(:api_user) { nil }

      it 'does not return specific job data' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when job succeeded' do
      it 'does not return failure_reason' do
        get api("/projects/#{project.id}/jobs/#{job.id}", api_user)

        expect(json_response).not_to include('failure_reason')
      end
    end

    context 'when job failed' do
      let(:job) do
        create(:ci_build, :failed, :tags, pipeline: pipeline)
      end

      it 'returns failure_reason' do
        get api("/projects/#{project.id}/jobs/#{job.id}", api_user)

        expect(json_response).to include('failure_reason')
      end
    end

    context 'when trace artifact record exists with no stored file', :skip_before_request do
      before do
        create(:ci_job_artifact, :unarchived_trace_artifact, job: job, project: job.project)
      end

      it 'returns no artifacts nor trace data' do
        get api("/projects/#{project.id}/jobs/#{job.id}", api_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['artifacts']).to be_an Array
        expect(json_response['artifacts'].size).to eq(1)
        expect(json_response['artifacts'][0]['file_type']).to eq('trace')
        expect(json_response['artifacts'][0]['filename']).to eq('job.log')
      end
    end
  end

  describe 'GET /projects/:id/jobs/:job_id/trace' do
    before do
      get api("/projects/#{project.id}/jobs/#{job.id}/trace", api_user)
    end

    context 'authorized user' do
      context 'when trace is in ObjectStorage' do
        let!(:job) { create(:ci_build, :trace_artifact, pipeline: pipeline) }
        let(:url) { 'http://object-storage/trace' }
        let(:file_path) { expand_fixture_path('trace/sample_trace') }

        before do
          stub_remote_url_206(url, file_path)
          allow_next_instance_of(JobArtifactUploader) do |instance|
            allow(instance).to receive(:file_storage?) { false }
            allow(instance).to receive(:url) { url }
            allow(instance).to receive(:size) { File.size(file_path) }
          end
        end

        it 'returns specific job trace' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to eq(job.trace.raw)
        end
      end

      context 'when trace is artifact' do
        let(:job) { create(:ci_build, :trace_artifact, pipeline: pipeline) }

        it 'returns specific job trace' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to eq(job.trace.raw)
        end
      end

      context 'when live trace and uploadless trace artifact' do
        let(:job) { create(:ci_build, :trace_live, :unarchived_trace_artifact, pipeline: pipeline) }

        it 'returns specific job trace' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to eq(job.trace.raw)
        end
      end

      context 'when trace is live' do
        let(:job) { create(:ci_build, :trace_live, pipeline: pipeline) }

        it 'returns specific job trace' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to eq(job.trace.raw)
        end
      end

      context 'when no trace' do
        let(:job) { create(:ci_build, pipeline: pipeline) }

        it 'returns empty trace' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to be_empty
        end
      end

      context 'when trace artifact record exists with no stored file' do
        let(:job) { create(:ci_build, pipeline: pipeline) }

        before do
          create(:ci_job_artifact, :unarchived_trace_artifact, job: job, project: job.project)
        end

        it 'returns empty trace' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to be_empty
        end
      end
    end

    context 'unauthorized user' do
      let(:api_user) { nil }

      it 'does not return specific job trace' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when ci_debug_trace is set to true' do
      before_all do
        create(:ci_instance_variable, key: 'CI_DEBUG_TRACE', value: true)
      end

      where(:public_builds, :user_project_role, :expected_status) do
        true         | 'developer'     | :ok
        true         | 'guest'         | :forbidden
        false        | 'developer'     | :ok
        false        | 'guest'         | :forbidden
      end

      with_them do
        before do
          project.update!(public_builds: public_builds)
          project.add_role(user, user_project_role)

          get api("/projects/#{project.id}/jobs/#{job.id}/trace", api_user)
        end

        it 'renders trace to authorized users' do
          expect(response).to have_gitlab_http_status(expected_status)
        end
      end
    end
  end

  describe 'POST /projects/:id/jobs/:job_id/cancel' do
    before do
      post api("/projects/#{project.id}/jobs/#{job.id}/cancel", api_user)
    end

    context 'authorized user' do
      context 'user with :update_build persmission' do
        it 'cancels running or pending job' do
          expect(response).to have_gitlab_http_status(:created)
          expect(project.builds.first.status).to eq('success')
        end
      end

      context 'user without :update_build permission' do
        let(:api_user) { reporter }

        it 'does not cancel job' do
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'unauthorized user' do
      let(:api_user) { nil }

      it 'does not cancel job' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/jobs/:job_id/retry' do
    let(:job) { create(:ci_build, :canceled, pipeline: pipeline) }

    before do
      post api("/projects/#{project.id}/jobs/#{job.id}/retry", api_user)
    end

    context 'authorized user' do
      context 'user with :update_build permission' do
        it 'retries non-running job' do
          expect(response).to have_gitlab_http_status(:created)
          expect(project.builds.first.status).to eq('canceled')
          expect(json_response['status']).to eq('pending')
        end
      end

      context 'when a build is not retryable' do
        let(:job) { create(:ci_build, :created, pipeline: pipeline) }

        it 'responds with unprocessable entity' do
          expect(json_response['message']).to eq('403 Forbidden - Job is not retryable')
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'user without :update_build permission' do
        let(:api_user) { reporter }

        it 'does not retry job' do
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'unauthorized user' do
      let(:api_user) { nil }

      it 'does not retry job' do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/jobs/:job_id/erase' do
    let(:role) { :maintainer }

    before do
      project.add_role(user, role)

      post api("/projects/#{project.id}/jobs/#{job.id}/erase", user)
    end

    shared_examples_for 'erases job' do
      it 'erases job content' do
        expect(response).to have_gitlab_http_status(:created)
        expect(job.job_artifacts.count).to eq(0)
        expect(job.trace.exist?).to be_falsy
        expect(job.artifacts_file.present?).to be_falsy
        expect(job.artifacts_metadata.present?).to be_falsy
        expect(job.has_job_artifacts?).to be_falsy
      end
    end

    context 'job is erasable' do
      let(:job) { create(:ci_build, :trace_artifact, :artifacts, :test_reports, :success, project: project, pipeline: pipeline) }

      it_behaves_like 'erases job'

      it 'updates job' do
        job.reload

        expect(job.erased_at).to be_truthy
        expect(job.erased_by).to eq(user)
      end
    end

    context 'when job has an unarchived trace artifact' do
      let(:job) { create(:ci_build, :success, :trace_live, :unarchived_trace_artifact, project: project, pipeline: pipeline) }

      it_behaves_like 'erases job'
    end

    context 'job is not erasable' do
      let(:job) { create(:ci_build, :trace_live, project: project, pipeline: pipeline) }

      it 'responds with forbidden' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when a developer erases a build' do
      let(:role) { :developer }
      let(:job) { create(:ci_build, :trace_artifact, :artifacts, :success, project: project, pipeline: pipeline, user: owner) }

      context 'when the build was created by the developer' do
        let(:owner) { user }

        it { expect(response).to have_gitlab_http_status(:created) }
      end

      context 'when the build was created by the other' do
        let(:owner) { create(:user) }

        it { expect(response).to have_gitlab_http_status(:forbidden) }
      end
    end
  end

  describe 'POST /projects/:id/jobs/:job_id/play' do
    let(:params) { {} }

    before do
      post api("/projects/#{project.id}/jobs/#{job.id}/play", api_user), params: params
    end

    context 'on a playable job' do
      let_it_be(:job) { create(:ci_build, :manual, project: project, pipeline: pipeline) }

      before do
        project.add_developer(user)
      end

      context 'when user is authorized to trigger a manual action' do
        context 'that is a bridge' do
          let_it_be(:job) { create(:ci_bridge, :playable, pipeline: pipeline, downstream: project) }

          it 'plays the job' do
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['user']['id']).to eq(user.id)
            expect(json_response['id']).to eq(job.id)
            expect(job.reload).to be_pending
          end
        end

        context 'that is a build' do
          it 'plays the job' do
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['user']['id']).to eq(user.id)
            expect(json_response['id']).to eq(job.id)
            expect(job.reload).to be_pending
          end
        end

        context 'when the user provides valid custom variables' do
          let(:params) { { job_variables_attributes: [{ key: 'TEST_VAR', value: 'test' }] } }

          it 'applies the variables to the job' do
            expect(response).to have_gitlab_http_status(:ok)
            expect(job.reload).to be_pending
            expect(job.job_variables.map(&:key)).to contain_exactly('TEST_VAR')
            expect(job.job_variables.map(&:value)).to contain_exactly('test')
          end
        end

        context 'when the user provides a variable without a key' do
          let(:params) { { job_variables_attributes: [{ value: 'test' }] } }

          it 'reports that the key is missing' do
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('job_variables_attributes[0][key] is missing')
            expect(job.reload).to be_manual
          end
        end

        context 'when the user provides a variable without a value' do
          let(:params) { { job_variables_attributes: [{ key: 'TEST_VAR' }] } }

          it 'reports that the value is missing' do
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('job_variables_attributes[0][value] is missing')
            expect(job.reload).to be_manual
          end
        end

        context 'when the user provides both valid and invalid variables' do
          let(:params) { { job_variables_attributes: [{ key: 'TEST_VAR', value: 'test' }, { value: 'test2' }] } }

          it 'reports the invalid variables and does not run the job' do
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('job_variables_attributes[1][key] is missing')
            expect(job.reload).to be_manual
          end
        end
      end

      context 'when user is not authorized to trigger a manual action' do
        context 'when user does not have access to the project' do
          let(:api_user) { create(:user) }

          it 'does not trigger a manual action' do
            expect(job.reload).to be_manual
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when user is not allowed to trigger the manual action' do
          let(:api_user) { reporter }

          it 'does not trigger a manual action' do
            expect(job.reload).to be_manual
            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end
    end

    context 'on a non-playable job' do
      it 'returns a status code 400, Bad Request' do
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to match("Unplayable Job")
      end
    end
  end
end

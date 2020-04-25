# frozen_string_literal: true

require 'spec_helper'

describe API::PipelineSchedules do
  let_it_be(:developer) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, public_builds: false) }

  before do
    project.add_developer(developer)
  end

  describe 'GET /projects/:id/pipeline_schedules' do
    context 'authenticated user with valid permissions' do
      let(:pipeline_schedule) { create(:ci_pipeline_schedule, project: project, owner: developer) }

      before do
        pipeline_schedule.pipelines << build(:ci_pipeline, project: project)
      end

      def create_pipeline_schedules(count)
        create_list(:ci_pipeline_schedule, count, project: project)
          .each do |pipeline_schedule|
          create(:user).tap do |user|
            project.add_developer(user)
            pipeline_schedule.update(owner: user)
          end
          pipeline_schedule.pipelines << build(:ci_pipeline, project: project)
        end
      end

      it 'returns list of pipeline_schedules' do
        get api("/projects/#{project.id}/pipeline_schedules", developer)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(response).to match_response_schema('pipeline_schedules')
      end

      it 'avoids N + 1 queries' do
        # We need at least two users to trigger a preload for that relation.
        create_pipeline_schedules(1)

        control_count = ActiveRecord::QueryRecorder.new do
          get api("/projects/#{project.id}/pipeline_schedules", developer)
        end.count

        create_pipeline_schedules(10)

        expect do
          get api("/projects/#{project.id}/pipeline_schedules", developer)
        end.not_to exceed_query_limit(control_count)
      end

      %w[active inactive].each do |target|
        context "when scope is #{target}" do
          before do
            create(:ci_pipeline_schedule, project: project, active: active?(target))
          end

          it 'returns matched pipeline schedules' do
            get api("/projects/#{project.id}/pipeline_schedules", developer), params: { scope: target }

            expect(json_response.map { |r| r['active'] }).to all(eq(active?(target)))
          end
        end

        def active?(str)
          (str == 'active') ? true : false
        end
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not return pipeline_schedules list' do
        get api("/projects/#{project.id}/pipeline_schedules", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not return pipeline_schedules list' do
        get api("/projects/#{project.id}/pipeline_schedules")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /projects/:id/pipeline_schedules/:pipeline_schedule_id' do
    let(:pipeline_schedule) { create(:ci_pipeline_schedule, project: project, owner: developer) }

    before do
      pipeline_schedule.variables << build(:ci_pipeline_schedule_variable)
      pipeline_schedule.pipelines << build(:ci_pipeline, project: project)
    end

    context 'authenticated user with valid permissions' do
      it 'returns pipeline_schedule details' do
        get api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", developer)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('pipeline_schedule')
      end

      it 'responds with 404 Not Found if requesting non-existing pipeline_schedule' do
        get api("/projects/#{project.id}/pipeline_schedules/-5", developer)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not return pipeline_schedules list' do
        get api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'authenticated user with insufficient permissions' do
      before do
        project.add_guest(user)
      end

      it 'does not return pipeline_schedules list' do
        get api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not return pipeline_schedules list' do
        get api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/pipeline_schedules' do
    let(:params) { attributes_for(:ci_pipeline_schedule) }

    context 'authenticated user with valid permissions' do
      context 'with required parameters' do
        it 'creates pipeline_schedule' do
          expect do
            post api("/projects/#{project.id}/pipeline_schedules", developer),
              params: params
          end.to change { project.pipeline_schedules.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('pipeline_schedule')
          expect(json_response['description']).to eq(params[:description])
          expect(json_response['ref']).to eq(params[:ref])
          expect(json_response['cron']).to eq(params[:cron])
          expect(json_response['cron_timezone']).to eq(params[:cron_timezone])
          expect(json_response['owner']['id']).to eq(developer.id)
        end
      end

      context 'without required parameters' do
        it 'does not create pipeline_schedule' do
          post api("/projects/#{project.id}/pipeline_schedules", developer)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when cron has validation error' do
        it 'does not create pipeline_schedule' do
          post api("/projects/#{project.id}/pipeline_schedules", developer),
            params: params.merge('cron' => 'invalid-cron')

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to have_key('cron')
        end
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not create pipeline_schedule' do
        post api("/projects/#{project.id}/pipeline_schedules", user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not create pipeline_schedule' do
        post api("/projects/#{project.id}/pipeline_schedules"), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /projects/:id/pipeline_schedules/:pipeline_schedule_id' do
    let(:pipeline_schedule) do
      create(:ci_pipeline_schedule, project: project, owner: developer)
    end

    context 'authenticated user with valid permissions' do
      it 'updates cron' do
        put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", developer),
          params: { cron: '1 2 3 4 *' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('pipeline_schedule')
        expect(json_response['cron']).to eq('1 2 3 4 *')
      end

      context 'when cron has validation error' do
        it 'does not update pipeline_schedule' do
          put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", developer),
            params: { cron: 'invalid-cron' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to have_key('cron')
        end
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not update pipeline_schedule' do
        put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not update pipeline_schedule' do
        put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/pipeline_schedules/:pipeline_schedule_id/take_ownership' do
    let(:pipeline_schedule) do
      create(:ci_pipeline_schedule, project: project, owner: developer)
    end

    context 'authenticated user with valid permissions' do
      it 'updates owner' do
        post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/take_ownership", developer)

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('pipeline_schedule')
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not update owner' do
        post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/take_ownership", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not update owner' do
        post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/take_ownership")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /projects/:id/pipeline_schedules/:pipeline_schedule_id' do
    let(:maintainer) { create(:user) }

    let!(:pipeline_schedule) do
      create(:ci_pipeline_schedule, project: project, owner: developer)
    end

    before do
      project.add_maintainer(maintainer)
    end

    context 'authenticated user with valid permissions' do
      it 'deletes pipeline_schedule' do
        expect do
          delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", maintainer)
        end.to change { project.pipeline_schedules.count }.by(-1)

        expect(response).to have_gitlab_http_status(204)
      end

      it 'responds with 404 Not Found if requesting non-existing pipeline_schedule' do
        delete api("/projects/#{project.id}/pipeline_schedules/-5", maintainer)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like '412 response' do
        let(:request) { api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", maintainer) }
      end
    end

    context 'authenticated user with invalid permissions' do
      let!(:pipeline_schedule) { create(:ci_pipeline_schedule, project: project, owner: maintainer) }

      it 'does not delete pipeline_schedule' do
        delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}", developer)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthenticated user' do
      it 'does not delete pipeline_schedule' do
        delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/pipeline_schedules/:pipeline_schedule_id/play' do
    let_it_be(:pipeline_schedule) { create(:ci_pipeline_schedule, project: project) }

    let(:route) { ->(id) { "/projects/#{project.id}/pipeline_schedules/#{id}/play" } }

    context 'authenticated user with `:play_pipeline_schedule` permission' do
      it 'schedules a pipeline worker' do
        project.add_developer(developer)

        expect(RunPipelineScheduleWorker)
          .to receive(:perform_async)
          .with(pipeline_schedule.id, developer.id)
          .and_call_original
        post api(route[pipeline_schedule.id], developer)

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'renders an error if scheduling failed' do
        project.add_developer(developer)

        expect(RunPipelineScheduleWorker)
          .to receive(:perform_async)
          .with(pipeline_schedule.id, developer.id)
          .and_return(nil)
        post api(route[pipeline_schedule.id], developer)

        expect(response).to have_gitlab_http_status(:internal_server_error)
      end
    end

    context 'authenticated user with insufficient access' do
      it 'responds with not found' do
        project.add_guest(user)

        post api(route[pipeline_schedule.id], user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'responds with unauthorized' do
        post api(route[pipeline_schedule.id])

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/pipeline_schedules/:pipeline_schedule_id/variables' do
    let(:params) { attributes_for(:ci_pipeline_schedule_variable) }

    let_it_be(:pipeline_schedule) do
      create(:ci_pipeline_schedule, project: project, owner: developer)
    end

    context 'authenticated user with valid permissions' do
      context 'with required parameters' do
        it 'creates pipeline_schedule_variable' do
          expect do
            post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables", developer),
              params: params.merge(variable_type: 'file')
          end.to change { pipeline_schedule.variables.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('pipeline_schedule_variable')
          expect(json_response['key']).to eq(params[:key])
          expect(json_response['value']).to eq(params[:value])
          expect(json_response['variable_type']).to eq('file')
        end
      end

      context 'without required parameters' do
        it 'does not create pipeline_schedule_variable' do
          post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables", developer)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when key has validation error' do
        it 'does not create pipeline_schedule_variable' do
          post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables", developer),
            params: params.merge('key' => '!?!?')

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to have_key('key')
        end
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not create pipeline_schedule_variable' do
        post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables", user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not create pipeline_schedule_variable' do
        post api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables"), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /projects/:id/pipeline_schedules/:pipeline_schedule_id/variables/:key' do
    let_it_be(:pipeline_schedule) do
      create(:ci_pipeline_schedule, project: project, owner: developer)
    end

    let(:pipeline_schedule_variable) do
      create(:ci_pipeline_schedule_variable, pipeline_schedule: pipeline_schedule)
    end

    context 'authenticated user with valid permissions' do
      it 'updates pipeline_schedule_variable' do
        put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/#{pipeline_schedule_variable.key}", developer),
          params: { value: 'updated_value', variable_type: 'file' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('pipeline_schedule_variable')
        expect(json_response['value']).to eq('updated_value')
        expect(json_response['variable_type']).to eq('file')
      end
    end

    context 'authenticated user with invalid permissions' do
      it 'does not update pipeline_schedule_variable' do
        put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/#{pipeline_schedule_variable.key}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'unauthenticated user' do
      it 'does not update pipeline_schedule_variable' do
        put api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/#{pipeline_schedule_variable.key}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /projects/:id/pipeline_schedules/:pipeline_schedule_id/variables/:key' do
    let(:maintainer) { create(:user) }

    let_it_be(:pipeline_schedule) do
      create(:ci_pipeline_schedule, project: project, owner: developer)
    end

    let!(:pipeline_schedule_variable) do
      create(:ci_pipeline_schedule_variable, pipeline_schedule: pipeline_schedule)
    end

    before do
      project.add_maintainer(maintainer)
    end

    context 'authenticated user with valid permissions' do
      it 'deletes pipeline_schedule_variable' do
        expect do
          delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/#{pipeline_schedule_variable.key}", maintainer)
        end.to change { Ci::PipelineScheduleVariable.count }.by(-1)

        expect(response).to have_gitlab_http_status(:accepted)
        expect(response).to match_response_schema('pipeline_schedule_variable')
      end

      it 'responds with 404 Not Found if requesting non-existing pipeline_schedule_variable' do
        delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/____", maintainer)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'authenticated user with invalid permissions' do
      let!(:pipeline_schedule) { create(:ci_pipeline_schedule, project: project, owner: maintainer) }

      it 'does not delete pipeline_schedule_variable' do
        delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/#{pipeline_schedule_variable.key}", developer)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'unauthenticated user' do
      it 'does not delete pipeline_schedule_variable' do
        delete api("/projects/#{project.id}/pipeline_schedules/#{pipeline_schedule.id}/variables/#{pipeline_schedule_variable.key}")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end
end

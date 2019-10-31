# frozen_string_literal: true

require 'spec_helper'

describe Projects::EnvironmentsController do
  include MetricsDashboardHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let_it_be(:environment) do
    create(:environment, name: 'production', project: project)
  end

  before do
    project.add_maintainer(user)

    sign_in(user)
  end

  describe 'GET index' do
    context 'when a request for the HTML is made' do
      it 'responds with status code 200' do
        get :index, params: environment_params

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'expires etag cache to force reload environments list' do
        expect_any_instance_of(Gitlab::EtagCaching::Store)
          .to receive(:touch).with(project_environments_path(project, format: :json))

        get :index, params: environment_params
      end
    end

    context 'when requesting JSON response for folders' do
      before do
        create(:environment, project: project,
                             name: 'staging/review-1',
                             state: :available)

        create(:environment, project: project,
                             name: 'staging/review-2',
                             state: :available)

        create(:environment, project: project,
                             name: 'staging/review-3',
                             state: :stopped)
      end

      let(:environments) { json_response['environments'] }

      context 'with default parameters' do
        before do
          get :index, params: environment_params(format: :json)
        end

        it 'responds with a flat payload describing available environments' do
          expect(environments.count).to eq 3
          expect(environments.first).to include('name' => 'production', 'name_without_type' => 'production')
          expect(environments.second).to include('name' => 'staging/review-1', 'name_without_type' => 'review-1')
          expect(environments.third).to include('name' => 'staging/review-2', 'name_without_type' => 'review-2')
          expect(json_response['available_count']).to eq 3
          expect(json_response['stopped_count']).to eq 1
        end

        it 'sets the polling interval header' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Poll-Interval']).to eq("3000")
        end
      end

      context 'when a folder-based nested structure is requested' do
        before do
          get :index, params: environment_params(format: :json, nested: true)
        end

        it 'responds with a payload containing the latest environment for each folder' do
          expect(environments.count).to eq 2
          expect(environments.first['name']).to eq 'production'
          expect(environments.second['name']).to eq 'staging'
          expect(environments.second['size']).to eq 2
          expect(environments.second['latest']['name']).to eq 'staging/review-2'
        end
      end

      context 'when requesting available environments scope' do
        before do
          get :index, params: environment_params(format: :json, nested: true, scope: :available)
        end

        it 'responds with a payload describing available environments' do
          expect(environments.count).to eq 2
          expect(environments.first['name']).to eq 'production'
          expect(environments.second['name']).to eq 'staging'
          expect(environments.second['size']).to eq 2
          expect(environments.second['latest']['name']).to eq 'staging/review-2'
        end

        it 'contains values describing environment scopes sizes' do
          expect(json_response['available_count']).to eq 3
          expect(json_response['stopped_count']).to eq 1
        end
      end

      context 'when requesting stopped environments scope' do
        before do
          get :index, params: environment_params(format: :json, nested: true, scope: :stopped)
        end

        it 'responds with a payload describing stopped environments' do
          expect(environments.count).to eq 1
          expect(environments.first['name']).to eq 'staging'
          expect(environments.first['size']).to eq 1
          expect(environments.first['latest']['name']).to eq 'staging/review-3'
        end

        it 'contains values describing environment scopes sizes' do
          expect(json_response['available_count']).to eq 3
          expect(json_response['stopped_count']).to eq 1
        end
      end
    end
  end

  describe 'GET folder' do
    before do
      create(:environment, project: project,
                           name: 'staging-1.0/review',
                           state: :available)
      create(:environment, project: project,
                           name: 'staging-1.0/zzz',
                           state: :available)
    end

    context 'when using default format' do
      it 'responds with HTML' do
        get :folder, params: {
                       namespace_id: project.namespace,
                       project_id: project,
                       id: 'staging-1.0'
                     }

        expect(response).to be_ok
        expect(response).to render_template 'folder'
      end
    end

    context 'when using JSON format' do
      it 'sorts the subfolders lexicographically' do
        get :folder, params: {
                       namespace_id: project.namespace,
                       project_id: project,
                       id: 'staging-1.0'
                     },
                     format: :json

        expect(response).to be_ok
        expect(response).not_to render_template 'folder'
        expect(json_response['environments'][0])
          .to include('name' => 'staging-1.0/review', 'name_without_type' => 'review')
        expect(json_response['environments'][1])
          .to include('name' => 'staging-1.0/zzz', 'name_without_type' => 'zzz')
      end
    end
  end

  describe 'GET show' do
    context 'with valid id' do
      it 'responds with a status code 200' do
        get :show, params: environment_params

        expect(response).to be_ok
      end
    end

    context 'with invalid id' do
      it 'responds with a status code 404' do
        params = environment_params
        params[:id] = 12345
        get :show, params: params

        expect(response).to have_gitlab_http_status(404)
      end
    end
  end

  describe 'GET edit' do
    it 'responds with a status code 200' do
      get :edit, params: environment_params

      expect(response).to be_ok
    end
  end

  describe 'PATCH #update' do
    it 'responds with a 302' do
      patch_params = environment_params.merge(environment: { external_url: 'https://git.gitlab.com' })
      patch :update, params: patch_params

      expect(response).to have_gitlab_http_status(302)
    end
  end

  describe 'PATCH #stop' do
    context 'when env not available' do
      it 'returns 404' do
        allow_any_instance_of(Environment).to receive(:available?) { false }

        patch :stop, params: environment_params(format: :json)

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when stop action' do
      it 'returns action url' do
        action = create(:ci_build, :manual)

        allow_any_instance_of(Environment)
          .to receive_messages(available?: true, stop_with_action!: action)

        patch :stop, params: environment_params(format: :json)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response).to eq(
          { 'redirect_url' =>
              project_job_url(project, action) })
      end
    end

    context 'when no stop action' do
      it 'returns env url' do
        allow_any_instance_of(Environment)
          .to receive_messages(available?: true, stop_with_action!: nil)

        patch :stop, params: environment_params(format: :json)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response).to eq(
          { 'redirect_url' =>
              project_environment_url(project, environment) })
      end
    end
  end

  describe 'GET #terminal' do
    context 'with valid id' do
      it 'responds with a status code 200' do
        get :terminal, params: environment_params

        expect(response).to have_gitlab_http_status(200)
      end

      it 'loads the terminals for the environment' do
        # In EE we have to stub EE::Environment since it overwrites the
        # "terminals" method.
        expect_any_instance_of(Gitlab.ee? ? EE::Environment : Environment)
          .to receive(:terminals)

        get :terminal, params: environment_params
      end
    end

    context 'with invalid id' do
      it 'responds with a status code 404' do
        get :terminal, params: environment_params(id: 666)

        expect(response).to have_gitlab_http_status(404)
      end
    end
  end

  describe 'GET #terminal_websocket_authorize' do
    context 'with valid workhorse signature' do
      before do
        allow(Gitlab::Workhorse).to receive(:verify_api_request!).and_return(nil)
      end

      context 'and valid id' do
        it 'returns the first terminal for the environment' do
          # In EE we have to stub EE::Environment since it overwrites the
          # "terminals" method.
          expect_any_instance_of(Gitlab.ee? ? EE::Environment : Environment)
            .to receive(:terminals)
            .and_return([:fake_terminal])

          expect(Gitlab::Workhorse)
            .to receive(:channel_websocket)
            .with(:fake_terminal)
            .and_return(workhorse: :response)

          get :terminal_websocket_authorize, params: environment_params

          expect(response).to have_gitlab_http_status(200)
          expect(response.headers["Content-Type"]).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
          expect(response.body).to eq('{"workhorse":"response"}')
        end
      end

      context 'and invalid id' do
        it 'returns 404' do
          get :terminal_websocket_authorize, params: environment_params(id: 666)

          expect(response).to have_gitlab_http_status(404)
        end
      end
    end

    context 'with invalid workhorse signature' do
      it 'aborts with an exception' do
        allow(Gitlab::Workhorse).to receive(:verify_api_request!).and_raise(JWT::DecodeError)

        expect { get :terminal_websocket_authorize, params: environment_params }.to raise_error(JWT::DecodeError)
        # controller tests don't set the response status correctly. It's enough
        # to check that the action raised an exception
      end
    end
  end

  describe 'GET #metrics_redirect' do
    let(:project) { create(:project) }

    it 'redirects to environment if it exists' do
      environment = create(:environment, name: 'production', project: project)

      get :metrics_redirect, params: { namespace_id: project.namespace, project_id: project }

      expect(response).to redirect_to(environment_metrics_path(environment))
    end

    it 'redirects to empty page if no environment exists' do
      get :metrics_redirect, params: { namespace_id: project.namespace, project_id: project }

      expect(response).to be_ok
      expect(response).to render_template 'empty'
    end
  end

  describe 'GET #metrics' do
    before do
      allow(controller).to receive(:environment).and_return(environment)
    end

    context 'when environment has no metrics' do
      it 'returns a metrics page' do
        expect(environment).not_to receive(:metrics)

        get :metrics, params: environment_params

        expect(response).to be_ok
      end

      context 'when requesting metrics as JSON' do
        it 'returns a metrics JSON document' do
          expect(environment).to receive(:metrics).and_return(nil)

          get :metrics, params: environment_params(format: :json)

          expect(response).to have_gitlab_http_status(204)
          expect(json_response).to eq({})
        end
      end
    end

    context 'when environment has some metrics' do
      before do
        expect(environment).to receive(:metrics).and_return({
          success: true,
          metrics: {},
          last_update: 42
        })
      end

      it 'returns a metrics JSON document' do
        get :metrics, params: environment_params(format: :json)

        expect(response).to be_ok
        expect(json_response['success']).to be(true)
        expect(json_response['metrics']).to eq({})
        expect(json_response['last_update']).to eq(42)
      end
    end
  end

  describe 'GET #additional_metrics' do
    let(:window_params) { { start: '1554702993.5398998', end: '1554717396.996232' } }

    before do
      allow(controller).to receive(:environment).and_return(environment)
    end

    context 'when environment has no metrics' do
      before do
        expect(environment).to receive(:additional_metrics).and_return(nil)
      end

      context 'when requesting metrics as JSON' do
        it 'returns a metrics JSON document' do
          additional_metrics(window_params)

          expect(response).to have_gitlab_http_status(204)
          expect(json_response).to eq({})
        end
      end
    end

    context 'when environment has some metrics' do
      before do
        expect(environment)
          .to receive(:additional_metrics)
                .and_return({
                              success: true,
                              data: {},
                              last_update: 42
                            })
      end

      it 'returns a metrics JSON document' do
        additional_metrics(window_params)

        expect(response).to be_ok
        expect(json_response['success']).to be(true)
        expect(json_response['data']).to eq({})
        expect(json_response['last_update']).to eq(42)
      end
    end

    context 'when time params are missing' do
      it 'raises an error when window params are missing' do
        expect { additional_metrics }
        .to raise_error(ActionController::ParameterMissing)
      end
    end

    context 'when only one time param is provided' do
      it 'raises an error when start is missing' do
        expect { additional_metrics(end: '1552647300.651094') }
          .to raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error when end is missing' do
        expect { additional_metrics(start: '1552647300.651094') }
          .to raise_error(ActionController::ParameterMissing)
      end
    end
  end

  describe 'GET #metrics_dashboard' do
    shared_examples_for 'correctly formatted response' do |status_code|
      it 'returns a json object with the correct keys' do
        get :metrics_dashboard, params: environment_params(dashboard_params)

        # Exlcude `all_dashboards` to handle separately.
        found_keys = json_response.keys - ['all_dashboards']

        expect(response).to have_gitlab_http_status(status_code)
        expect(found_keys).to contain_exactly(*expected_keys)
      end
    end

    shared_examples_for '200 response' do
      let(:expected_keys) { %w(dashboard status) }

      it_behaves_like 'correctly formatted response', :ok
    end

    shared_examples_for 'error response' do |status_code|
      let(:expected_keys) { %w(message status) }

      it_behaves_like 'correctly formatted response', status_code
    end

    shared_examples_for 'includes all dashboards' do
      it 'includes info for all findable dashboard' do
        get :metrics_dashboard, params: environment_params(dashboard_params)

        expect(json_response).to have_key('all_dashboards')
        expect(json_response['all_dashboards']).to be_an_instance_of(Array)
        expect(json_response['all_dashboards']).to all( include('path', 'default', 'display_name') )
      end
    end

    shared_examples_for 'the default dashboard' do
      it_behaves_like '200 response'
      it_behaves_like 'includes all dashboards'

      it 'is the default dashboard' do
        get :metrics_dashboard, params: environment_params(dashboard_params)

        expect(json_response['dashboard']['dashboard']).to eq('Environment metrics')
      end
    end

    shared_examples_for 'the specified dashboard' do |expected_dashboard|
      it_behaves_like '200 response'
      it_behaves_like 'includes all dashboards'

      it 'has the correct name' do
        get :metrics_dashboard, params: environment_params(dashboard_params)

        dashboard_name = json_response['dashboard']['dashboard']

        # 'Environment metrics' is the default dashboard.
        expect(dashboard_name).not_to eq('Environment metrics')
        expect(dashboard_name).to eq(expected_dashboard)
      end

      context 'when the dashboard cannot not be processed' do
        before do
          allow(YAML).to receive(:safe_load).and_return({})
        end

        it_behaves_like 'error response', :unprocessable_entity
      end
    end

    shared_examples_for 'specified dashboard embed' do |expected_titles|
      it_behaves_like '200 response'

      it 'contains only the specified charts' do
        get :metrics_dashboard, params: environment_params(dashboard_params)

        dashboard = json_response['dashboard']
        panel_group = dashboard['panel_groups'].first
        titles = panel_group['panels'].map { |panel| panel['title'] }

        expect(dashboard['dashboard']).to be_nil
        expect(dashboard['panel_groups'].length).to eq 1
        expect(panel_group['group']).to be_nil
        expect(titles).to eq expected_titles
      end
    end

    shared_examples_for 'the default dynamic dashboard' do
      it_behaves_like 'specified dashboard embed', ['Memory Usage (Total)', 'Core Usage (Total)']
    end

    shared_examples_for 'dashboard can be specified' do
      context 'when dashboard is specified' do
        let(:dashboard_path) { '.gitlab/dashboards/test.yml' }
        let(:dashboard_params) { { format: :json, dashboard: dashboard_path } }

        it_behaves_like 'error response', :not_found

        context 'when the project dashboard is available' do
          let(:dashboard_yml) { fixture_file('lib/gitlab/metrics/dashboard/sample_dashboard.yml') }
          let(:project) { project_with_dashboard(dashboard_path, dashboard_yml) }
          let(:environment) { create(:environment, name: 'production', project: project) }

          it_behaves_like 'the specified dashboard', 'Test Dashboard'
        end

        context 'when the specified dashboard is the default dashboard' do
          let(:dashboard_path) { system_dashboard_path }

          it_behaves_like 'the default dashboard'
        end
      end
    end

    shared_examples_for 'dashboard can be embedded' do
      context 'when the embedded flag is included' do
        let(:dashboard_params) { { format: :json, embedded: true } }

        it_behaves_like 'the default dynamic dashboard'

        context 'when incomplete dashboard params are provided' do
          let(:dashboard_params) { { format: :json, embedded: true, title: 'Title' } }

          # The title param should be ignored.
          it_behaves_like 'the default dynamic dashboard'
        end

        context 'when invalid params are provided' do
          let(:dashboard_params) { { format: :json, embedded: true, metric_id: 16 } }

          # The superfluous param should be ignored.
          it_behaves_like 'the default dynamic dashboard'
        end

        context 'when the dashboard is correctly specified' do
          let(:dashboard_params) do
            {
              format: :json,
              embedded: true,
              dashboard: system_dashboard_path,
              group: business_metric_title,
              title: 'title',
              y_label: 'y_label'
            }
          end

          it_behaves_like 'error response', :not_found

          context 'and exists' do
            let!(:metric) { create(:prometheus_metric, project: project) }

            it_behaves_like 'specified dashboard embed', ['title']
          end
        end
      end
    end

    shared_examples_for 'dashboard cannot be specified' do
      context 'when dashboard is specified' do
        let(:dashboard_params) { { format: :json, dashboard: '.gitlab/dashboards/test.yml' } }

        it_behaves_like 'the default dashboard'
      end
    end

    let(:dashboard_params) { { format: :json } }

    it_behaves_like 'the default dashboard'
    it_behaves_like 'dashboard can be specified'
    it_behaves_like 'dashboard can be embedded'
  end

  describe 'GET #search' do
    before do
      create(:environment, name: 'staging', project: project)
      create(:environment, name: 'review/patch-1', project: project)
      create(:environment, name: 'review/patch-2', project: project)
    end

    let(:query) { 'pro' }

    it 'responds with status code 200' do
      get :search, params: environment_params(format: :json, query: query)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'returns matched results' do
      get :search, params: environment_params(format: :json, query: query)

      expect(json_response).to contain_exactly('production')
    end

    context 'when query is review' do
      let(:query) { 'review' }

      it 'returns matched results' do
        get :search, params: environment_params(format: :json, query: query)

        expect(json_response).to contain_exactly('review/patch-1', 'review/patch-2')
      end
    end

    context 'when query is empty' do
      let(:query) { '' }

      it 'returns matched results' do
        get :search, params: environment_params(format: :json, query: query)

        expect(json_response)
          .to contain_exactly('production', 'staging', 'review/patch-1', 'review/patch-2')
      end
    end

    context 'when query is review/patch-3' do
      let(:query) { 'review/patch-3' }

      it 'responds with status code 204' do
        get :search, params: environment_params(format: :json, query: query)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'when query is partially matched in the middle of environment name' do
      let(:query) { 'patch' }

      it 'responds with status code 204' do
        get :search, params: environment_params(format: :json, query: query)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'when query contains a wildcard character' do
      let(:query) { 'review%' }

      it 'prevents wildcard injection' do
        get :search, params: environment_params(format: :json, query: query)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'when query matches case insensitively' do
      let(:query) { 'Prod' }

      it 'returns matched results' do
        get :search, params: environment_params(format: :json, query: query)

        expect(json_response).to contain_exactly('production')
      end
    end
  end

  def environment_params(opts = {})
    opts.reverse_merge(namespace_id: project.namespace,
                       project_id: project,
                       id: environment.id)
  end

  def additional_metrics(opts = {})
    get :additional_metrics, params: environment_params(format: :json, **opts)
  end
end

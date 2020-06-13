# frozen_string_literal: true

require "spec_helper"

describe API::Services do
  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let_it_be(:project, reload: true) do
    create(:project, creator_id: user.id, namespace: user.namespace)
  end

  describe "GET /projects/:id/services" do
    it 'returns authentication error when unauthenticated' do
      get api("/projects/#{project.id}/services")

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it "returns error when authenticated but user is not a project owner" do
      project.add_developer(user2)
      get api("/projects/#{project.id}/services", user2)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'project with services' do
      let!(:active_service) { create(:emails_on_push_service, project: project, active: true) }
      let!(:service) { create(:custom_issue_tracker_service, project: project, active: false) }

      it "returns a list of all active services" do
        get api("/projects/#{project.id}/services", user)

        aggregate_failures 'expect successful response with all active services' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Array
          expect(json_response.count).to eq(1)
          expect(json_response.first['slug']).to eq('emails-on-push')
          expect(response).to match_response_schema('public_api/v4/services')
        end
      end
    end
  end

  Service.available_services_names.each do |service|
    describe "PUT /projects/:id/services/#{service.dasherize}" do
      include_context service

      it "updates #{service} settings" do
        put api("/projects/#{project.id}/services/#{dashed_service}", user), params: service_attrs

        expect(response).to have_gitlab_http_status(:ok)

        current_service = project.services.first
        events = current_service.event_names.empty? ? ["foo"].freeze : current_service.event_names
        query_strings = []
        events.each do |event|
          query_strings << "#{event}=#{!current_service[event]}"
        end
        query_strings = query_strings.join('&')

        put api("/projects/#{project.id}/services/#{dashed_service}?#{query_strings}", user), params: service_attrs

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['slug']).to eq(dashed_service)
        events.each do |event|
          next if event == "foo"

          expect(project.services.first[event]).not_to eq(current_service[event]),
            "expected #{!current_service[event]} for event #{event} for service #{current_service.title}, got #{current_service[event]}"
        end
      end

      it "returns if required fields missing" do
        attrs = service_attrs

        required_attributes = service_attrs_list.select do |attr|
          service_klass.validators_on(attr).any? do |v|
            v.class == ActiveRecord::Validations::PresenceValidator
          end
        end

        if required_attributes.empty?
          expected_code = 200
        else
          attrs.delete(required_attributes.sample)
          expected_code = 400
        end

        put api("/projects/#{project.id}/services/#{dashed_service}", user), params: attrs

        expect(response.status).to eq(expected_code)
      end
    end

    describe "DELETE /projects/:id/services/#{service.dasherize}" do
      include_context service

      before do
        initialize_service(service)
      end

      it "deletes #{service}" do
        delete api("/projects/#{project.id}/services/#{dashed_service}", user)

        expect(response).to have_gitlab_http_status(:no_content)
        project.send(service_method).reload
        expect(project.send(service_method).activated?).to be_falsey
      end
    end

    describe "GET /projects/:id/services/#{service.dasherize}" do
      include_context service

      # inject some properties into the service
      let!(:initialized_service) { initialize_service(service) }

      it 'returns authentication error when unauthenticated' do
        get api("/projects/#{project.id}/services/#{dashed_service}")
        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it "returns all properties of service #{service}" do
        get api("/projects/#{project.id}/services/#{dashed_service}", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['properties'].keys).to match_array(service_instance.api_field_names)
      end

      it "returns error when authenticated but not a project owner" do
        project.add_developer(user2)
        get api("/projects/#{project.id}/services/#{dashed_service}", user2)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /projects/:id/services/:slug/trigger' do
    describe 'Mattermost Service' do
      let(:service_name) { 'mattermost_slash_commands' }

      context 'no service is available' do
        it 'returns a not found message' do
          post api("/projects/#{project.id}/services/idonotexist/trigger")

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response["error"]).to eq("404 Not Found")
        end
      end

      context 'the service exists' do
        let(:params) { { token: 'token' } }

        context 'the service is not active' do
          before do
            project.create_mattermost_slash_commands_service(
              active: false,
              properties: params
            )
          end

          it 'when the service is inactive' do
            post api("/projects/#{project.id}/services/#{service_name}/trigger"), params: params

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'the service is active' do
          before do
            project.create_mattermost_slash_commands_service(
              active: true,
              properties: params
            )
          end

          it 'returns status 200' do
            post api("/projects/#{project.id}/services/#{service_name}/trigger"), params: params

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'when the project can not be found' do
          it 'returns a generic 404' do
            post api("/projects/404/services/#{service_name}/trigger"), params: params

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response["message"]).to eq("404 Service Not Found")
          end
        end
      end
    end

    describe 'Slack Service' do
      let(:service_name) { 'slack_slash_commands' }

      before do
        project.create_slack_slash_commands_service(
          active: true,
          properties: { token: 'token' }
        )
      end

      it 'returns status 200' do
        post api("/projects/#{project.id}/services/#{service_name}/trigger"), params: { token: 'token', text: 'help' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['response_type']).to eq("ephemeral")
      end
    end
  end

  describe 'Mattermost service' do
    let(:service_name) { 'mattermost' }
    let(:params) do
      { webhook: 'https://hook.example.com', username: 'username' }
    end

    before do
      project.create_mattermost_service(
        active: true,
        properties: params
      )
    end

    it 'accepts a username for update' do
      put api("/projects/#{project.id}/services/#{service_name}", user), params: params.merge(username: 'new_username')

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['properties']['username']).to eq('new_username')
    end
  end

  describe 'Microsoft Teams service' do
    let(:service_name) { 'microsoft-teams' }
    let(:params) do
      {
        webhook: 'https://hook.example.com',
        branches_to_be_notified: 'default',
        notify_only_broken_pipelines: false
      }
    end

    before do
      project.create_microsoft_teams_service(
        active: true,
        properties: params
      )
    end

    it 'accepts branches_to_be_notified for update' do
      put api("/projects/#{project.id}/services/#{service_name}", user), params: params.merge(branches_to_be_notified: 'all')

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['properties']['branches_to_be_notified']).to eq('all')
    end

    it 'accepts notify_only_broken_pipelines for update' do
      put api("/projects/#{project.id}/services/#{service_name}", user), params: params.merge(notify_only_broken_pipelines: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['properties']['notify_only_broken_pipelines']).to eq(true)
    end
  end
end

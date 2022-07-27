# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Environments do
  let_it_be(:user) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:project) { create(:project, :private, :repository, namespace: user.namespace) }
  let_it_be_with_reload(:environment) { create(:environment, project: project) }

  before do
    project.add_maintainer(user)
  end

  describe 'GET /projects/:id/environments', :aggregate_failures do
    context 'as member of the project' do
      it 'returns project environments' do
        get api("/projects/#{project.id}/environments", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/environments')
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
        expect(json_response.first['name']).to eq(environment.name)
        expect(json_response.first['tier']).to eq(environment.tier)
        expect(json_response.first['external_url']).to eq(environment.external_url)
        expect(json_response.first['project']).to match_schema('public_api/v4/project')
        expect(json_response.first).not_to have_key('last_deployment')
      end

      context 'when filtering' do
        let_it_be(:stopped_environment) { create(:environment, :stopped, project: project) }

        it 'returns environment by name' do
          get api("/projects/#{project.id}/environments?name=#{environment.name}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(1)
          expect(json_response.first['name']).to eq(environment.name)
        end

        it 'returns no environment by non-existent name' do
          get api("/projects/#{project.id}/environments?name=test", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(0)
        end

        it 'returns environments by name_like' do
          get api("/projects/#{project.id}/environments?search=envir", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(2)
        end

        it 'returns no environment by non-existent name_like' do
          get api("/projects/#{project.id}/environments?search=test", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(0)
        end

        it 'returns environment by valid state' do
          get api("/projects/#{project.id}/environments?states=available", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(1)
          expect(json_response.first['name']).to eq(environment.name)
        end

        it 'returns all environments when state is not specified' do
          get api("/projects/#{project.id}/environments", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(2)
          expect(json_response.first['name']).to eq(environment.name)
          expect(json_response.last['name']).to eq(stopped_environment.name)
        end

        it 'returns a 400 when filtering by invalid state' do
          get api("/projects/#{project.id}/environments?states=test", user)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('states does not have a valid value')
        end
      end
    end

    context 'as non member' do
      it 'returns a 404 status code' do
        get api("/projects/#{project.id}/environments", non_member)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST /projects/:id/environments' do
    context 'as a member' do
      it 'creates a environment with valid params' do
        post api("/projects/#{project.id}/environments", user), params: { name: "mepmep", tier: 'staging' }

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/environment')
        expect(json_response['name']).to eq('mepmep')
        expect(json_response['slug']).to eq('mepmep')
        expect(json_response['tier']).to eq('staging')
        expect(json_response['external']).to be nil
      end

      it 'requires name to be passed' do
        post api("/projects/#{project.id}/environments", user), params: { external_url: 'test.gitlab.com' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns a 400 if environment already exists' do
        post api("/projects/#{project.id}/environments", user), params: { name: environment.name }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns a 400 if slug is specified' do
        post api("/projects/#{project.id}/environments", user), params: { name: "foo", slug: "foo" }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["error"]).to eq("slug is automatically generated and cannot be changed")
      end
    end

    context 'a non member' do
      it 'rejects the request' do
        post api("/projects/#{project.id}/environments", non_member), params: { name: 'gitlab.com' }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns a 400 when the required params are missing' do
        post api("/projects/#{non_existing_record_id}/environments", non_member), params: { external_url: 'http://env.git.com' }
      end
    end
  end

  describe 'PUT /projects/:id/environments/:environment_id' do
    it 'returns a 200 if name and external_url are changed' do
      url = 'https://mepmep.whatever.ninja'
      put api("/projects/#{project.id}/environments/#{environment.id}", user),
          params: { name: 'Mepmep', external_url: url }

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/environment')
      expect(json_response['name']).to eq('Mepmep')
      expect(json_response['external_url']).to eq(url)
    end

    it 'returns a 200 if tier is changed' do
      put api("/projects/#{project.id}/environments/#{environment.id}", user),
          params: { tier: 'production' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/environment')
      expect(json_response['tier']).to eq('production')
    end

    it "won't allow slug to be changed" do
      slug = environment.slug
      api_url = api("/projects/#{project.id}/environments/#{environment.id}", user)
      put api_url, params: { slug: slug + "-foo" }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response["error"]).to eq("slug is automatically generated and cannot be changed")
    end

    it "won't update the external_url if only the name is passed" do
      url = environment.external_url
      put api("/projects/#{project.id}/environments/#{environment.id}", user),
          params: { name: 'Mepmep' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['name']).to eq('Mepmep')
      expect(json_response['external_url']).to eq(url)
    end

    it 'returns a 404 if the environment does not exist' do
      put api("/projects/#{project.id}/environments/#{non_existing_record_id}", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'DELETE /projects/:id/environments/:environment_id' do
    context 'as a maintainer' do
      it "rejects the requests in environment isn't stopped" do
        delete api("/projects/#{project.id}/environments/#{environment.id}", user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'returns a 204 for stopped environment' do
        environment.stop

        delete api("/projects/#{project.id}/environments/#{environment.id}", user)

        expect(response).to have_gitlab_http_status(:no_content)
      end

      it 'returns a 404 for non existing id' do
        delete api("/projects/#{project.id}/environments/#{non_existing_record_id}", user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end

      it_behaves_like '412 response' do
        before do
          environment.stop
        end

        let(:request) { api("/projects/#{project.id}/environments/#{environment.id}", user) }
      end
    end

    context 'a non member' do
      it 'rejects the request' do
        delete api("/projects/#{project.id}/environments/#{environment.id}", non_member)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST /projects/:id/environments/:environment_id/stop' do
    context 'as a maintainer' do
      context 'with a stoppable environment' do
        before do
          environment.update!(state: :available)

          post api("/projects/#{project.id}/environments/#{environment.id}/stop", user)
        end

        it 'returns a 200' do
          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/environment')
        end

        it 'actually stops the environment' do
          expect(environment.reload).to be_stopped
        end
      end

      it 'returns a 404 for non existing id' do
        post api("/projects/#{project.id}/environments/#{non_existing_record_id}/stop", user)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end

    context 'a non member' do
      it 'rejects the request' do
        post api("/projects/#{project.id}/environments/#{environment.id}/stop", non_member)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /projects/:id/environments/:environment_id' do
    context 'as member of the project' do
      it 'returns project environments' do
        create(:deployment, :success, project: project, environment: environment)

        get api("/projects/#{project.id}/environments/#{environment.id}", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/environment')
        expect(json_response['last_deployment']).to be_present
      end
    end

    context 'as non member' do
      it 'returns a 404 status code' do
        get api("/projects/#{project.id}/environments/#{environment.id}", non_member)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "DELETE /projects/:id/environments/review_apps" do
    shared_examples "delete stopped review environments" do
      around do |example|
        freeze_time { example.run }
      end

      it "deletes the old stopped review apps" do
        old_stopped_review_env = create(:environment, :with_review_app, :stopped, created_at: 31.days.ago, project: project)
        new_stopped_review_env = create(:environment, :with_review_app, :stopped, project: project)
        old_active_review_env  = create(:environment, :with_review_app, :available, created_at: 31.days.ago, project: project)
        old_stopped_other_env  = create(:environment, :stopped, created_at: 31.days.ago, project: project)
        new_stopped_other_env  = create(:environment, :stopped, project: project)
        old_active_other_env   = create(:environment, :available, created_at: 31.days.ago, project: project)

        delete api("/projects/#{project.id}/environments/review_apps", current_user), params: { dry_run: false }
        project.environments.reload

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response["scheduled_entries"].size).to eq(1)
        expect(json_response["scheduled_entries"].first["id"]).to eq(old_stopped_review_env.id)
        expect(json_response["unprocessable_entries"].size).to eq(0)
        expect(json_response["scheduled_entries"]).to match_schema('public_api/v4/environments')
        expect(json_response["unprocessable_entries"]).to match_schema('public_api/v4/environments')

        expect(old_stopped_review_env.reload.auto_delete_at).to eq(1.week.from_now)
        expect(new_stopped_review_env.reload.auto_delete_at).to be_nil
        expect(old_active_review_env.reload.auto_delete_at).to be_nil
        expect(old_stopped_other_env.reload.auto_delete_at).to be_nil
        expect(new_stopped_other_env.reload.auto_delete_at).to be_nil
        expect(old_active_other_env.reload.auto_delete_at).to be_nil
      end
    end

    context "as a maintainer" do
      it_behaves_like "delete stopped review environments" do
        let(:current_user) { user }
      end
    end

    context "as a developer" do
      let(:developer) { create(:user) }

      before do
        project.add_developer(developer)
      end

      it_behaves_like "delete stopped review environments" do
        let(:current_user) { developer }
      end
    end

    context "as a reporter" do
      let(:reporter) { create(:user) }

      before do
        project.add_reporter(reporter)
      end

      it "rejects the request" do
        delete api("/projects/#{project.id}/environments/review_apps", reporter)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "as a non member" do
      it "rejects the request" do
        delete api("/projects/#{project.id}/environments/review_apps", non_member)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end

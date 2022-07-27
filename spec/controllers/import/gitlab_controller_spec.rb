# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::GitlabController do
  include ImportSpecHelper

  let(:user) { create(:user) }
  let(:token) { "asdasd12345" }
  let(:access_params) { { gitlab_access_token: token } }

  def assign_session_token
    session[:gitlab_access_token] = token
  end

  before do
    sign_in(user)
    allow(controller).to receive(:gitlab_import_enabled?).and_return(true)
  end

  describe "GET callback" do
    it "updates access token" do
      allow_next_instance_of(Gitlab::GitlabImport::Client) do |instance|
        allow(instance).to receive(:get_token).and_return(token)
      end
      stub_omniauth_provider('gitlab')

      get :callback

      expect(session[:gitlab_access_token]).to eq(token)
      expect(controller).to redirect_to(status_import_gitlab_url)
    end

    it "importable_repos should return an array" do
      allow_next_instance_of(Gitlab::GitlabImport::Client) do |instance|
        allow(instance).to receive(:projects).and_return([{ "id": 1 }].to_enum)
      end

      expect(controller.send(:importable_repos)).to be_an_instance_of(Array)
    end

    it "passes namespace_id query param to status if provided" do
      namespace_id = 30

      allow_next_instance_of(Gitlab::GitlabImport::Client) do |instance|
        allow(instance).to receive(:get_token).and_return(token)
      end

      get :callback, params: { namespace_id: namespace_id }

      expect(controller).to redirect_to(status_import_gitlab_url(namespace_id: namespace_id))
    end
  end

  describe "GET status" do
    let(:repo_fake) { Struct.new(:id, :path, :path_with_namespace, :web_url, keyword_init: true) }
    let(:repo) { repo_fake.new(id: 1, path: 'vim', path_with_namespace: 'asd/vim', web_url: 'https://gitlab.com/asd/vim') }

    context 'when session contains access token' do
      before do
        assign_session_token
      end

      it_behaves_like 'import controller status' do
        let(:repo_id) { repo.id }
        let(:import_source) { repo.path_with_namespace }
        let(:provider_name) { 'gitlab' }
        let(:client_repos_field) { :projects }
      end
    end

    it 'redirects to auth if session does not contain access token' do
      remote_gitlab_url = 'https://test.host/auth/gitlab'

      allow(Gitlab::GitlabImport::Client)
        .to receive(:new)
        .and_return(double(authorize_url: remote_gitlab_url))

      get :status

      expect(response).to redirect_to(remote_gitlab_url)
    end
  end

  describe "POST create" do
    let(:project) { create(:project) }
    let(:gitlab_username) { user.username }
    let(:gitlab_user) do
      { username: gitlab_username }.with_indifferent_access
    end

    let(:gitlab_repo) do
      {
        path: 'vim',
        path_with_namespace: "#{gitlab_username}/vim",
        owner: { name: gitlab_username },
        namespace: { path: gitlab_username }
      }.with_indifferent_access
    end

    before do
      stub_client(user: gitlab_user, project: gitlab_repo)
      assign_session_token
    end

    it 'returns 200 response when the project is imported successfully' do
      allow(Gitlab::GitlabImport::ProjectCreator)
        .to receive(:new).with(gitlab_repo, user.namespace, user, access_params)
        .and_return(double(execute: project))

      post :create, format: :json

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'returns 422 response when the project could not be imported' do
      allow(Gitlab::GitlabImport::ProjectCreator)
        .to receive(:new).with(gitlab_repo, user.namespace, user, access_params)
        .and_return(double(execute: build(:project)))

      post :create, format: :json

      expect(response).to have_gitlab_http_status(:unprocessable_entity)
    end

    context "when the repository owner is the GitLab.com user" do
      context "when the GitLab.com user and GitLab server user's usernames match" do
        it "takes the current user's namespace" do
          expect(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, user.namespace, user, access_params)
            .and_return(double(execute: project))

          post :create, format: :json
        end
      end

      context "when the GitLab.com user and GitLab server user's usernames don't match" do
        let(:gitlab_username) { "someone_else" }

        it "takes the current user's namespace" do
          expect(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, user.namespace, user, access_params)
            .and_return(double(execute: project))

          post :create, format: :json
        end
      end
    end

    context "when the repository owner is not the GitLab.com user" do
      let(:other_username) { "someone_else" }

      before do
        gitlab_repo["namespace"]["path"] = other_username
        assign_session_token
      end

      context "when a namespace with the GitLab.com user's username already exists" do
        let!(:existing_namespace) { create(:group, name: other_username) }

        context "when the namespace is owned by the GitLab server user" do
          before do
            existing_namespace.add_owner(user)
          end

          it "takes the existing namespace" do
            expect(Gitlab::GitlabImport::ProjectCreator)
              .to receive(:new).with(gitlab_repo, existing_namespace, user, access_params)
              .and_return(double(execute: project))

            post :create, format: :json
          end
        end

        context "when the namespace is not owned by the GitLab server user" do
          it "doesn't create a project" do
            expect(Gitlab::GitlabImport::ProjectCreator)
              .not_to receive(:new)

            post :create, format: :json
          end
        end
      end

      context "when a namespace with the GitLab.com user's username doesn't exist" do
        context "when current user can create namespaces" do
          it "creates the namespace" do
            expect(Gitlab::GitlabImport::ProjectCreator)
              .to receive(:new).and_return(double(execute: project))

            expect { post :create, format: :json }.to change(Namespace, :count).by(1)
          end

          it "takes the new namespace" do
            expect(Gitlab::GitlabImport::ProjectCreator)
              .to receive(:new).with(gitlab_repo, an_instance_of(Group), user, access_params)
              .and_return(double(execute: project))

            post :create, format: :json
          end
        end

        context "when current user can't create namespaces" do
          before do
            user.update_attribute(:can_create_group, false)
          end

          it "doesn't create the namespace" do
            expect(Gitlab::GitlabImport::ProjectCreator)
              .to receive(:new).and_return(double(execute: project))

            expect { post :create, format: :json }.not_to change(Namespace, :count)
          end

          it "takes the current user's namespace" do
            expect(Gitlab::GitlabImport::ProjectCreator)
              .to receive(:new).with(gitlab_repo, user.namespace, user, access_params)
              .and_return(double(execute: project))

            post :create, format: :json
          end
        end
      end

      context 'user has chosen an existing nested namespace for the project' do
        let(:parent_namespace) { create(:group, name: 'foo') }
        let(:nested_namespace) { create(:group, name: 'bar', parent: parent_namespace) }

        before do
          parent_namespace.add_owner(user)
          nested_namespace.add_owner(user)
        end

        it 'takes the selected namespace and name' do
          expect(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, nested_namespace, user, access_params)
              .and_return(double(execute: project))

          post :create, params: { target_namespace: nested_namespace.full_path }, format: :json
        end
      end

      context 'user has chosen a non-existent nested namespaces for the project' do
        let(:test_name) { 'test_name' }

        it 'takes the selected namespace and name' do
          expect(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, kind_of(Namespace), user, access_params)
              .and_return(double(execute: project))

          post :create, params: { target_namespace: 'foo/bar' }, format: :json
        end

        it 'creates the namespaces' do
          allow(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, kind_of(Namespace), user, access_params)
              .and_return(double(execute: project))

          expect { post :create, params: { target_namespace: 'foo/bar' }, format: :json }
            .to change { Namespace.count }.by(2)
        end

        it 'new namespace has the right parent' do
          allow(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, kind_of(Namespace), user, access_params)
              .and_return(double(execute: project))

          post :create, params: { target_namespace: 'foo/bar' }, format: :json

          expect(Namespace.find_by_path_or_name('bar').parent.path).to eq('foo')
        end
      end

      context 'user has chosen existent and non-existent nested namespaces and name for the project' do
        let(:test_name) { 'test_name' }
        let!(:parent_namespace) { create(:group, name: 'foo') }

        before do
          parent_namespace.add_owner(user)
        end

        it 'takes the selected namespace and name' do
          expect(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, kind_of(Namespace), user, access_params)
              .and_return(double(execute: project))

          post :create, params: { target_namespace: 'foo/foobar/bar' }, format: :json
        end

        it 'creates the namespaces' do
          allow(Gitlab::GitlabImport::ProjectCreator)
            .to receive(:new).with(gitlab_repo, kind_of(Namespace), user, access_params)
              .and_return(double(execute: project))

          expect { post :create, params: { target_namespace: 'foo/foobar/bar' }, format: :json }
            .to change { Namespace.count }.by(2)
        end
      end

      context 'when user can not create projects in the chosen namespace' do
        it 'returns 422 response' do
          other_namespace = create(:group, name: 'other_namespace')

          post :create, params: { target_namespace: other_namespace.name }, format: :json

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      it_behaves_like 'project import rate limiter'
    end
  end
end

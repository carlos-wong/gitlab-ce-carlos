# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TreeController, feature_category: :source_code_management do
  let(:project) { create(:project, :repository, previous_default_branch: previous_default_branch) }
  let(:previous_default_branch) { nil }
  let(:user) { create(:user) }

  before do
    sign_in(user)

    project.add_maintainer(user)
    controller.instance_variable_set(:@project, project)
  end

  describe "GET show" do
    let(:params) do
      {
        namespace_id: project.namespace.to_param, project_id: project, id: id
      }
    end

    # Make sure any errors accessing the tree in our views bubble up to this spec
    render_views

    before do
      expect(::Gitlab::GitalyClient).to receive(:allow_ref_name_caching).and_call_original
      project.repository.add_tag(project.creator, 'ambiguous_ref', RepoHelpers.sample_commit.id)
      project.repository.add_branch(project.creator, 'ambiguous_ref', RepoHelpers.another_sample_commit.id)
      get :show, params: params
    end

    context 'when the ref is ambiguous' do
      let(:id) { 'ambiguous_ref' }
      let(:params) { { namespace_id: project.namespace, project_id: project, id: id, ref_type: ref_type } }

      context 'and explicitly requesting a branch' do
        let(:ref_type) { 'heads' }

        it 'redirects to blob#show with sha for the branch' do
          expect(response).to redirect_to(project_tree_path(project, RepoHelpers.another_sample_commit.id))
        end
      end

      context 'and explicitly requesting a tag' do
        let(:ref_type) { 'tags' }

        it 'responds with success' do
          expect(response).to be_ok
        end
      end
    end

    context "valid branch, no path" do
      let(:id) { 'master' }

      it { is_expected.to respond_with(:success) }
    end

    context "valid branch, valid path" do
      let(:id) { 'master/encoding/' }

      it { is_expected.to respond_with(:success) }
    end

    context "valid branch, invalid path" do
      let(:id) { 'master/invalid-path/' }

      it 'redirects' do
        expect(subject)
            .to redirect_to("/#{project.full_path}/-/tree/master")
      end
    end

    context "invalid branch, valid path" do
      let(:id) { 'invalid-branch/encoding/' }

      it { is_expected.to respond_with(:not_found) }
    end

    context "renamed default branch, valid file" do
      let(:id) { 'old-default-branch/encoding/' }
      let(:previous_default_branch) { 'old-default-branch' }

      it { is_expected.to redirect_to("/#{project.full_path}/-/tree/#{project.default_branch}/encoding/") }
    end

    context "renamed default branch, invalid file" do
      let(:id) { 'old-default-branch/invalid-path/' }
      let(:previous_default_branch) { 'old-default-branch' }

      it { is_expected.to redirect_to("/#{project.full_path}/-/tree/#{project.default_branch}/invalid-path/") }
    end

    context "valid empty branch, invalid path" do
      let(:id) { 'empty-branch/invalid-path/' }

      it 'redirects' do
        expect(subject)
            .to redirect_to("/#{project.full_path}/-/tree/empty-branch")
      end
    end

    context "valid empty branch" do
      let(:id) { 'empty-branch' }

      it { is_expected.to respond_with(:success) }
    end

    context "invalid SHA commit ID" do
      let(:id) { 'ff39438/.gitignore' }

      it { is_expected.to respond_with(:not_found) }
    end

    context "valid SHA commit ID" do
      let(:id) { '6d39438' }

      it { is_expected.to respond_with(:success) }
    end

    context "valid SHA commit ID with path" do
      let(:id) { '6d39438/.gitignore' }

      it { expect(response).to have_gitlab_http_status(:found) }
    end
  end

  describe 'GET show with whitespace in ref' do
    render_views

    let(:id) { "this ref/api/responses" }

    it 'does not call make a Gitaly request' do
      allow(::Gitlab::GitalyClient).to receive(:call).and_call_original
      expect(::Gitlab::GitalyClient).not_to receive(:call).with(anything, :commit_service, :find_commit, anything, anything)

      get :show, params: {
        namespace_id: project.namespace.to_param, project_id: project, id: id
      }

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET show with blob path' do
    render_views

    before do
      get :show, params: {
        namespace_id: project.namespace.to_param, project_id: project, id: id
      }
    end

    context 'redirect to blob' do
      let(:id) { 'master/README.md' }

      it 'redirects' do
        redirect_url = "/#{project.full_path}/-/blob/master/README.md"
        expect(subject).to redirect_to(redirect_url)
      end
    end
  end

  describe '#create_dir' do
    render_views

    before do
      post :create_dir, params: {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: 'master',
        dir_name: path,
        branch_name: branch_name,
        commit_message: 'Test commit message'
      }
    end

    context 'successful creation' do
      let(:path) { 'files/new_dir' }
      let(:branch_name) { 'master-test' }

      it 'redirects to the new directory' do
        expect(subject)
            .to redirect_to("/#{project.full_path}/-/tree/#{branch_name}/#{path}")
        expect(flash[:notice]).to eq('The directory has been successfully created.')
      end
    end

    context 'unsuccessful creation' do
      let(:path) { 'README.md' }
      let(:branch_name) { 'master' }

      it 'does not allow overwriting of existing files' do
        expect(subject)
            .to redirect_to("/#{project.full_path}/-/tree/master")
        expect(flash[:alert]).to eq('A file with this name already exists')
      end
    end
  end
end

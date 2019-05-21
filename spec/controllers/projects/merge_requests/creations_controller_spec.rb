# frozen_string_literal: true

require 'spec_helper'

describe Projects::MergeRequests::CreationsController do
  let(:project) { create(:project, :repository) }
  let(:user)    { project.owner }
  let(:fork_project) { create(:forked_project_with_submodules) }
  let(:get_diff_params) do
    {
      namespace_id: fork_project.namespace.to_param,
      project_id: fork_project,
      merge_request: {
        source_branch: 'remove-submodule',
        target_branch: 'master'
      }
    }
  end

  before do
    fork_project.add_maintainer(user)
    Projects::ForkService.new(project, user).execute(fork_project)
    sign_in(user)
  end

  describe 'GET new' do
    context 'merge request that removes a submodule' do
      it 'renders new merge request widget template' do
        get :new, params: get_diff_params

        expect(response).to be_success
      end
    end

    context 'merge request with some commits' do
      render_views

      let(:large_diff_params) do
        {
          namespace_id: fork_project.namespace.to_param,
          project_id: fork_project,
          merge_request: {
            source_branch: 'master',
            target_branch: 'fix'
          }
        }
      end

      describe 'with artificial limits' do
        before do
          # Load MergeRequestdiff so stub_const won't override it with its own definition
          # See https://github.com/rspec/rspec-mocks/issues/1079
          stub_const("#{MergeRequestDiff}::COMMITS_SAFE_SIZE", 2)
        end

        it 'limits total commits' do
          get :new, params: large_diff_params

          expect(response).to be_success

          total = assigns(:total_commit_count)
          expect(assigns(:commits)).to be_an Array
          expect(total).to be > 0
          expect(assigns(:hidden_commit_count)).to be > 0
          expect(response).to have_gitlab_http_status(200)
          expect(response.body).to match %r(<span class="commits-count">2 commits</span>)
        end
      end

      it 'shows total commits' do
        get :new, params: large_diff_params

        expect(response).to be_success

        total = assigns(:total_commit_count)
        expect(assigns(:commits)).to be_an CommitCollection
        expect(total).to be > 0
        expect(assigns(:hidden_commit_count)).to eq(0)
        expect(response).to have_gitlab_http_status(200)
        expect(response.body).to match %r(<span class="commits-count">#{total} commits</span>)
      end
    end
  end

  describe 'GET diffs' do
    context 'when merge request cannot be created' do
      it 'does not assign diffs var' do
        allow_any_instance_of(MergeRequest).to receive(:can_be_created).and_return(false)

        get :diffs, params: get_diff_params.merge(format: 'json')

        expect(response).to be_success
        expect(assigns[:diffs]).to be_nil
      end
    end
  end

  describe 'GET pipelines' do
    before do
      create(:ci_pipeline, sha: fork_project.commit('remove-submodule').id,
                           ref: 'remove-submodule',
                           project: fork_project)
    end

    it 'renders JSON including serialized pipelines' do
      get :pipelines, params: get_diff_params.merge(format: 'json')

      expect(response).to be_ok
      expect(json_response).to have_key 'pipelines'
      expect(json_response['pipelines']).not_to be_empty
    end
  end

  describe 'GET diff_for_path' do
    def diff_for_path(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        format: 'json'
      }

      get :diff_for_path, params: params.merge(extra_params)
    end

    let(:existing_path) { 'files/ruby/feature.rb' }

    context 'when both branches are in the same project' do
      it 'disables diff notes' do
        diff_for_path(old_path: existing_path, new_path: existing_path, merge_request: { source_branch: 'feature', target_branch: 'master' })

        expect(assigns(:diff_notes_disabled)).to be_truthy
      end

      it 'only renders the diffs for the path given' do
        expect(controller).to receive(:render_diff_for_path).and_wrap_original do |meth, diffs|
          expect(diffs.diff_files.map(&:new_path)).to contain_exactly(existing_path)
          meth.call(diffs)
        end

        diff_for_path(old_path: existing_path, new_path: existing_path, merge_request: { source_branch: 'feature', target_branch: 'master' })
      end
    end

    context 'when the source branch is in a different project to the target' do
      let(:other_project) { create(:project, :repository) }

      before do
        other_project.add_maintainer(user)
      end

      context 'when the path exists in the diff' do
        it 'disables diff notes' do
          diff_for_path(old_path: existing_path, new_path: existing_path, merge_request: { source_project: other_project, source_branch: 'feature', target_branch: 'master' })

          expect(assigns(:diff_notes_disabled)).to be_truthy
        end

        it 'only renders the diffs for the path given' do
          expect(controller).to receive(:render_diff_for_path).and_wrap_original do |meth, diffs|
            expect(diffs.diff_files.map(&:new_path)).to contain_exactly(existing_path)
            meth.call(diffs)
          end

          diff_for_path(old_path: existing_path, new_path: existing_path, merge_request: { source_project: other_project, source_branch: 'feature', target_branch: 'master' })
        end
      end

      context 'when the path does not exist in the diff' do
        before do
          diff_for_path(old_path: 'files/ruby/nopen.rb', new_path: 'files/ruby/nopen.rb', merge_request: { source_project: other_project, source_branch: 'feature', target_branch: 'master' })
        end

        it 'returns a 404' do
          expect(response).to have_gitlab_http_status(404)
        end
      end
    end
  end

  describe 'GET #branch_to' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
    end

    it 'fetches the commit if a user has access' do
      expect(Ability).to receive(:allowed?).with(user, :read_project, project) { true }

      get :branch_to,
          params: {
            namespace_id: fork_project.namespace,
            project_id: fork_project,
            target_project_id: project.id,
            ref: 'master'
          }

      expect(assigns(:commit)).not_to be_nil
      expect(response).to have_gitlab_http_status(200)
    end

    it 'does not load the commit when the user cannot read the project' do
      expect(Ability).to receive(:allowed?).with(user, :read_project, project) { false }

      get :branch_to,
          params: {
            namespace_id: fork_project.namespace,
            project_id: fork_project,
            target_project_id: project.id,
            ref: 'master'
          }

      expect(assigns(:commit)).to be_nil
      expect(response).to have_gitlab_http_status(200)
    end
  end
end

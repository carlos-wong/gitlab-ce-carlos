# frozen_string_literal: true

require 'spec_helper'

describe Projects::MergeRequests::DiffsController do
  include ProjectForksHelper

  shared_examples '404 for unexistent diffable' do
    context 'when diffable does not exists' do
      it 'returns 404' do
        unexistent_diff_id = 9999

        go(diff_id: unexistent_diff_id)

        expect(MergeRequestDiff.find_by(id: unexistent_diff_id)).to be_nil
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'forked project with submodules' do
    render_views

    let(:project) { create(:project, :repository) }
    let(:forked_project) { fork_project_with_submodules(project) }
    let(:merge_request) { create(:merge_request_with_diffs, source_project: forked_project, source_branch: 'add-submodule-version-bump', target_branch: 'master', target_project: project) }

    before do
      project.add_developer(user)

      merge_request.reload
      go
    end

    it 'renders' do
      expect(response).to be_successful
      expect(response.body).to have_content('Subproject commit')
    end
  end

  shared_examples 'cached diff collection' do
    it 'ensures diff highlighting cache writing' do
      expect_next_instance_of(Gitlab::Diff::HighlightCache) do |cache|
        expect(cache).to receive(:write_if_empty).once
      end

      go
    end
  end

  shared_examples 'persisted preferred diff view cookie' do
    context 'with view param' do
      before do
        go(view: 'parallel')
      end

      it 'saves the preferred diff view in a cookie' do
        expect(response.cookies['diff_view']).to eq('parallel')
      end

      it 'only renders the required view', :aggregate_failures do
        diff_files_without_deletions = json_response['diff_files'].reject { |f| f['deleted_file'] }
        have_no_inline_diff_lines = satisfy('have no inline diff lines') do |diff_file|
          !diff_file.has_key?('highlighted_diff_lines')
        end

        expect(diff_files_without_deletions).to all(have_key('parallel_diff_lines'))
        expect(diff_files_without_deletions).to all(have_no_inline_diff_lines)
      end
    end

    context 'when the user cannot view the merge request' do
      before do
        project.team.truncate
        go
      end

      it 'returns a 404' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:merge_request) { create(:merge_request_with_diffs, target_project: project, source_project: project) }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  describe 'GET show' do
    def go(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: merge_request.iid,
        format: 'json'
      }

      get :show, params: params.merge(extra_params)
    end

    context 'with default params' do
      context 'for the same project' do
        before do
          allow(controller).to receive(:rendered_for_merge_request?).and_return(true)
        end

        it 'serializes merge request diff collection' do
          expect_next_instance_of(DiffsSerializer) do |instance|
            expect(instance).to receive(:represent).with(an_instance_of(Gitlab::Diff::FileCollection::MergeRequestDiff), an_instance_of(Hash))
          end

          go
        end
      end

      context 'when note is a legacy diff note' do
        before do
          create(:legacy_diff_note_on_merge_request, project: project, noteable: merge_request)
        end

        it 'serializes merge request diff collection' do
          expect_next_instance_of(DiffsSerializer) do |instance|
            expect(instance).to receive(:represent).with(an_instance_of(Gitlab::Diff::FileCollection::MergeRequestDiff), an_instance_of(Hash))
          end

          go
        end
      end

      it_behaves_like 'forked project with submodules'
    end

    it_behaves_like 'persisted preferred diff view cookie'
    it_behaves_like 'cached diff collection'
  end

  describe 'GET diffs_metadata' do
    def go(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: merge_request.iid,
        format: 'json'
      }

      get :diffs_metadata, params: params.merge(extra_params)
    end

    it_behaves_like '404 for unexistent diffable'

    context 'when not authorized' do
      let(:another_user) { create(:user) }

      before do
        sign_in(another_user)
      end

      it 'returns 404 when not a member' do
        go

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns 404 when visibility level is not enough' do
        project.add_guest(another_user)

        go

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with valid diff_id' do
      it 'returns success' do
        go(diff_id: merge_request.merge_request_diff.id)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'serializes diffs metadata with expected arguments' do
        expected_options = {
          environment: nil,
          merge_request: merge_request,
          merge_request_diff: merge_request.merge_request_diff,
          merge_request_diffs: merge_request.merge_request_diffs,
          start_version: nil,
          start_sha: nil,
          commit: nil,
          latest_diff: true
        }

        expect_next_instance_of(DiffsMetadataSerializer) do |instance|
          expect(instance).to receive(:represent)
            .with(an_instance_of(Gitlab::Diff::FileCollection::MergeRequestDiff), expected_options)
            .and_call_original
        end

        go(diff_id: merge_request.merge_request_diff.id)
      end
    end

    context 'with diff_head param passed' do
      before do
        allow(merge_request).to receive(:diffable_merge_ref?)
          .and_return(diffable_merge_ref)
      end

      context 'the merge request can be compared with head' do
        let(:diffable_merge_ref) { true }

        it 'compares diffs with the head' do
          MergeRequests::MergeToRefService.new(project, merge_request.author).execute(merge_request)

          expect(CompareService).to receive(:new).with(
            project, merge_request.merge_ref_head.sha
          ).and_call_original

          go(diff_head: true)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'the merge request cannot be compared with head' do
        let(:diffable_merge_ref) { false }

        it 'compares diffs with the base' do
          expect(CompareService).not_to receive(:new)

          go(diff_head: true)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'with MR regular diff params' do
      it 'returns success' do
        go

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'serializes diffs metadata with expected arguments' do
        expected_options = {
          environment: nil,
          merge_request: merge_request,
          merge_request_diff: merge_request.merge_request_diff,
          merge_request_diffs: merge_request.merge_request_diffs,
          start_version: nil,
          start_sha: nil,
          commit: nil,
          latest_diff: true
        }

        expect_next_instance_of(DiffsMetadataSerializer) do |instance|
          expect(instance).to receive(:represent)
            .with(an_instance_of(Gitlab::Diff::FileCollection::MergeRequestDiff), expected_options)
            .and_call_original
        end

        go
      end
    end

    context 'with commit param' do
      it 'returns success' do
        go(commit_id: merge_request.diff_head_sha)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'serializes diffs metadata with expected arguments' do
        expected_options = {
          environment: nil,
          merge_request: merge_request,
          merge_request_diff: nil,
          merge_request_diffs: merge_request.merge_request_diffs,
          start_version: nil,
          start_sha: nil,
          commit: merge_request.diff_head_commit,
          latest_diff: nil
        }

        expect_next_instance_of(DiffsMetadataSerializer) do |instance|
          expect(instance).to receive(:represent)
            .with(an_instance_of(Gitlab::Diff::FileCollection::Commit), expected_options)
            .and_call_original
        end

        go(commit_id: merge_request.diff_head_sha)
      end
    end
  end

  describe 'GET diff_for_path' do
    def diff_for_path(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: merge_request.iid,
        format: 'json'
      }

      get :diff_for_path, params: params.merge(extra_params)
    end

    let(:existing_path) { 'files/ruby/popen.rb' }

    context 'when the merge request exists' do
      context 'when the user can view the merge request' do
        context 'when the path exists in the diff' do
          it 'enables diff notes' do
            diff_for_path(old_path: existing_path, new_path: existing_path)

            expect(assigns(:diff_notes_disabled)).to be_falsey
            expect(assigns(:new_diff_note_attrs)).to eq(noteable_type: 'MergeRequest',
                                                        noteable_id: merge_request.id,
                                                        commit_id: nil)
          end

          it 'only renders the diffs for the path given' do
            diff_for_path(old_path: existing_path, new_path: existing_path)

            paths = json_response['diff_files'].map { |file| file['new_path'] }

            expect(paths).to include(existing_path)
          end
        end
      end

      context 'when the user cannot view the merge request' do
        before do
          project.team.truncate
          diff_for_path(old_path: existing_path, new_path: existing_path)
        end

        it 'returns a 404' do
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when the merge request does not exist' do
      before do
        diff_for_path(id: merge_request.iid.succ, old_path: existing_path, new_path: existing_path)
      end

      it 'returns a 404' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the merge request belongs to a different project' do
      let(:other_project) { create(:project) }

      before do
        other_project.add_maintainer(user)
        diff_for_path(old_path: existing_path, new_path: existing_path, project_id: other_project)
      end

      it 'returns a 404' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET diffs_batch' do
    shared_examples_for 'serializes diffs with expected arguments' do
      it 'serializes paginated merge request diff collection' do
        expect_next_instance_of(PaginatedDiffSerializer) do |instance|
          expect(instance).to receive(:represent)
            .with(an_instance_of(collection), expected_options)
            .and_call_original
        end

        subject
      end
    end

    shared_examples_for 'successful request' do
      it 'returns success' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    def collection_arguments(pagination_data = {})
      {
        merge_request: merge_request,
        diff_view: :inline,
        pagination_data: {
          current_page: nil,
          next_page: nil,
          total_pages: nil
        }.merge(pagination_data)
      }
    end

    def go(extra_params = {})
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: merge_request.iid,
        page: 1,
        per_page: 20,
        format: 'json'
      }

      get :diffs_batch, params: params.merge(extra_params)
    end

    it_behaves_like '404 for unexistent diffable'

    context 'when feature is disabled' do
      before do
        stub_feature_flags(diffs_batch_load: false)
      end

      it 'returns 404' do
        go

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when not authorized' do
      let(:other_user) { create(:user) }

      before do
        sign_in(other_user)
      end

      it 'returns 404' do
        go

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with valid diff_id' do
      subject { go(diff_id: merge_request.merge_request_diff.id) }

      it_behaves_like 'serializes diffs with expected arguments' do
        let(:collection) { Gitlab::Diff::FileCollection::MergeRequestDiffBatch }
        let(:expected_options) { collection_arguments(current_page: 1, total_pages: 1) }
      end

      it_behaves_like 'successful request'
    end

    context 'with commit_id param' do
      subject { go(commit_id: merge_request.diff_head_sha) }

      it_behaves_like 'serializes diffs with expected arguments' do
        let(:collection) { Gitlab::Diff::FileCollection::Commit }
        let(:expected_options) { collection_arguments }
      end
    end

    context 'with diff_id and start_sha params' do
      subject do
        go(diff_id: merge_request.merge_request_diff.id,
           start_sha: merge_request.merge_request_diff.start_commit_sha)
      end

      it_behaves_like 'serializes diffs with expected arguments' do
        let(:collection) { Gitlab::Diff::FileCollection::Compare }
        let(:expected_options) { collection_arguments }
      end

      it_behaves_like 'successful request'
    end

    context 'with default params' do
      subject { go }

      it_behaves_like 'serializes diffs with expected arguments' do
        let(:collection) { Gitlab::Diff::FileCollection::MergeRequestDiffBatch }
        let(:expected_options) { collection_arguments(current_page: 1, total_pages: 1) }
      end

      it_behaves_like 'successful request'
    end

    context 'with smaller diff batch params' do
      subject { go(page: 2, per_page: 5) }

      it_behaves_like 'serializes diffs with expected arguments' do
        let(:collection) { Gitlab::Diff::FileCollection::MergeRequestDiffBatch }
        let(:expected_options) { collection_arguments(current_page: 2, next_page: 3, total_pages: 4) }
      end

      it_behaves_like 'successful request'
    end

    it_behaves_like 'forked project with submodules'
    it_behaves_like 'persisted preferred diff view cookie'
    it_behaves_like 'cached diff collection'

    context 'diff unfolding' do
      let!(:unfoldable_diff_note) do
        create(:diff_note_on_merge_request, :folded_position, project: project, noteable: merge_request)
      end

      let!(:diff_note) do
        create(:diff_note_on_merge_request, project: project, noteable: merge_request)
      end

      it 'unfolds correct diff file positions' do
        expect_next_instance_of(Gitlab::Diff::FileCollection::MergeRequestDiffBatch) do |instance|
          expect(instance)
            .to receive(:unfold_diff_files)
            .with([unfoldable_diff_note.position])
            .and_call_original
        end

        go
      end
    end
  end
end

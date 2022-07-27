# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PaginatedDiffEntity do
  let(:user) { create(:user) }
  let(:request) { double('request', current_user: user) }
  let(:merge_request) { create(:merge_request) }
  let(:diff_batch) { merge_request.merge_request_diff.diffs_in_batch(2, 3, diff_options: nil) }
  let(:allow_tree_conflicts) { false }
  let(:options) do
    {
      request: request,
      merge_request: merge_request,
      pagination_data: diff_batch.pagination_data,
      allow_tree_conflicts: allow_tree_conflicts
    }
  end

  let(:entity) { described_class.new(diff_batch, options) }

  subject { entity.as_json }

  it 'exposes diff_files' do
    expect(subject[:diff_files]).to be_present
  end

  it 'exposes pagination data' do
    expect(subject[:pagination]).to eq(total_pages: 20)
  end

  context 'when there are conflicts' do
    let(:diff_batch) { merge_request.merge_request_diff.diffs_in_batch(7, 3, diff_options: nil) }
    let(:diff_files) { diff_batch.diff_files.to_a }
    let(:diff_file_with_conflict) { diff_files.last }
    let(:diff_file_without_conflict) { diff_files.first }

    let(:resolvable_conflicts) { true }
    let(:conflict_file) { double(path: diff_file_with_conflict.new_path, conflict_type: :both_modified) }
    let(:conflicts) { double(conflicts: double(files: [conflict_file]), can_be_resolved_in_ui?: resolvable_conflicts) }

    let(:merge_ref_head_diff) { true }
    let(:options) { super().merge(merge_ref_head_diff: merge_ref_head_diff) }

    before do
      allow(merge_request).to receive(:cannot_be_merged?).and_return(true)
      allow(MergeRequests::Conflicts::ListService).to receive(:new).and_return(conflicts)
    end

    it 'conflicts are highlighted' do
      expect(conflict_file).to receive(:diff_lines_for_serializer)
      expect(diff_file_with_conflict).not_to receive(:diff_lines_for_serializer)
      expect(diff_file_without_conflict).to receive(:diff_lines_for_serializer).twice # for highlighted_diff_lines and is_fully_expanded

      subject
    end

    context 'merge ref head diff is not chosen to be displayed' do
      let(:merge_ref_head_diff) { false }

      it 'conflicts are not calculated' do
        expect(MergeRequests::Conflicts::ListService).not_to receive(:new)
      end
    end

    context 'when conflicts cannot be resolved' do
      let(:resolvable_conflicts) { false }

      it 'conflicts are not highlighted' do
        expect(conflict_file).not_to receive(:diff_lines_for_serializer)
        expect(diff_file_with_conflict).to receive(:diff_lines_for_serializer).twice  # for highlighted_diff_lines and is_fully_expanded
        expect(diff_file_without_conflict).to receive(:diff_lines_for_serializer).twice # for highlighted_diff_lines and is_fully_expanded

        subject
      end

      context 'when allow_tree_conflicts is set to true' do
        let(:allow_tree_conflicts) { true }

        it 'conflicts are still highlighted' do
          expect(conflict_file).to receive(:diff_lines_for_serializer)
          expect(diff_file_with_conflict).not_to receive(:diff_lines_for_serializer)
          expect(diff_file_without_conflict).to receive(:diff_lines_for_serializer).twice # for highlighted_diff_lines and is_fully_expanded

          subject
        end
      end
    end
  end
end

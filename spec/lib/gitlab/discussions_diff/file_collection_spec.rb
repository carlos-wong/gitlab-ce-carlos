# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::DiscussionsDiff::FileCollection do
  let(:merge_request) { create(:merge_request) }
  let!(:diff_note_a) { create(:diff_note_on_merge_request, project: merge_request.project, noteable: merge_request) }
  let!(:diff_note_b) { create(:diff_note_on_merge_request, project: merge_request.project, noteable: merge_request) }
  let(:note_diff_file_a) { diff_note_a.note_diff_file }
  let(:note_diff_file_b) { diff_note_b.note_diff_file }

  subject { described_class.new([note_diff_file_a, note_diff_file_b]) }

  describe '#load_highlight', :clean_gitlab_redis_shared_state do
    it 'writes uncached diffs highlight' do
      file_a_caching_content = diff_note_a.diff_file.highlighted_diff_lines.map(&:to_hash)
      file_b_caching_content = diff_note_b.diff_file.highlighted_diff_lines.map(&:to_hash)

      expect(Gitlab::DiscussionsDiff::HighlightCache)
        .to receive(:write_multiple)
        .with({ note_diff_file_a.id => file_a_caching_content,
                note_diff_file_b.id => file_b_caching_content })
        .and_call_original

      subject.load_highlight
    end

    it 'does not write cache for already cached file' do
      file_a_caching_content = diff_note_a.diff_file.highlighted_diff_lines.map(&:to_hash)
      Gitlab::DiscussionsDiff::HighlightCache
        .write_multiple({ note_diff_file_a.id => file_a_caching_content })

      file_b_caching_content = diff_note_b.diff_file.highlighted_diff_lines.map(&:to_hash)

      expect(Gitlab::DiscussionsDiff::HighlightCache)
        .to receive(:write_multiple)
        .with({ note_diff_file_b.id => file_b_caching_content })
        .and_call_original

      subject.load_highlight
    end

    it 'does not write cache for resolved notes' do
      diff_note_a.update_column(:resolved_at, Time.now)

      file_b_caching_content = diff_note_b.diff_file.highlighted_diff_lines.map(&:to_hash)

      expect(Gitlab::DiscussionsDiff::HighlightCache)
        .to receive(:write_multiple)
        .with({ note_diff_file_b.id => file_b_caching_content })
        .and_call_original

      subject.load_highlight
    end

    it 'loaded diff files have highlighted lines loaded' do
      subject.load_highlight

      diff_file_a = subject.find_by_id(note_diff_file_a.id)
      diff_file_b = subject.find_by_id(note_diff_file_b.id)

      expect(diff_file_a).to be_highlight_loaded
      expect(diff_file_b).to be_highlight_loaded
    end

    it 'not loaded diff files does not have highlighted lines loaded' do
      diff_note_a.update_column(:resolved_at, Time.now)

      subject.load_highlight

      diff_file_a = subject.find_by_id(note_diff_file_a.id)
      diff_file_b = subject.find_by_id(note_diff_file_b.id)

      expect(diff_file_a).not_to be_highlight_loaded
      expect(diff_file_b).to be_highlight_loaded
    end
  end
end

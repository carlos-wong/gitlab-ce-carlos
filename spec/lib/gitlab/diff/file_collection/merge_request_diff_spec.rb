# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Diff::FileCollection::MergeRequestDiff do
  let(:merge_request) { create(:merge_request) }
  let(:diffable) { merge_request.merge_request_diff }
  let(:subject) { described_class.new(diffable, diff_options: nil) }
  let(:diff_files) { subject.diff_files }

  describe '#diff_files' do
    it 'does not highlight binary files' do
      allow_next_instance_of(Gitlab::Diff::File) do |instance|
        allow(instance).to receive(:text?).and_return(false)
      end

      expect_next_instance_of(Gitlab::Diff::File) do |instance|
        expect(instance).not_to receive(:highlighted_diff_lines)
      end

      diff_files
    end

    it 'does not highlight files marked as undiffable in .gitattributes' do
      allow_next_instance_of(Gitlab::Diff::File) do |instance|
        allow(instance).to receive(:diffable?).and_return(false)
      end

      expect_next_instance_of(Gitlab::Diff::File) do |instance|
        expect(instance).not_to receive(:highlighted_diff_lines)
      end

      diff_files
    end
  end

  it_behaves_like 'unfoldable diff' do
    let(:diffable) { merge_request.merge_request_diff }
  end

  context 'using Gitlab::Diff::DeprecatedHighlightCache' do
    before do
      stub_feature_flags(hset_redis_diff_caching: false)
    end

    it 'uses a different cache key if diff line keys change' do
      mr_diff = described_class.new(merge_request.merge_request_diff, diff_options: nil)
      key = mr_diff.cache_key

      stub_const('Gitlab::Diff::Line::SERIALIZE_KEYS', [:foo])

      expect(mr_diff.cache_key).not_to eq(key)
    end
  end

  it_behaves_like 'diff statistics' do
    let(:collection_default_args) do
      { diff_options: {} }
    end
    let(:diffable) { merge_request.merge_request_diff }
    let(:stub_path) { '.gitignore' }
  end

  it_behaves_like 'cacheable diff collection' do
    let(:cacheable_files_count) { diffable.size.to_i }
  end

  it 'returns a valid instance of a DiffCollection' do
    expect(diff_files).to be_a(Gitlab::Git::DiffCollection)
  end
end

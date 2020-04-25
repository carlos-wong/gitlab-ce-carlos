# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Diff::HighlightCache, :clean_gitlab_redis_cache do
  let(:merge_request) { create(:merge_request_with_diffs) }
  let(:diff_hash) do
    { ".gitignore-false-false-false" =>
      [{ line_code: nil, rich_text: nil, text: "@@ -17,3 +17,4 @@ rerun.txt", type: "match", index: 0, old_pos: 17, new_pos: 17 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_17_17",
        rich_text: " <span id=\"LC17\" class=\"line\" lang=\"plaintext\">pickle-email-*.html</span>\n",
        text: " pickle-email-*.html",
        type: nil,
        index: 1,
        old_pos: 17,
        new_pos: 17 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_18_18",
        rich_text: " <span id=\"LC18\" class=\"line\" lang=\"plaintext\">.project</span>\n",
        text: " .project",
        type: nil,
        index: 2,
        old_pos: 18,
        new_pos: 18 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_19_19",
        rich_text: " <span id=\"LC19\" class=\"line\" lang=\"plaintext\">config/initializers/secret_token.rb</span>\n",
        text: " config/initializers/secret_token.rb",
        type: nil,
        index: 3,
        old_pos: 19,
        new_pos: 19 },
       { line_code: "a5cc2925ca8258af241be7e5b0381edf30266302_20_20",
        rich_text: "+<span id=\"LC20\" class=\"line\" lang=\"plaintext\">.DS_Store</span>",
        text: "+.DS_Store",
        type: "new",
        index: 4,
        old_pos: 20,
        new_pos: 20 }] }
  end

  let(:cache_key) { cache.key }

  subject(:cache) { described_class.new(merge_request.diffs) }

  describe '#decorate' do
    # Manually creates a Diff::File object to avoid triggering the cache on
    # the FileCollection::MergeRequestDiff
    let(:diff_file) do
      diffs = merge_request.diffs
      raw_diff = diffs.diffable.raw_diffs(diffs.diff_options.merge(paths: ['CHANGELOG'])).first
      Gitlab::Diff::File.new(raw_diff,
                             repository: diffs.project.repository,
                             diff_refs: diffs.diff_refs,
                             fallback_diff_refs: diffs.fallback_diff_refs)
    end

    it 'does not calculate highlighting when reading from cache' do
      cache.write_if_empty
      cache.decorate(diff_file)

      expect_any_instance_of(Gitlab::Diff::Highlight).not_to receive(:highlight)

      diff_file.highlighted_diff_lines
    end

    it 'assigns highlighted diff lines to the DiffFile' do
      cache.write_if_empty
      cache.decorate(diff_file)

      expect(diff_file.highlighted_diff_lines.size).to be > 5
    end

    it 'assigns highlighted diff lines which rich_text are HTML-safe' do
      cache.write_if_empty
      cache.decorate(diff_file)

      rich_texts = diff_file.highlighted_diff_lines.map(&:rich_text)

      expect(rich_texts).to all(be_html_safe)
    end
  end

  shared_examples 'caches missing entries' do
    it 'filters the key/value list of entries to be caches for each invocation' do
      expect(cache).to receive(:write_to_redis_hash)
        .with(hash_including(*paths))
        .once
        .and_call_original

      2.times { cache.write_if_empty }
    end

    it 'reads from cache once' do
      expect(cache).to receive(:read_cache).once.and_call_original

      cache.write_if_empty
    end
  end

  describe '#write_if_empty' do
    it_behaves_like 'caches missing entries' do
      let(:paths) { merge_request.diffs.raw_diff_files.select(&:text?).map(&:file_path) }
    end

    context 'different diff_collections for the same diffable' do
      before do
        cache.write_if_empty
      end

      it 'writes an uncached files in the collection to the same redis hash' do
        Gitlab::Redis::Cache.with { |r| r.hdel(cache_key, "files/whitespace") }

        expect { cache.write_if_empty }
          .to change { Gitlab::Redis::Cache.with { |r| r.hgetall(cache_key) } }
      end
    end

    context 'when cache initialized with MergeRequestDiffBatch' do
      let(:merge_request_diff_batch) do
        Gitlab::Diff::FileCollection::MergeRequestDiffBatch.new(
          merge_request.merge_request_diff,
          1,
          10,
          diff_options: nil)
      end

      it_behaves_like 'caches missing entries' do
        let(:cache) { described_class.new(merge_request_diff_batch) }
        let(:paths) { merge_request_diff_batch.raw_diff_files.select(&:text?).map(&:file_path) }
      end
    end
  end

  describe '#write_to_redis_hash' do
    it 'creates or updates a Redis hash' do
      expect { cache.send(:write_to_redis_hash, diff_hash) }
        .to change { Gitlab::Redis::Cache.with { |r| r.hgetall(cache_key) } }
    end
  end

  describe '#clear' do
    it 'clears cache' do
      expect_any_instance_of(Redis).to receive(:del).with(cache_key)

      cache.clear
    end
  end

  describe 'metrics' do
    it 'defines :gitlab_redis_diff_caching_memory_usage_bytes histogram' do
      expect(described_class).to respond_to(:gitlab_redis_diff_caching_memory_usage_bytes)
    end
  end
end

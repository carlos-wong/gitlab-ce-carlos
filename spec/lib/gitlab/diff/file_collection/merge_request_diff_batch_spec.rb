# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Diff::FileCollection::MergeRequestDiffBatch do
  let(:merge_request) { create(:merge_request) }
  let(:batch_page) { 1 }
  let(:batch_size) { 10 }
  let(:diffable) { merge_request.merge_request_diff }
  let(:diff_files_relation) { diffable.merge_request_diff_files }

  subject do
    described_class.new(diffable,
                        batch_page,
                        batch_size,
                        diff_options: nil)
  end

  let(:diff_files) { subject.diff_files }

  describe 'initialize' do
    it 'memoizes pagination_data' do
      expect(subject.pagination_data).to eq(current_page: 1, next_page: 2, total_pages: 2)
    end
  end

  describe '#diff_files' do
    let(:batch_size) { 3 }
    let(:paginated_rel) { diff_files_relation.page(batch_page).per(batch_size) }

    let(:expected_batch_files) do
      paginated_rel.map(&:new_path)
    end

    it 'returns paginated diff files' do
      expect(diff_files.size).to eq(3)
    end

    it 'returns a valid instance of a DiffCollection' do
      expect(diff_files).to be_a(Gitlab::Git::DiffCollection)
    end

    context 'first page' do
      it 'returns correct diff files' do
        expect(diff_files.map(&:new_path)).to eq(expected_batch_files)
      end
    end

    context 'another page' do
      let(:batch_page) { 2 }

      it 'returns correct diff files' do
        expect(diff_files.map(&:new_path)).to eq(expected_batch_files)
      end
    end

    context 'nil batch_page' do
      let(:batch_page) { nil }

      it 'returns correct diff files' do
        expected_batch_files =
          diff_files_relation.page(described_class::DEFAULT_BATCH_PAGE).per(batch_size).map(&:new_path)

        expect(diff_files.map(&:new_path)).to eq(expected_batch_files)
      end
    end

    context 'nil batch_size' do
      let(:batch_size) { nil }

      it 'returns correct diff files' do
        expected_batch_files =
          diff_files_relation.page(batch_page).per(described_class::DEFAULT_BATCH_SIZE).map(&:new_path)

        expect(diff_files.map(&:new_path)).to eq(expected_batch_files)
      end
    end

    context 'invalid page' do
      let(:batch_page) { 999 }

      it 'returns correct diff files' do
        expect(diff_files.map(&:new_path)).to be_empty
      end
    end

    context 'last page' do
      it 'returns correct diff files' do
        last_page = paginated_rel.total_pages
        collection = described_class.new(diffable,
                                         last_page,
                                         batch_size,
                                         diff_options: nil)

        expected_batch_files = diff_files_relation.page(last_page).per(batch_size).map(&:new_path)

        expect(collection.diff_files.map(&:new_path)).to eq(expected_batch_files)
      end
    end
  end

  it_behaves_like 'unfoldable diff' do
    subject do
      described_class.new(merge_request.merge_request_diff,
                          batch_page,
                          batch_size,
                          diff_options: nil)
    end
  end

  it_behaves_like 'diff statistics' do
    let(:collection_default_args) do
      { diff_options: {} }
    end

    let(:diffable) { merge_request.merge_request_diff }
    let(:stub_path) { '.gitignore' }

    subject do
      described_class.new(merge_request.merge_request_diff,
                          batch_page,
                          batch_size,
                          collection_default_args)
    end
  end
end

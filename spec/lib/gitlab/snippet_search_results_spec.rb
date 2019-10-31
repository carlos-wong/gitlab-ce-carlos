# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::SnippetSearchResults do
  include SearchHelpers

  let!(:snippet) { create(:snippet, content: 'foo', file_name: 'foo') }
  let(:results) { described_class.new(snippet.author, 'foo') }

  describe '#snippet_titles_count' do
    it 'returns the amount of matched snippet titles' do
      expect(results.limited_snippet_titles_count).to eq(1)
    end
  end

  describe '#snippet_blobs_count' do
    it 'returns the amount of matched snippet blobs' do
      expect(results.limited_snippet_blobs_count).to eq(1)
    end
  end

  describe '#formatted_count' do
    using RSpec::Parameterized::TableSyntax

    where(:scope, :count_method, :expected) do
      'snippet_titles' | :limited_snippet_titles_count   | max_limited_count
      'snippet_blobs'  | :limited_snippet_blobs_count    | max_limited_count
      'projects'       | :limited_projects_count         | max_limited_count
      'unknown'        | nil                             | nil
    end

    with_them do
      it 'returns the expected formatted count' do
        expect(results).to receive(count_method).and_return(1234) if count_method
        expect(results.formatted_count(scope)).to eq(expected)
      end
    end
  end
end

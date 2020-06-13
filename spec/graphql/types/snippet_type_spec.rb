# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['Snippet'] do
  it 'has the correct fields' do
    expected_fields = [:id, :title, :project, :author,
                       :file_name, :description,
                       :visibility_level, :created_at, :updated_at,
                       :web_url, :raw_url, :notes, :discussions,
                       :user_permissions, :description_html, :blob]

    is_expected.to have_graphql_fields(*expected_fields)
  end

  describe 'authorizations' do
    it { expect(described_class).to require_graphql_authorizations(:read_snippet) }
  end

  describe '#blob' do
    let_it_be(:user) { create(:user) }
    let(:query_blob) { subject.dig('data', 'snippets', 'edges')[0]['node']['blob'] }
    let(:query) do
      %(
        {
          snippets {
            edges {
              node {
                blob {
                  name
                  path
                }
              }
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    context 'when snippet has repository' do
      let!(:snippet) { create(:personal_snippet, :repository, :public, author: user) }
      let(:blob) { snippet.blobs.first }

      it 'returns blob from the repository' do
        expect(query_blob['name']).to eq blob.name
        expect(query_blob['path']).to eq blob.path
      end
    end

    context 'when snippet does not have a repository' do
      let!(:snippet) { create(:personal_snippet, :public, author: user) }
      let(:blob) { snippet.blob }

      it 'returns SnippetBlob type' do
        expect(query_blob['name']).to eq blob.name
        expect(query_blob['path']).to eq blob.path
      end
    end
  end
end

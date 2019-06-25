require 'spec_helper'

describe 'GitlabSchema configurations' do
  include GraphqlHelpers

  set(:project) { create(:project) }

  shared_examples 'imposing query limits' do
    describe '#max_complexity' do
      context 'when complexity is too high' do
        it 'shows an error' do
          allow(GitlabSchema).to receive(:max_query_complexity).and_return 1

          subject

          expect(graphql_errors.flatten.first['message']).to include('which exceeds max complexity of 1')
        end
      end
    end

    describe '#max_depth' do
      context 'when query depth is too high' do
        it 'shows error' do
          errors = { "message" => "Query has depth of 2, which exceeds max depth of 1" }
          allow(GitlabSchema).to receive(:max_query_depth).and_return 1

          subject

          expect(graphql_errors.flatten).to include(errors)
        end
      end

      context 'when query depth is within range' do
        it 'has no error' do
          allow(GitlabSchema).to receive(:max_query_depth).and_return 5

          subject

          expect(Array.wrap(graphql_errors).compact).to be_empty
        end
      end
    end
  end

  context 'regular queries' do
    subject do
      query = graphql_query_for('project', { 'fullPath' => project.full_path }, %w(id name description))
      post_graphql(query)
    end

    it_behaves_like 'imposing query limits'
  end

  context 'multiplexed queries' do
    let(:current_user) { nil }

    subject do
      queries = [
        { query: graphql_query_for('project', { 'fullPath' => '$fullPath' }, %w(id name description)) },
        { query: graphql_query_for('echo', { 'text' => "$test" }, []), variables: { "test" => "Hello world" } },
        { query: graphql_query_for('project', { 'fullPath' => project.full_path }, "userPermissions { createIssue }") }
      ]

      post_multiplex(queries, current_user: current_user)
    end

    it 'does not authenticate all queries' do
      subject

      expect(json_response.last['data']['project']).to be_nil
    end

    it_behaves_like 'imposing query limits' do
      it "fails all queries when only one of the queries is too complex" do
        # The `project` query above has a complexity of 5
        allow(GitlabSchema).to receive(:max_query_complexity).and_return 4

        subject

        # Expect a response for each query, even though it will be empty
        expect(json_response.size).to eq(3)
        json_response.each do |single_query_response|
          expect(single_query_response).not_to have_key('data')
        end

        # Expect errors for each query
        expect(graphql_errors.size).to eq(3)
        graphql_errors.each do |single_query_errors|
          expect(single_query_errors.first['message']).to include('which exceeds max complexity of 4')
        end
      end
    end

    context 'authentication' do
      let(:current_user) { project.owner }

      it 'authenticates all queries' do
        subject

        expect(json_response.last['data']['project']['userPermissions']['createIssue']).to be(true)
      end
    end
  end

  context 'when IntrospectionQuery' do
    it 'is not too complex' do
      query = File.read(Rails.root.join('spec/fixtures/api/graphql/introspection.graphql'))

      post_graphql(query, current_user: nil)

      expect(graphql_errors).to be_nil
    end
  end

  context 'logging' do
    let(:query) { File.read(Rails.root.join('spec/fixtures/api/graphql/introspection.graphql')) }

    it 'logs the query complexity and depth' do
      analyzer_memo = {
        query_string: query,
        variables: {}.to_s,
        complexity: 181,
        depth: 0,
        duration: 7
      }

      expect_any_instance_of(Gitlab::Graphql::QueryAnalyzers::LoggerAnalyzer).to receive(:duration).and_return(7)
      expect(Gitlab::GraphqlLogger).to receive(:info).with(analyzer_memo)

      post_graphql(query, current_user: nil)
    end

    it 'logs using `format_message`' do
      expect_any_instance_of(Gitlab::GraphqlLogger).to receive(:format_message)

      post_graphql(query, current_user: nil)
    end
  end

  context "global id's" do
    it 'uses GlobalID to expose ids' do
      post_graphql(graphql_query_for('project', { 'fullPath' => project.full_path }, %w(id)),
                   current_user: project.owner)

      parsed_id = GlobalID.parse(graphql_data['project']['id'])

      expect(parsed_id).to eq(project.to_global_id)
    end
  end
end

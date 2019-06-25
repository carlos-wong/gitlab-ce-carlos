# frozen_string_literal: true

require 'spec_helper'

# Based on spec/requests/api/groups_spec.rb
# Should follow closely in order to ensure all situations are covered
describe 'getting group information' do
  include GraphqlHelpers
  include UploadHelpers

  let(:user1)         { create(:user, can_create_group: false) }
  let(:user2)         { create(:user) }
  let(:admin)         { create(:admin) }
  let(:public_group)  { create(:group, :public) }
  let(:private_group) { create(:group, :private) }

  # similar to the API "GET /groups/:id"
  describe "Query group(fullPath)" do
    def group_query(group)
      graphql_query_for('group', 'fullPath' => group.full_path)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(group_query(public_group))
      end
    end

    context 'when unauthenticated' do
      it 'returns nil for a private group' do
        post_graphql(group_query(private_group))

        expect(graphql_data['group']).to be_nil
      end

      it 'returns a public group' do
        post_graphql(group_query(public_group))

        expect(graphql_data['group']).not_to be_nil
      end
    end

    context "when authenticated as user" do
      let!(:group1) { create(:group, avatar: File.open(uploaded_image_temp_path)) }
      let!(:group2) { create(:group, :private) }

      before do
        group1.add_owner(user1)
        group2.add_owner(user2)
      end

      it "returns one of user1's groups" do
        project = create(:project, namespace: group2, path: 'Foo')
        create(:project_group_link, project: project, group: group1)

        post_graphql(group_query(group1), current_user: user1)

        expect(response).to have_gitlab_http_status(200)
        expect(graphql_data['group']['id']).to eq(group1.to_global_id.to_s)
        expect(graphql_data['group']['name']).to eq(group1.name)
        expect(graphql_data['group']['path']).to eq(group1.path)
        expect(graphql_data['group']['description']).to eq(group1.description)
        expect(graphql_data['group']['visibility']).to eq(Gitlab::VisibilityLevel.string_level(group1.visibility_level))
        expect(graphql_data['group']['avatarUrl']).to eq(group1.avatar_url(only_path: false))
        expect(graphql_data['group']['webUrl']).to eq(group1.web_url)
        expect(graphql_data['group']['requestAccessEnabled']).to eq(group1.request_access_enabled)
        expect(graphql_data['group']['fullName']).to eq(group1.full_name)
        expect(graphql_data['group']['fullPath']).to eq(group1.full_path)
        expect(graphql_data['group']['parentId']).to eq(group1.parent_id)
      end

      it "does not return a non existing group" do
        query = graphql_query_for('group', 'fullPath' => '1328')

        post_graphql(query, current_user: user1)

        expect(graphql_data['group']).to be_nil
      end

      it "does not return a group not attached to user1" do
        private_group.add_owner(user2)

        post_graphql(group_query(private_group), current_user: user1)

        expect(graphql_data['group']).to be_nil
      end

      it 'avoids N+1 queries' do
        control_count = ActiveRecord::QueryRecorder.new do
          post_graphql(group_query(group1), current_user: admin)
        end.count

        queries = [{ query: group_query(group1) },
                   { query: group_query(group2) }]

        expect do
          post_multiplex(queries, current_user: admin)
        end.not_to exceed_query_limit(control_count)

        expect(graphql_errors).to contain_exactly(nil, nil)
      end
    end

    context "when authenticated as admin" do
      it "returns any existing group" do
        post_graphql(group_query(private_group), current_user: admin)

        expect(graphql_data['group']['name']).to eq(private_group.name)
      end

      it "does not return a non existing group" do
        query = graphql_query_for('group', 'fullPath' => '1328')
        post_graphql(query, current_user: admin)

        expect(graphql_data['group']).to be_nil
      end
    end
  end
end

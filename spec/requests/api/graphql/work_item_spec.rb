# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.work_item(id)' do
  include GraphqlHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:work_item) { create(:work_item, project: project, description: '- List item', weight: 1) }
  let_it_be(:child_item1) { create(:work_item, :task, project: project) }
  let_it_be(:child_item2) { create(:work_item, :task, confidential: true, project: project) }
  let_it_be(:child_link1) { create(:parent_link, work_item_parent: work_item, work_item: child_item1) }
  let_it_be(:child_link2) { create(:parent_link, work_item_parent: work_item, work_item: child_item2) }

  let(:current_user) { developer }
  let(:work_item_data) { graphql_data['workItem'] }
  let(:work_item_fields) { all_graphql_fields_for('WorkItem') }
  let(:global_id) { work_item.to_gid.to_s }

  let(:query) do
    graphql_query_for('workItem', { 'id' => global_id }, work_item_fields)
  end

  context 'when the user can read the work item' do
    before do
      project.add_developer(developer)
      project.add_guest(guest)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a working graphql query'

    it 'returns all fields' do
      expect(work_item_data).to include(
        'description' => work_item.description,
        'id' => work_item.to_gid.to_s,
        'iid' => work_item.iid.to_s,
        'lockVersion' => work_item.lock_version,
        'state' => "OPEN",
        'title' => work_item.title,
        'workItemType' => hash_including('id' => work_item.work_item_type.to_gid.to_s),
        'userPermissions' => { 'readWorkItem' => true, 'updateWorkItem' => true, 'deleteWorkItem' => false }
      )
    end

    context 'when querying widgets' do
      describe 'description widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetDescription {
                description
                descriptionHtml
              }
            }
          GRAPHQL
        end

        it 'returns widget information' do
          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'DESCRIPTION',
                'description' => work_item.description,
                'descriptionHtml' => ::MarkupHelper.markdown_field(work_item, :description, {})
              )
            )
          )
        end
      end

      describe 'hierarchy widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetHierarchy {
                parent {
                  id
                }
                children {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        it 'returns widget information' do
          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'HIERARCHY',
                'parent' => nil,
                'children' => { 'nodes' => match_array([
                  hash_including('id' => child_link1.work_item.to_gid.to_s),
                  hash_including('id' => child_link2.work_item.to_gid.to_s)
                ]) }
              )
            )
          )
        end

        it 'avoids N+1 queries' do
          post_graphql(query, current_user: current_user) # warm up

          control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end

          create_list(:parent_link, 3, work_item_parent: work_item)

          expect do
            post_graphql(query, current_user: current_user)
          end.not_to exceed_all_query_limit(control_count)
        end

        context 'when user is guest' do
          let(:current_user) { guest }

          it 'filters out not accessible children or parent' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'HIERARCHY',
                  'parent' => nil,
                  'children' => { 'nodes' => match_array([
                    hash_including('id' => child_link1.work_item.to_gid.to_s)
                  ]) }
                )
              )
            )
          end
        end

        context 'when requesting child item' do
          let_it_be(:work_item) { create(:work_item, :task, project: project, description: '- List item') }
          let_it_be(:parent_link) { create(:parent_link, work_item: work_item) }

          it 'returns parent information' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'HIERARCHY',
                  'parent' => hash_including('id' => parent_link.work_item_parent.to_gid.to_s),
                  'children' => { 'nodes' => match_array([]) }
                )
              )
            )
          end
        end
      end

      describe 'weight widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetWeight {
                weight
              }
            }
          GRAPHQL
        end

        it 'returns widget information' do
          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'WEIGHT',
                'weight' => work_item.weight
              )
            )
          )
        end
      end

      describe 'assignees widget' do
        let(:assignees) { create_list(:user, 2) }
        let(:work_item) { create(:work_item, project: project, assignees: assignees) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetAssignees {
                allowsMultipleAssignees
                canInviteMembers
                assignees {
                  nodes {
                    id
                    username
                  }
                }
              }
            }
          GRAPHQL
        end

        it 'returns widget information' do
          expect(work_item_data).to include(
            'id' => work_item.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'type' => 'ASSIGNEES',
                'allowsMultipleAssignees' => boolean,
                'canInviteMembers' => boolean,
                'assignees' => {
                  'nodes' => match_array(
                    assignees.map { |a| { 'id' => a.to_gid.to_s, 'username' => a.username } }
                  )
                }
              )
            )
          )
        end
      end
    end

    context 'when an Issue Global ID is provided' do
      let(:global_id) { Issue.find(work_item.id).to_gid.to_s }

      it 'allows an Issue GID as input' do
        expect(work_item_data).to include('id' => work_item.to_gid.to_s)
      end
    end
  end

  context 'when the user can not read the work item' do
    let(:current_user) { create(:user) }

    before do
      post_graphql(query)
    end

    it 'returns an access error' do
      expect(work_item_data).to be_nil
      expect(graphql_errors).to contain_exactly(
        hash_including('message' => ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
      )
    end
  end

  context 'when the work_items feature flag is disabled' do
    before do
      stub_feature_flags(work_items: false)
    end

    it 'returns nil' do
      post_graphql(query)

      expect(work_item_data).to be_nil
    end
  end
end

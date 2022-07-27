# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a work item' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user).tap { |user| project.add_developer(user) } }

  let(:input) do
    {
      'title' => 'new title',
      'description' => 'new description',
      'workItemTypeId' => WorkItems::Type.default_by_type(:task).to_global_id.to_s
    }
  end

  let(:mutation) { graphql_mutation(:workItemCreate, input.merge('projectPath' => project.full_path)) }

  let(:mutation_response) { graphql_mutation_response(:work_item_create) }

  context 'the user is not allowed to create a work item' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user has permissions to create a work item' do
    let(:current_user) { developer }

    it 'creates the work item' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change(WorkItem, :count).by(1)

      created_work_item = WorkItem.last

      expect(response).to have_gitlab_http_status(:success)
      expect(created_work_item.issue_type).to eq('task')
      expect(created_work_item.work_item_type.base_type).to eq('task')
      expect(mutation_response['workItem']).to include(
        input.except('workItemTypeId').merge(
          'id' => created_work_item.to_global_id.to_s,
          'workItemType' => hash_including('name' => 'Task')
        )
      )
    end

    context 'when input is invalid' do
      let(:input) { { 'title' => '', 'workItemTypeId' => WorkItems::Type.default_by_type(:task).to_global_id.to_s } }

      it 'does not create and returns validation errors' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to not_change(WorkItem, :count)

        expect(graphql_mutation_response(:work_item_create)['errors']).to contain_exactly("Title can't be blank")
      end
    end

    it_behaves_like 'has spam protection' do
      let(:mutation_class) { ::Mutations::WorkItems::Create }
    end

    context 'with hierarchy widget input' do
      let(:widgets_response) { mutation_response['workItem']['widgets'] }
      let(:fields) do
        <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetHierarchy {
              parent {
                id
              }
              children {
                edges {
                  node {
                    id
                  }
                }
              }
            }
          }
        }
        errors
        FIELDS
      end

      let(:mutation) { graphql_mutation(:workItemCreate, input.merge('projectPath' => project.full_path), fields) }

      context 'when setting parent' do
        let_it_be(:parent) { create(:work_item, project: project) }

        let(:input) do
          {
            title: 'item1',
            workItemTypeId: WorkItems::Type.default_by_type(:task).to_global_id.to_s,
            hierarchyWidget: { 'parentId' => parent.to_global_id.to_s }
          }
        end

        it 'updates the work item parent' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(widgets_response).to include(
            {
              'children' => { 'edges' => [] },
              'parent' => { 'id' => parent.to_global_id.to_s },
              'type' => 'HIERARCHY'
            }
          )
        end

        context 'when parent work item type is invalid' do
          let_it_be(:parent) { create(:work_item, :task, project: project) }

          it 'returns error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['errors'])
              .to contain_exactly(/cannot be added: only Issue and Incident can be parent of Task./)
            expect(mutation_response['workItem']).to be_nil
          end
        end

        context 'when parent work item is not found' do
          let_it_be(:parent) { build_stubbed(:work_item, id: non_existing_record_id)}

          it 'returns a top level error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(graphql_errors.first['message']).to include('No object found for `parentId')
          end
        end
      end

      context 'when unsupported widget input is sent' do
        let(:input) do
          {
            'title' => 'new title',
            'description' => 'new description',
            'workItemTypeId' => WorkItems::Type.default_by_type(:test_case).to_global_id.to_s,
            'hierarchyWidget' => {}
          }
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['Following widget keys are not supported by Test Case type: [:hierarchy_widget]']
      end
    end

    context 'when the work_items feature flag is disabled' do
      before do
        stub_feature_flags(work_items: false)
      end

      it 'does not create the work item and returns an error' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to not_change(WorkItem, :count)

        expect(mutation_response['errors']).to contain_exactly('`work_items` feature flag disabled for this project')
      end
    end
  end
end

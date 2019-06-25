# frozen_string_literal: true

require 'spec_helper'

describe 'getting task completion status information' do
  include GraphqlHelpers

  DESCRIPTION_0_DONE = '- [ ] task 1\n- [ ] task 2'
  DESCRIPTION_1_DONE = '- [x] task 1\n- [ ] task 2'
  DESCRIPTION_2_DONE = '- [x] task 1\n- [x] task 2'

  set(:user1) { create(:user) }
  set(:project) { create(:project, :repository, :public) }

  let(:fields) do
    <<~QUERY
    taskCompletionStatus {
      count,
      completedCount
    }
    QUERY
  end

  def create_task_completion_status_query_for(type, iid)
    graphql_query_for(
      'project',
        { 'fullPath' => project.full_path },
        query_graphql_field(type, { iid: iid }, fields)
    )
  end

  shared_examples_for 'graphql task completion status provider' do |type|
    it 'returns the expected task completion status' do
      post_graphql(create_task_completion_status_query_for(type, item.iid), current_user: user1)

      expect(response).to have_gitlab_http_status(200)

      task_completion_status = graphql_data.dig('project', type, 'taskCompletionStatus')
      expect(task_completion_status).not_to be_nil
      expect(task_completion_status['count']).to eq(item.task_completion_status[:count])
      expect(task_completion_status['completedCount']).to eq(item.task_completion_status[:completed_count])
    end
  end

  [DESCRIPTION_0_DONE, DESCRIPTION_1_DONE, DESCRIPTION_2_DONE].each do |desc|
    context "with description #{desc}" do
      context 'when type is issue' do
        it_behaves_like 'graphql task completion status provider', 'issue' do
          let(:item) { create(:issue, project: project, description: desc) }
        end
      end

      context 'when type is merge request' do
        it_behaves_like 'graphql task completion status provider', 'mergeRequest' do
          let(:item) { create(:merge_request, author: user1, source_project: project, description: desc) }
        end
      end
    end
  end
end

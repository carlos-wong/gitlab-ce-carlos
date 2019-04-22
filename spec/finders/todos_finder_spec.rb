require 'spec_helper'

describe TodosFinder do
  describe '#execute' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:project) { create(:project, namespace: group) }
    let(:issue) { create(:issue, project: project) }
    let(:merge_request) { create(:merge_request, source_project: project) }
    let(:finder) { described_class }

    before do
      group.add_developer(user)
    end

    describe '#execute' do
      context 'filtering' do
        let!(:todo1) { create(:todo, user: user, project: project, target: issue) }
        let!(:todo2) { create(:todo, user: user, group: group, target: merge_request) }

        it 'returns correct todos when filtered by a project' do
          todos = finder.new(user, { project_id: project.id }).execute

          expect(todos).to match_array([todo1])
        end

        it 'returns correct todos when filtered by a group' do
          todos = finder.new(user, { group_id: group.id }).execute

          expect(todos).to match_array([todo1, todo2])
        end

        it 'returns correct todos when filtered by a type' do
          todos = finder.new(user, { type: 'Issue' }).execute

          expect(todos).to match_array([todo1])
        end

        context 'with subgroups', :nested_groups do
          let(:subgroup) { create(:group, parent: group) }
          let!(:todo3) { create(:todo, user: user, group: subgroup, target: issue) }

          it 'returns todos from subgroups when filtered by a group' do
            todos = finder.new(user, { group_id: group.id }).execute

            expect(todos).to match_array([todo1, todo2, todo3])
          end
        end
      end

      context 'external authorization' do
        it_behaves_like 'a finder with external authorization service' do
          let!(:subject) { create(:todo, project: project, user: user) }
          let(:project_params) { { project_id: project.id } }
        end
      end
    end

    describe '#sort' do
      context 'by date' do
        let!(:todo1) { create(:todo, user: user, project: project) }
        let!(:todo2) { create(:todo, user: user, project: project) }
        let!(:todo3) { create(:todo, user: user, project: project) }

        it 'sorts with oldest created first' do
          todos = finder.new(user, { sort: 'id_asc' }).execute

          expect(todos.first).to eq(todo1)
          expect(todos.second).to eq(todo2)
          expect(todos.third).to eq(todo3)
        end

        it 'sorts with newest created first' do
          todos = finder.new(user, { sort: 'id_desc' }).execute

          expect(todos.first).to eq(todo3)
          expect(todos.second).to eq(todo2)
          expect(todos.third).to eq(todo1)
        end
      end

      it "sorts by priority" do
        project_2       = create(:project)

        label_1         = create(:label, title: 'label_1', project: project, priority: 1)
        label_2         = create(:label, title: 'label_2', project: project, priority: 2)
        label_3         = create(:label, title: 'label_3', project: project, priority: 3)
        label_1_2       = create(:label, title: 'label_1', project: project_2, priority: 1)

        issue_1         = create(:issue, title: 'issue_1', project: project)
        issue_2         = create(:issue, title: 'issue_2', project: project)
        issue_3         = create(:issue, title: 'issue_3', project: project)
        issue_4         = create(:issue, title: 'issue_4', project: project)
        merge_request_1 = create(:merge_request, source_project: project_2)

        merge_request_1.labels << label_1_2

        # Covers the case where Todo has more than one label
        issue_3.labels         << label_1
        issue_3.labels         << label_3

        issue_2.labels         << label_3
        issue_1.labels         << label_2

        todo_1 = create(:todo, user: user, project: project, target: issue_4)
        todo_2 = create(:todo, user: user, project: project, target: issue_2)
        todo_3 = create(:todo, user: user, project: project, target: issue_3, created_at: 2.hours.ago)
        todo_4 = create(:todo, user: user, project: project, target: issue_1)
        todo_5 = create(:todo, user: user, project: project_2, target: merge_request_1, created_at: 1.hour.ago)

        project_2.add_developer(user)

        todos = finder.new(user, { sort: 'priority' }).execute

        expect(todos).to eq([todo_3, todo_5, todo_4, todo_2, todo_1])
      end
    end
  end

  describe '#any_for_target?' do
    it 'returns true if there are any todos for the given target' do
      todo = create(:todo, :pending)
      finder = described_class.new(todo.user)

      expect(finder.any_for_target?(todo.target)).to eq(true)
    end

    it 'returns false if there are no todos for the given target' do
      issue = create(:issue)
      finder = described_class.new(issue.author)

      expect(finder.any_for_target?(issue)).to eq(false)
    end
  end
end

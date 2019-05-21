# frozen_string_literal: true

require 'spec_helper'

describe Todos::Destroy::GroupPrivateService do
  let(:group)         { create(:group, :public) }
  let(:project)       { create(:project, group: group) }
  let(:user)          { create(:user) }
  let(:group_member)  { create(:user) }
  let(:project_member)  { create(:user) }

  let!(:todo_non_member)         { create(:todo, user: user, group: group) }
  let!(:todo_another_non_member) { create(:todo, user: user, group: group) }
  let!(:todo_group_member)       { create(:todo, user: group_member, group: group) }
  let!(:todo_project_member)     { create(:todo, user: project_member, group: group) }

  describe '#execute' do
    before do
      group.add_developer(group_member)
      project.add_developer(project_member)
    end

    subject { described_class.new(group.id).execute }

    context 'when a group set to private' do
      before do
        group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
      end

      it 'removes todos only for users who are not group users' do
        expect { subject }.to change { Todo.count }.from(4).to(2)

        expect(user.todos).to be_empty
        expect(group_member.todos).to match_array([todo_group_member])
        expect(project_member.todos).to match_array([todo_project_member])
      end

      context 'with nested groups', :nested_groups do
        let(:parent_group) { create(:group) }
        let(:subgroup)     { create(:group, :private, parent: group) }
        let(:subproject)   { create(:project, group: subgroup) }

        let(:parent_member)  { create(:user) }
        let(:subgroup_member)  { create(:user) }
        let(:subgproject_member) { create(:user) }

        let!(:todo_parent_member)     { create(:todo, user: parent_member, group: group) }
        let!(:todo_subgroup_member)   { create(:todo, user: subgroup_member, group: group) }
        let!(:todo_subproject_member) { create(:todo, user: subgproject_member, group: group) }

        before do
          group.update!(parent: parent_group)

          parent_group.add_developer(parent_member)
          subgroup.add_developer(subgroup_member)
          subproject.add_developer(subgproject_member)
        end

        it 'removes todos only for users who are not group users' do
          expect { subject }.to change { Todo.count }.from(7).to(5)
        end
      end
    end

    context 'when group is not private' do
      it 'does not remove any todos' do
        expect { subject }.not_to change { Todo.count }
      end
    end
  end
end

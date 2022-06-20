# frozen_string_literal: true

require "spec_helper"

RSpec.describe InviteMembersHelper do
  include Devise::Test::ControllerHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group, projects: [project]) }
  let_it_be(:developer) { create(:user, developer_projects: [project]) }

  let(:owner) { project.owner }

  before do
    helper.extend(Gitlab::Experimentation::ControllerConcern)
  end

  describe '#common_invite_group_modal_data' do
    it 'has expected common attributes' do
      attributes = {
        id: project.id,
        root_id: project.root_ancestor.id,
        name: project.name,
        default_access_level: Gitlab::Access::GUEST,
        invalid_groups: project.related_group_ids,
        help_link: help_page_url('user/permissions'),
        is_project: 'true',
        access_levels: ProjectMember.access_level_roles.to_json
      }

      expect(helper.common_invite_group_modal_data(project, ProjectMember, 'true')).to include(attributes)
    end
  end

  describe '#common_invite_modal_dataset' do
    it 'has expected common attributes' do
      attributes = {
        id: project.id,
        root_id: project.root_ancestor.id,
        name: project.name,
        default_access_level: Gitlab::Access::GUEST
      }

      expect(helper.common_invite_modal_dataset(project)).to include(attributes)
    end

    context 'tasks_to_be_done' do
      using RSpec::Parameterized::TableSyntax

      subject(:output) { helper.common_invite_modal_dataset(source) }

      shared_examples_for 'including the tasks to be done attributes' do
        it 'includes the tasks to be done attributes when expected' do
          if expected?
            expect(output[:tasks_to_be_done_options]).to eq(
              [
                { value: :code, text: 'Create/import code into a project (repository)' },
                { value: :ci, text: 'Set up CI/CD pipelines to build, test, deploy, and monitor code' },
                { value: :issues, text: 'Create/import issues (tickets) to collaborate on ideas and plan work' }
              ].to_json
            )
            expect(output[:projects]).to eq(
              [{ id: project.id, title: project.title }].to_json
            )
            expect(output[:new_project_path]).to eq(
              source.is_a?(Project) ? '' : new_project_path(namespace_id: group.id)
            )
          else
            expect(output[:tasks_to_be_done_options]).to be_nil
            expect(output[:projects]).to be_nil
            expect(output[:new_project_path]).to be_nil
          end
        end
      end

      context 'inviting members for tasks' do
        where(:open_modal_param_present?, :logged_in?, :expected?) do
          true  | true  | true
          true  | false | false
          false | true  | false
          false | false | false
        end

        with_them do
          before do
            allow(helper).to receive(:current_user).and_return(developer) if logged_in?
            allow(helper).to receive(:params).and_return({ open_modal: 'invite_members_for_task' }) if open_modal_param_present?
          end

          context 'when the source is a project' do
            let_it_be(:source) { project }

            it_behaves_like 'including the tasks to be done attributes'
          end

          context 'when the source is a group' do
            let_it_be(:source) { group }

            it_behaves_like 'including the tasks to be done attributes'
          end
        end
      end

      context 'the invite_for_help_continuous_onboarding experiment' do
        where(:invite_for_help_continuous_onboarding?, :logged_in?, :expected?) do
          true  | true  | true
          true  | false | false
          false | true  | false
          false | false | false
        end

        with_them do
          before do
            allow(helper).to receive(:current_user).and_return(developer) if logged_in?
            stub_experiments(invite_for_help_continuous_onboarding: :candidate) if invite_for_help_continuous_onboarding?
          end

          context 'when the source is a project' do
            let_it_be(:source) { project }

            it_behaves_like 'including the tasks to be done attributes'
          end

          context 'when the source is a group' do
            let_it_be(:source) { group }

            let(:expected?) { false }

            it_behaves_like 'including the tasks to be done attributes'
          end
        end
      end
    end
  end

  context 'with project' do
    before do
      allow(helper).to receive(:current_user) { owner }
      assign(:project, project)
    end

    describe "#can_invite_members_for_project?" do
      context 'when the user can_admin_project_member' do
        before do
          allow(helper).to receive(:can?).with(owner, :admin_project_member, project).and_return(true)
        end

        it 'returns true', :aggregate_failures do
          expect(helper.can_invite_members_for_project?(project)).to eq true
          expect(helper).to have_received(:can?).with(owner, :admin_project_member, project)
        end
      end

      context 'when the user can not manage project members' do
        before do
          expect(helper).to receive(:can?).with(owner, :admin_project_member, project).and_return(false)
        end

        it 'returns false' do
          expect(helper.can_invite_members_for_project?(project)).to eq false
        end
      end
    end
  end

  describe '#group_select_data' do
    let_it_be(:group) { create(:group) }

    context 'when sharing with groups outside the hierarchy is disabled' do
      before do
        group.namespace_settings.update!(prevent_sharing_groups_outside_hierarchy: true)
      end

      it 'provides the correct attributes' do
        expect(helper.group_select_data(group)).to eq({ groups_filter: 'descendant_groups', parent_id: group.id })
      end
    end

    context 'when sharing with groups outside the hierarchy is enabled' do
      before do
        group.namespace_settings.update!(prevent_sharing_groups_outside_hierarchy: false)
      end

      it 'returns an empty hash' do
        expect(helper.group_select_data(project.group)).to eq({})
      end
    end
  end
end

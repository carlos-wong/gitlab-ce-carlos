# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItemPolicy do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:public_project) { create(:project, :public, group: group) }
  let_it_be(:guest) { create(:user).tap { |user| project.add_guest(user) } }
  let_it_be(:guest_author) { create(:user).tap { |user| project.add_guest(user) } }
  let_it_be(:reporter) { create(:user).tap { |user| project.add_reporter(user) } }
  let_it_be(:group_reporter) { create(:user).tap { |user| group.add_reporter(user) } }
  let_it_be(:non_member_user) { create(:user) }
  let_it_be(:work_item) { create(:work_item, project: project) }
  let_it_be(:authored_work_item) { create(:work_item, project: project, author: guest_author) }
  let_it_be(:public_work_item) { create(:work_item, project: public_project) }

  let(:work_item_subject) { work_item }

  subject { described_class.new(current_user, work_item_subject) }

  before_all do
    public_project.add_developer(guest_author)
  end

  describe 'read_work_item' do
    context 'when project is public' do
      let(:work_item_subject) { public_work_item }

      context 'when user is not a member of the project' do
        let(:current_user) { non_member_user }

        it { is_expected.to be_allowed(:read_work_item) }
      end

      context 'when user is a member of the project' do
        let(:current_user) { guest_author }

        it { is_expected.to be_allowed(:read_work_item) }

        context 'when work_item is confidential' do
          let(:work_item_subject) { create(:work_item, confidential: true, project: project) }

          it { is_expected.not_to be_allowed(:read_work_item) }
        end
      end
    end

    context 'when project is private' do
      let(:work_item_subject) { work_item }

      context 'when user is not a member of the project' do
        let(:current_user) { non_member_user }

        it { is_expected.to be_disallowed(:read_work_item) }
      end

      context 'when user is a member of the project' do
        let(:current_user) { guest_author }

        it { is_expected.to be_allowed(:read_work_item) }
      end
    end
  end

  describe 'update_work_item' do
    context 'when user is reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:update_work_item) }
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:update_work_item) }

      context 'when guest authored the work item' do
        let(:work_item_subject) { authored_work_item }
        let(:current_user) { guest_author }

        it { is_expected.to be_allowed(:update_work_item) }
      end
    end
  end

  describe 'delete_work_item' do
    context 'when user is a member of the project' do
      let(:work_item_subject) { work_item }
      let(:current_user) { reporter }

      context 'when the user is not the author of the work item' do
        it { is_expected.to be_disallowed(:delete_work_item) }
      end

      context 'when guest authored the work item' do
        let(:work_item_subject) { authored_work_item }
        let(:current_user) { guest_author }

        it { is_expected.to be_allowed(:delete_work_item) }
      end
    end

    context 'when user is member of the project\'s group' do
      let(:current_user) { group_reporter }

      context 'when the user is not the author of the work item' do
        it { is_expected.to be_disallowed(:delete_work_item) }
      end

      context 'when user authored the work item' do
        let(:work_item_subject) { create(:work_item, project: project, author: current_user) }

        it { is_expected.to be_allowed(:delete_work_item) }
      end
    end

    context 'when user is not a member of the project' do
      let(:current_user) { non_member_user }

      context 'when the user authored the work item' do
        let(:work_item_subject) { create(:work_item, project: public_project, author: current_user) }

        it { is_expected.to be_disallowed(:delete_work_item) }
      end

      context 'when the user is not the author of the work item' do
        let(:work_item_subject) { public_work_item }

        it { is_expected.to be_disallowed(:delete_work_item) }
      end
    end
  end

  describe 'admin_parent_link' do
    context 'when user is reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:admin_parent_link) }
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:admin_parent_link) }

      context 'when guest authored the work item' do
        let(:work_item_subject) { authored_work_item }
        let(:current_user) { guest_author }

        it { is_expected.to be_disallowed(:admin_parent_link) }
      end

      context 'when guest is assigned to the work item' do
        before do
          work_item.assignees = [guest]
        end

        it { is_expected.to be_disallowed(:admin_parent_link) }
      end
    end
  end
end

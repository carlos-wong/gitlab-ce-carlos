# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItem do
  let_it_be(:reusable_project) { create(:project) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_one(:work_item_parent).class_name('WorkItem') }

    it 'has one `parent_link`' do
      is_expected.to have_one(:parent_link)
        .class_name('::WorkItems::ParentLink')
        .with_foreign_key('work_item_id')
    end

    it 'has many `work_item_children`' do
      is_expected.to have_many(:work_item_children)
        .class_name('WorkItem')
        .with_foreign_key('work_item_id')
    end

    it 'has many `child_links`' do
      is_expected.to have_many(:child_links)
        .class_name('::WorkItems::ParentLink')
        .with_foreign_key('work_item_parent_id')
    end
  end

  describe '#noteable_target_type_name' do
    it 'returns `issue` as the target name' do
      work_item = build(:work_item)

      expect(work_item.noteable_target_type_name).to eq('issue')
    end
  end

  describe '#widgets' do
    subject { build(:work_item).widgets }

    it 'returns instances of supported widgets' do
      is_expected.to match_array([instance_of(WorkItems::Widgets::Description),
                                  instance_of(WorkItems::Widgets::Hierarchy),
                                  instance_of(WorkItems::Widgets::Assignees),
                                  instance_of(WorkItems::Widgets::Weight)])
    end
  end

  describe 'callbacks' do
    describe 'record_create_action' do
      it 'records the creation action after saving' do
        expect(Gitlab::UsageDataCounters::WorkItemActivityUniqueCounter).to receive(:track_work_item_created_action)
        # During the work item transition we also want to track work items as issues
        expect(Gitlab::UsageDataCounters::IssueActivityUniqueCounter).to receive(:track_issue_created_action)

        create(:work_item)
      end
    end

    context 'work item namespace' do
      let(:work_item) { build(:work_item, project: reusable_project) }

      it 'sets the namespace_id' do
        expect(work_item).to be_valid
        expect(work_item.namespace).to eq(reusable_project.project_namespace)
      end

      context 'when work item is saved' do
        it 'sets the namespace_id' do
          work_item.save!
          expect(work_item.reload.namespace).to eq(reusable_project.project_namespace)
        end
      end

      context 'when existing work item is saved' do
        let(:work_item) { create(:work_item) }

        before do
          work_item.update!(namespace_id: nil)
        end

        it 'sets the namespace id' do
          work_item.update!(title: "#{work_item.title} and something extra")

          expect(work_item.namespace).to eq(work_item.project.project_namespace)
        end
      end
    end
  end

  describe 'validations' do
    subject { work_item.valid? }

    describe 'issue_type' do
      let(:work_item) { build(:work_item, issue_type: issue_type) }

      context 'when a valid type' do
        let(:issue_type) { :issue }

        it { is_expected.to eq(true) }
      end

      context 'empty type' do
        let(:issue_type) { nil }

        it { is_expected.to eq(false) }
      end
    end
  end
end

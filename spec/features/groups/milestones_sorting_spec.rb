# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Milestones sorting', :js do
  let(:group) { create(:group) }
  let!(:project) { create(:project_empty_repo, group: group) }
  let!(:other_project) { create(:project_empty_repo, group: group) }
  let!(:project_milestone1) { create(:milestone, project: project, title: 'v1.0', due_date: 10.days.from_now) }
  let!(:other_project_milestone1) { create(:milestone, project: other_project, title: 'v1.0', due_date: 10.days.from_now) }
  let!(:project_milestone2) { create(:milestone, project: project, title: 'v2.0', due_date: 5.days.from_now) }
  let!(:other_project_milestone2) { create(:milestone, project: other_project, title: 'v2.0', due_date: 5.days.from_now) }
  let!(:group_milestone) { create(:milestone, group: group, title: 'v3.0', due_date: 7.days.from_now) }
  let(:user) { create(:group_member, :maintainer, user: create(:user), group: group ).user }

  before do
    sign_in(user)
  end

  it 'visit group milestones and sort by due_date_asc', :js do
    visit group_milestones_path(group)

    expect(page).to have_button('Due soon')

    # assert default sorting
    within '.milestones' do
      expect(page.all('ul.content-list > li strong > a').map(&:text)).to eq(['v2.0', 'v2.0', 'v3.0', 'v1.0', 'v1.0'])
    end

    within '[data-testid=milestone_sort_by_dropdown]' do
      click_button 'Due soon'
      expect(find('.gl-new-dropdown-contents').all('.gl-new-dropdown-item-text-wrapper p').map(&:text)).to eq(['Due soon', 'Due later', 'Start soon', 'Start later', 'Name, ascending', 'Name, descending'])

      click_button 'Due later'
      expect(page).to have_button('Due later')
    end

    # assert descending sorting
    within '.milestones' do
      expect(page.all('ul.content-list > li strong > a').map(&:text)).to eq(['v1.0', 'v1.0', 'v3.0', 'v2.0', 'v2.0'])
    end
  end
end

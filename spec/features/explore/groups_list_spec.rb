# frozen_string_literal: true

require 'spec_helper'

describe 'Explore Groups page', :js do
  let!(:user) { create :user }
  let!(:group) { create(:group) }
  let!(:public_group) { create(:group, :public) }
  let!(:private_group) { create(:group, :private) }
  let!(:empty_project) { create(:project, group: public_group) }

  before do
    group.add_owner(user)

    sign_in(user)

    visit explore_groups_path
    wait_for_requests
  end

  it 'shows groups user is member of' do
    expect(page).to have_content(group.full_name)
    expect(page).to have_content(public_group.full_name)
    expect(page).not_to have_content(private_group.full_name)
  end

  it 'filters groups' do
    fill_in 'filter', with: group.name
    wait_for_requests

    expect(page).to have_content(group.full_name)
    expect(page).not_to have_content(public_group.full_name)
    expect(page).not_to have_content(private_group.full_name)
  end

  it 'resets search when user cleans the input' do
    fill_in 'filter', with: group.name
    wait_for_requests

    expect(page).to have_content(group.full_name)
    expect(page).not_to have_content(public_group.full_name)

    fill_in 'filter', with: ""
    page.find('[name="filter"]').send_keys(:enter)
    wait_for_requests

    expect(page).to have_content(group.full_name)
    expect(page).to have_content(public_group.full_name)
    expect(page).not_to have_content(private_group.full_name)
    expect(page.all('.js-groups-list-holder .content-list li').length).to eq 2
  end

  it 'shows non-archived projects count' do
    # Initially project is not archived
    expect(find('.js-groups-list-holder .content-list li:first-child .stats .number-projects')).to have_text("1")

    # Archive project
    ::Projects::UpdateService.new(empty_project, user, archived: true).execute
    visit explore_groups_path

    # Check project count
    expect(find('.js-groups-list-holder .content-list li:first-child .stats .number-projects')).to have_text("0")

    # Unarchive project
    ::Projects::UpdateService.new(empty_project, user, archived: false).execute
    visit explore_groups_path

    # Check project count
    expect(find('.js-groups-list-holder .content-list li:first-child .stats .number-projects')).to have_text("1")
  end

  describe 'landing component' do
    it 'shows a landing component' do
      expect(page).to have_content('Below you will find all the groups that are public.')
    end

    it 'is dismissable' do
      find('.dismiss-button').click

      expect(page).not_to have_content('Below you will find all the groups that are public.')
    end

    it 'does not show persistently once dismissed' do
      find('.dismiss-button').click

      visit explore_groups_path

      expect(page).not_to have_content('Below you will find all the groups that are public.')
    end
  end
end

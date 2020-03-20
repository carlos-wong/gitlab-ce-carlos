# frozen_string_literal: true

require 'spec_helper'

describe 'Search group member' do
  let(:user) { create :user }
  let(:member) { create :user }

  let!(:guest_group) do
    create(:group) do |group|
      group.add_guest(user)
      group.add_guest(member)
    end
  end

  before do
    sign_in(user)
    visit group_group_members_path(guest_group)
  end

  it 'renders member users' do
    page.within '.user-search-form' do
      fill_in 'search', with: member.name
      find('.user-search-btn').click
    end

    group_members_list = find('[data-qa-selector="members_list"]')
    expect(group_members_list).to have_content(member.name)
    expect(group_members_list).not_to have_content(user.name)
  end
end

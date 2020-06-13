# frozen_string_literal: true

require 'spec_helper'

describe 'Issue Boards new issue', :js do
  let(:project) { create(:project, :public) }
  let(:board)   { create(:board, project: project) }
  let!(:list)   { create(:list, board: board, position: 0) }
  let(:user)    { create(:user) }

  context 'authorized user' do
    before do
      project.add_maintainer(user)

      sign_in(user)

      visit project_board_path(project, board)
      wait_for_requests

      expect(page).to have_selector('.board', count: 3)
    end

    it 'displays new issue button' do
      expect(first('.board')).to have_selector('.issue-count-badge-add-button', count: 1)
    end

    it 'does not display new issue button in closed list' do
      page.within('.board:nth-child(3)') do
        expect(page).not_to have_selector('.issue-count-badge-add-button')
      end
    end

    it 'shows form when clicking button' do
      page.within(first('.board')) do
        find('.issue-count-badge-add-button').click

        expect(page).to have_selector('.board-new-issue-form')
      end
    end

    it 'hides form when clicking cancel' do
      page.within(first('.board')) do
        find('.issue-count-badge-add-button').click

        expect(page).to have_selector('.board-new-issue-form')

        click_button 'Cancel'

        expect(page).not_to have_selector('.board-new-issue-form')
      end
    end

    it 'creates new issue' do
      page.within(first('.board')) do
        find('.issue-count-badge-add-button').click
      end

      page.within(first('.board-new-issue-form')) do
        find('.form-control').set('bug')
        click_button 'Submit issue'
      end

      wait_for_requests

      page.within(first('.board .issue-count-badge-count')) do
        expect(page).to have_content('1')
      end

      page.within(first('.board-card')) do
        issue = project.issues.find_by_title('bug')

        expect(page).to have_content(issue.to_reference)
        expect(page).to have_link(issue.title, href: issue_path(issue))
      end
    end

    it 'shows sidebar when creating new issue' do
      page.within(first('.board')) do
        find('.issue-count-badge-add-button').click
      end

      page.within(first('.board-new-issue-form')) do
        find('.form-control').set('bug')
        click_button 'Submit issue'
      end

      wait_for_requests

      expect(page).to have_selector('.issue-boards-sidebar')
    end

    it 'successfuly loads labels to be added to newly created issue' do
      page.within(first('.board')) do
        find('.issue-count-badge-add-button').click
      end

      page.within(first('.board-new-issue-form')) do
        find('.form-control').set('new issue')
        click_button 'Submit issue'
      end

      wait_for_requests

      page.within(first('.issue-boards-sidebar')) do
        find('.labels .edit-link').click

        wait_for_requests

        expect(page).to have_selector('.labels .dropdown-content li a')
      end
    end
  end

  context 'unauthorized user' do
    before do
      visit project_board_path(project, board)
      wait_for_requests
    end

    it 'displays new issue button in open list' do
      expect(first('.board')).to have_selector('.issue-count-badge-add-button', count: 1)
    end

    it 'does not display new issue button in label list' do
      page.within('.board:nth-child(2)') do
        expect(page).not_to have_selector('.issue-count-badge-add-button')
      end
    end
  end

  context 'group boards' do
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:group_board) { create(:board, group: group) }
    let_it_be(:list) { create(:list, board: group_board, position: 0) }

    context 'for unauthorized users' do
      before do
        sign_in(user)
        visit group_board_path(group, group_board)
        wait_for_requests
      end

      it 'displays new issue button in open list' do
        expect(first('.board')).to have_selector('.issue-count-badge-add-button', count: 1)
      end

      it 'does not display new issue button in label list' do
        page.within('.board.is-draggable') do
          expect(page).not_to have_selector('.issue-count-badge-add-button')
        end
      end
    end

    context 'for authorized users' do
      it 'display new issue button in label list' do
        project = create(:project, namespace: group)
        project.add_reporter(user)

        sign_in(user)
        visit group_board_path(group, group_board)
        wait_for_requests

        page.within('.board.is-draggable') do
          expect(page).to have_selector('.issue-count-badge-add-button')
        end
      end
    end
  end
end

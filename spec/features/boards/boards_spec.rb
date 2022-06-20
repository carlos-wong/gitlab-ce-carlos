# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project issue boards', :js do
  include DragTo
  include MobileHelpers
  include BoardHelpers

  let_it_be(:group)   { create(:group, :nested) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:board)   { create(:board, project: project) }
  let_it_be(:user)    { create(:user) }
  let_it_be(:user2)   { create(:user) }

  let(:filtered_search) { find('[data-testid="issue-board-filtered-search"]') }
  let(:filter_input) { find('.gl-filtered-search-term-input') }
  let(:filter_submit) { find('.gl-search-box-by-click-search-button') }

  context 'signed in user' do
    before do
      project.add_maintainer(user)
      project.add_maintainer(user2)

      sign_in(user)
      stub_feature_flags(gl_avatar_for_all_user_avatars: false)

      set_cookie('sidebar_collapsed', 'true')
    end

    context 'no lists' do
      before do
        visit_project_board_path_without_query_limit(project, board)
      end

      it 'creates default lists' do
        lists = %w[Open Closed]

        wait_for_requests

        expect(page).to have_selector('.board', count: 2)

        page.all('.board').each_with_index do |list, i|
          expect(list.find('.board-title')).to have_content(lists[i])
        end
      end
    end

    context 'with lists' do
      let_it_be(:milestone) { create(:milestone, project: project) }

      let_it_be(:planning)    { create(:label, project: project, name: 'Planning', description: 'Test') }
      let_it_be(:development) { create(:label, project: project, name: 'Development') }
      let_it_be(:testing)     { create(:label, project: project, name: 'Testing') }
      let_it_be(:bug)         { create(:label, project: project, name: 'Bug') }
      let_it_be(:backlog)     { create(:label, project: project, name: 'Backlog') }
      let_it_be(:closed)      { create(:label, project: project, name: 'Closed') }
      let_it_be(:accepting)   { create(:label, project: project, name: 'Accepting Merge Requests') }
      let_it_be(:a_plus)      { create(:label, project: project, name: 'A+') }
      let_it_be(:list1)       { create(:list, board: board, label: planning, position: 0) }
      let_it_be(:list2)       { create(:list, board: board, label: development, position: 1) }
      let_it_be(:backlog_list) { create(:backlog_list, board: board) }

      let_it_be(:confidential_issue) { create(:labeled_issue, :confidential, project: project, author: user, labels: [planning], relative_position: 9) }
      let_it_be(:issue1) { create(:labeled_issue, project: project, title: 'aaa', description: '111', assignees: [user], labels: [planning], relative_position: 8) }
      let_it_be(:issue2) { create(:labeled_issue, project: project, title: 'bbb', description: '222', author: user2, labels: [planning], relative_position: 7) }
      let_it_be(:issue3) { create(:labeled_issue, project: project, title: 'ccc', description: '333', labels: [planning], relative_position: 6) }
      let_it_be(:issue4) { create(:labeled_issue, project: project, title: 'ddd', description: '444', labels: [planning], relative_position: 5) }
      let_it_be(:issue5) { create(:labeled_issue, project: project, title: 'eee', description: '555', labels: [planning], milestone: milestone, relative_position: 4) }
      let_it_be(:issue6) { create(:labeled_issue, project: project, title: 'fff', description: '666', labels: [planning, development], relative_position: 3) }
      let_it_be(:issue7) { create(:labeled_issue, project: project, title: 'ggg', description: '777', labels: [development], relative_position: 2) }
      let_it_be(:issue8) { create(:closed_issue, project: project, title: 'hhh', description: '888') }
      let_it_be(:issue9) { create(:labeled_issue, project: project, title: 'iii', description: '999', labels: [planning, testing, bug, accepting], relative_position: 1) }
      let_it_be(:issue10) { create(:labeled_issue, project: project, title: 'issue +', description: 'A+ great issue', labels: [a_plus]) }

      before do
        visit_project_board_path_without_query_limit(project, board)
      end

      it 'shows description tooltip on list title', :quarantine do
        page.within('.board:nth-child(2)') do
          expect(find('.board-title span.has-tooltip')[:title]).to eq('Test')
        end
      end

      it 'shows issues in lists' do
        wait_for_board_cards(2, 8)
        wait_for_board_cards(3, 2)
      end

      it 'shows confidential issues with icon' do
        page.within(find('.board:nth-child(2)')) do
          expect(page).to have_selector('.confidential-icon', count: 1)
        end
      end

      it 'search closed list' do
        set_filter_and_search_by_token_value(issue8.title)

        wait_for_requests

        expect(find('.board:nth-child(2)')).to have_selector('.board-card', count: 0)
        expect(find('.board:nth-child(3)')).to have_selector('.board-card', count: 0)
        expect(find('.board:nth-child(4)')).to have_selector('.board-card', count: 1)
      end

      it 'search list' do
        set_filter_and_search_by_token_value(issue5.title)

        wait_for_requests

        expect(find('.board:nth-child(2)')).to have_selector('.board-card', count: 1)
        expect(find('.board:nth-child(3)')).to have_selector('.board-card', count: 0)
        expect(find('.board:nth-child(4)')).to have_selector('.board-card', count: 0)
      end

      it 'allows user to delete board' do
        remove_list

        wait_for_requests

        expect(page).to have_selector('.board', count: 3)
      end

      it 'infinite scrolls list' do
        create_list(:labeled_issue, 30, project: project, labels: [planning])

        visit_project_board_path_without_query_limit(project, board)

        page.within(find('.board:nth-child(2)')) do
          expect(page.find('.board-header')).to have_content('38')
          expect(page).to have_selector('.board-card', count: 10)
          expect(page).to have_content('Showing 10 of 38 issues')

          find('.board .board-list')

          inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
            evaluate_script("document.querySelectorAll('.board .board-list')[1].scrollTop = document.querySelectorAll('.board .board-list')[1].scrollHeight")
          end

          expect(page).to have_selector('.board-card', count: 20)
          expect(page).to have_content('Showing 20 of 38 issues')

          find('.board .board-list')

          inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
            evaluate_script("document.querySelectorAll('.board .board-list')[1].scrollTop = document.querySelectorAll('.board .board-list')[1].scrollHeight")
          end

          expect(page).to have_selector('.board-card', count: 30)
          expect(page).to have_content('Showing 30 of 38 issues')

          find('.board .board-list')

          inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
            evaluate_script("document.querySelectorAll('.board .board-list')[1].scrollTop = document.querySelectorAll('.board .board-list')[1].scrollHeight")
          end

          expect(page).to have_selector('.board-card', count: 38)
          expect(page).to have_content('Showing all issues')
        end
      end

      context 'closed' do
        it 'shows list of closed issues' do
          wait_for_board_cards(4, 1)
          wait_for_requests
        end

        it 'moves issue to closed' do
          drag(list_from_index: 1, list_to_index: 3)

          wait_for_board_cards(2, 7)
          wait_for_board_cards(3, 2)
          wait_for_board_cards(4, 2)

          expect(find('.board:nth-child(2)')).not_to have_content(issue9.title)
          expect(find('.board:nth-child(4)')).to have_selector('.board-card', count: 2)
          expect(find('.board:nth-child(4)')).to have_content(issue9.title)
          expect(find('.board:nth-child(4)')).not_to have_content(planning.title)
        end

        it 'removes all of the same issue to closed' do
          drag(list_from_index: 1, list_to_index: 3)

          wait_for_board_cards(2, 7)
          wait_for_board_cards(3, 2)
          wait_for_board_cards(4, 2)

          expect(find('.board:nth-child(2)')).not_to have_content(issue9.title)
          expect(find('.board:nth-child(4)')).to have_content(issue9.title)
          expect(find('.board:nth-child(4)')).not_to have_content(planning.title)
        end
      end

      context 'lists' do
        it 'changes position of list' do
          drag(list_from_index: 2, list_to_index: 1, selector: '.board-header')

          expect(find('.board:nth-child(2) [data-testid="board-list-header"]')).to have_content(development.title)
          expect(find('.board:nth-child(3) [data-testid="board-list-header"]')).to have_content(planning.title)

          # Make sure list positions are preserved after a reload
          visit_project_board_path_without_query_limit(project, board)

          expect(find('.board:nth-child(2) [data-testid="board-list-header"]')).to have_content(development.title)
          expect(find('.board:nth-child(3) [data-testid="board-list-header"]')).to have_content(planning.title)
        end

        context 'without backlog and closed lists' do
          let_it_be(:board) { create(:board, project: project, hide_backlog_list: true, hide_closed_list: true) }
          let_it_be(:list1) { create(:list, board: board, label: planning, position: 0) }
          let_it_be(:list2) { create(:list, board: board, label: development, position: 1) }

          it 'changes position of list' do
            visit_project_board_path_without_query_limit(project, board)

            drag(list_from_index: 0, list_to_index: 1, selector: '.board-header')

            expect(find('.board:nth-child(1) [data-testid="board-list-header"]')).to have_content(development.title)
            expect(find('.board:nth-child(2) [data-testid="board-list-header"]')).to have_content(planning.title)

            # Make sure list positions are preserved after a reload
            visit_project_board_path_without_query_limit(project, board)

            expect(find('.board:nth-child(1) [data-testid="board-list-header"]')).to have_content(development.title)
            expect(find('.board:nth-child(2) [data-testid="board-list-header"]')).to have_content(planning.title)
          end
        end

        it 'dragging does not duplicate list' do
          selector = '.board:not(.is-ghost) .board-header'
          expect(page).to have_selector(selector, text: development.title, count: 1)

          drag(list_from_index: 2, list_to_index: 1, selector: '.board-header', perform_drop: false)

          expect(page).to have_selector(selector, text: development.title, count: 1)
        end

        it 'issue moves between lists and does not show the "Development" label since the card is in the "Development" list label' do
          drag(list_from_index: 1, from_index: 1, list_to_index: 2)

          wait_for_board_cards(2, 7)
          wait_for_board_cards(3, 2)
          wait_for_board_cards(4, 1)

          expect(find('.board:nth-child(3)')).to have_content(issue6.title)
          expect(find('.board:nth-child(3)').all('.board-card').last).not_to have_content(development.title)
        end

        it 'issue moves between lists and does not show the "Planning" label since the card is in the "Planning" list label' do
          drag(list_from_index: 2, list_to_index: 1)

          wait_for_board_cards(2, 9)
          wait_for_board_cards(3, 1)
          wait_for_board_cards(4, 1)

          expect(find('.board:nth-child(2)')).to have_content(issue7.title)
          expect(find('.board:nth-child(2)').all('.board-card').first).not_to have_content(planning.title)
        end

        it 'issue moves from closed' do
          drag(list_from_index: 2, list_to_index: 3)

          wait_for_board_cards(2, 8)
          wait_for_board_cards(3, 1)
          wait_for_board_cards(4, 2)

          expect(find('.board:nth-child(4)')).to have_content(issue8.title)
        end

        context 'issue card' do
          it 'shows assignee' do
            page.within(find('.board:nth-child(2)')) do
              expect(page).to have_selector('.avatar', count: 1)
            end
          end

          context 'list header' do
            let(:total_planning_issues) { "8" }

            it 'shows issue count on the list' do
              page.within(find(".board:nth-child(2)")) do
                expect(page.find('[data-testid="board-items-count"]')).to have_text(total_planning_issues)
                expect(page).not_to have_selector('.max-issue-size')
              end
            end
          end
        end
      end

      context 'filtering' do
        it 'filters by author' do
          set_filter("author", user2.username)
          click_on user2.username
          filter_submit.click

          wait_for_requests
          wait_for_board_cards(2, 1)
          wait_for_empty_boards((3..4))
        end

        it 'filters by assignee' do
          set_filter("assignee", user.username)
          click_on user.username
          filter_submit.click

          wait_for_requests

          wait_for_board_cards(2, 1)
          wait_for_empty_boards((3..4))
        end

        it 'filters by milestone' do
          set_filter("milestone", "\"#{milestone.title}")
          click_on milestone.title
          filter_submit.click

          wait_for_requests
          wait_for_board_cards(2, 1)
          wait_for_board_cards(3, 0)
          wait_for_board_cards(4, 0)
        end

        it 'filters by label' do
          set_filter("label", testing.title)
          click_on testing.title
          filter_submit.click

          wait_for_requests
          wait_for_board_cards(2, 1)
          wait_for_empty_boards((3..4))
        end

        it 'filters by label with encoded character' do
          set_filter("label", a_plus.title)
          #  This one is a char encoding issue like the & issue
          click_on a_plus.title
          filter_submit.click
          wait_for_requests

          wait_for_board_cards(1, 1)
          wait_for_empty_boards((2..4))
        end

        it 'filters by label with space after reload', :quarantine do
          set_filter("label", "\"#{accepting.title}")
          click_on accepting.title
          filter_submit.click

          # Test after reload
          page.evaluate_script 'window.location.reload()'
          wait_for_board_cards(2, 1)
          wait_for_empty_boards((3..4))

          wait_for_requests

          page.within(find('.board:nth-child(2)')) do
            expect(page.find('.board-header')).to have_content('1')
            expect(page).to have_selector('.board-card', count: 1)
          end

          page.within(find('.board:nth-child(3)')) do
            expect(page.find('.board-header')).to have_content('0')
            expect(page).to have_selector('.board-card', count: 0)
          end
        end

        it 'removes filtered labels' do
          inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
            set_filter("label", testing.title)
            click_on testing.title
            filter_submit.click

            wait_for_board_cards(2, 1)

            find('[data-testid="filtered-search-clear-button"]').click
            filter_submit.click
          end

          wait_for_board_cards(2, 8)
        end

        it 'infinite scrolls list with label filter' do
          create_list(:labeled_issue, 30, project: project, labels: [planning, testing])

          set_filter("label", testing.title)
          click_on testing.title
          inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
            filter_submit.click
          end

          wait_for_requests

          page.within(find('.board:nth-child(2)')) do
            expect(page.find('.board-header')).to have_content('31')
            expect(page).to have_selector('.board-card', count: 10)
            expect(page).to have_content('Showing 10 of 31 issues')

            find('.board .board-list')

            inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
              evaluate_script("document.querySelectorAll('.board .board-list')[1].scrollTop = document.querySelectorAll('.board .board-list')[1].scrollHeight")
            end

            expect(page).to have_selector('.board-card', count: 20)
            expect(page).to have_content('Showing 20 of 31 issues')

            find('.board .board-list')

            inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
              evaluate_script("document.querySelectorAll('.board .board-list')[1].scrollTop = document.querySelectorAll('.board .board-list')[1].scrollHeight")
            end

            expect(page).to have_selector('.board-card', count: 30)
            expect(page).to have_content('Showing 30 of 31 issues')

            find('.board .board-list')
            inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
              evaluate_script("document.querySelectorAll('.board .board-list')[1].scrollTop = document.querySelectorAll('.board .board-list')[1].scrollHeight")
            end

            expect(page).to have_selector('.board-card', count: 31)
            expect(page).to have_content('Showing all issues')
          end
        end

        it 'filters by multiple labels', :quarantine do
          set_filter("label", testing.title)
          click_on testing.title

          set_filter("label", bug.title)
          click_on bug.title

          submit_filter

          wait_for_requests

          wait_for_board_cards(2, 1)
          wait_for_empty_boards((3..4))
        end

        it 'filters by clicking label button on issue' do
          page.within(find('.board:nth-child(2)')) do
            expect(page).to have_selector('.board-card', count: 8)
            expect(find('.board-card', match: :first)).to have_content(bug.title)
            click_link(bug.title)
            wait_for_requests
          end

          page.within('.gl-filtered-search-token') do
            expect(page).to have_content(bug.title)
          end

          wait_for_requests

          wait_for_board_cards(2, 1)
          wait_for_empty_boards((3..4))
        end

        it 'removes label filter by clicking label button on issue' do
          page.within(find('.board:nth-child(2)')) do
            page.within(find('.board-card', match: :first)) do
              click_link(bug.title)
            end

            wait_for_requests

            expect(page).to have_selector('.board-card', count: 1)
          end

          wait_for_requests
        end
      end
    end

    context 'issue board focus mode' do
      before do
        visit project_board_path(project, board)
        wait_for_requests
      end

      it 'shows the button' do
        expect(page).to have_button('Toggle focus mode')
      end
    end

    context 'keyboard shortcuts' do
      before do
        visit_project_board_path_without_query_limit(project, board)
        wait_for_requests
      end

      it 'allows user to use keyboard shortcuts' do
        find('body').native.send_keys('i')
        expect(page).to have_content('New Issue')
      end
    end
  end

  context 'signed out user' do
    before do
      visit project_board_path(project, board)
      wait_for_requests
    end

    it 'displays lists' do
      expect(page).to have_selector('.board')
    end

    it 'does not show create new list' do
      expect(page).not_to have_button('Create list')
    end

    it 'does not allow dragging' do
      expect(page).not_to have_selector('.gl-cursor-grab')
    end
  end

  context 'as guest user' do
    let_it_be(:user_guest) { create(:user) }

    before do
      stub_feature_flags(bootstrap_confirmation_modals: false)
      project.add_guest(user_guest)
      sign_in(user_guest)
      visit project_board_path(project, board)
      wait_for_requests
    end

    it 'does not show create new list' do
      expect(page).not_to have_button('Create list')
    end
  end

  def wait_for_board_cards(board_number, expected_cards)
    page.within(find(".board:nth-child(#{board_number})")) do
      expect(page.find('.board-header')).to have_content(expected_cards.to_s)
      expect(page).to have_selector('.board-card', count: expected_cards)
    end
  end

  def wait_for_empty_boards(board_numbers)
    board_numbers.each do |board|
      wait_for_board_cards(board, 0)
    end
  end

  def set_filter_and_search_by_token_value(value)
    filter_input.click
    filter_input.set(value)
    filter_submit.click
  end

  def set_filter(type, text)
    filter_input.click
    filter_input.native.send_keys("#{type}:=#{text}")
  end

  def submit_filter
    filter_input.native.send_keys(:enter)
  end

  def click_filter_link(link_text)
    page.within(filtered_search) do
      expect(page).to have_button(link_text)

      click_on link_text
    end
  end

  def remove_list
    page.within(find('.board:nth-child(2)')) do
      find('button[title="List settings"]').click
    end

    page.within(find('.js-board-settings-sidebar')) do
      click_button 'Remove list'
    end

    page.within('.modal') do
      click_button 'Remove list'
    end
  end

  def visit_project_board_path_without_query_limit(project, board)
    inspect_requests(inject_headers: { 'X-GITLAB-DISABLE-SQL-QUERY-LIMIT' => 'https://gitlab.com/gitlab-org/gitlab/-/issues/323426' }) do
      visit project_board_path(project, board)

      wait_for_requests
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

describe "User creates issue" do
  include DropzoneHelper

  let_it_be(:project) { create(:project_empty_repo, :public) }
  let_it_be(:user) { create(:user) }

  context "when unauthenticated" do
    before do
      sign_out(:user)
    end

    it "redirects to signin then back to new issue after signin" do
      create(:issue, project: project)

      visit project_issues_path(project)

      page.within ".nav-controls" do
        click_link "New issue"
      end

      expect(current_path).to eq new_user_session_path

      gitlab_sign_in(create(:user))

      expect(current_path).to eq new_project_issue_path(project)
    end
  end

  context "when signed in as guest" do
    before do
      project.add_guest(user)
      sign_in(user)

      visit(new_project_issue_path(project))
    end

    it "creates issue", :js do
      page.within(".issue-form") do
        expect(page).to have_no_content("Assign to")
        .and have_no_content("Labels")
        .and have_no_content("Milestone")

        expect(page.find('#issue_title')['placeholder']).to eq 'Title'
        expect(page.find('#issue_description')['placeholder']).to eq 'Write a comment or drag your files here…'
      end

      issue_title = "500 error on profile"

      fill_in("Title", with: issue_title)
      first('.js-md').click
      first('.rspec-issuable-form-description').native.send_keys('Description')

      click_button("Submit issue")

      expect(page).to have_content(issue_title)
        .and have_content(user.name)
        .and have_content(project.name)
      expect(page).to have_selector('strong', text: 'Description')
    end
  end

  context "when signed in as developer", :js do
    before do
      project.add_developer(user)
      sign_in(user)

      visit(new_project_issue_path(project))
    end

    context "when previewing" do
      it "previews content" do
        form = first(".gfm-form")
        textarea = first(".gfm-form textarea")

        page.within(form) do
          click_button("Preview")

          preview = find(".js-md-preview") # this element is findable only when the "Preview" link is clicked.

          expect(preview).to have_content("Nothing to preview.")

          click_button("Write")
          fill_in("Description", with: "Bug fixed :smile:")
          click_button("Preview")

          expect(preview).to have_css("gl-emoji")
          expect(textarea).not_to be_visible
        end
      end
    end

    context "with labels" do
      let(:label_titles) { %w(bug feature enhancement) }

      before do
        label_titles.each do |title|
          create(:label, project: project, title: title)
        end
      end

      it "creates issue" do
        issue_title = "500 error on profile"

        fill_in("Title", with: issue_title)
        click_button("Label")
        click_link(label_titles.first)
        click_button("Submit issue")

        expect(page).to have_content(issue_title)
          .and have_content(user.name)
          .and have_content(project.name)
          .and have_content(label_titles.first)
      end
    end

    context 'with due date', :js do
      it 'saves with due date' do
        date = Date.today.at_beginning_of_month

        fill_in 'issue_title', with: 'bug 345'
        fill_in 'issue_description', with: 'bug description'
        find('#issuable-due-date').click

        page.within '.pika-single' do
          click_button date.day
        end

        expect(find('#issuable-due-date').value).to eq date.to_s

        click_button 'Submit issue'

        page.within '.issuable-sidebar' do
          expect(page).to have_content date.to_s(:medium)
        end
      end
    end

    context 'dropzone upload file', :js do
      before do
        visit new_project_issue_path(project)
      end

      it 'uploads file when dragging into textarea' do
        dropzone_file Rails.root.join('spec', 'fixtures', 'banana_sample.gif')

        expect(page.find_field("issue_description").value).to have_content 'banana_sample'
      end

      it "doesn't add double newline to end of a single attachment markdown" do
        dropzone_file Rails.root.join('spec', 'fixtures', 'banana_sample.gif')

        expect(page.find_field("issue_description").value).not_to match /\n\n$/
      end

      it "cancels a file upload correctly" do
        slow_requests do
          dropzone_file([Rails.root.join('spec', 'fixtures', 'dk.png')], 0, false)

          click_button 'Cancel'
        end

        expect(page).to have_button('Attach a file')
        expect(page).not_to have_button('Cancel')
        expect(page).not_to have_selector('.uploading-progress-container', visible: true)
      end
    end

    context 'form filled by URL parameters' do
      let(:project) { create(:project, :public, :repository) }

      before do
        project.repository.create_file(
          user,
          '.gitlab/issue_templates/bug.md',
          'this is a test "bug" template',
          message: 'added issue template',
          branch_name: 'master')

        visit new_project_issue_path(project, issuable_template: 'bug')
      end

      it 'fills in template' do
        expect(find('.js-issuable-selector .dropdown-toggle-text')).to have_content('bug')
      end
    end

    context 'suggestions', :js do
      it 'displays list of related issues' do
        issue = create(:issue, project: project)
        create(:issue, project: project, title: 'test issue')

        visit new_project_issue_path(project)

        fill_in 'issue_title', with: issue.title

        expect(page).to have_selector('.suggestion-item', count: 1)
      end
    end

    it 'clears local storage after creating a new issue', :js do
      2.times do
        visit new_project_issue_path(project)
        wait_for_requests

        expect(page).to have_field('Title', with: '')

        fill_in 'issue_title', with: 'bug 345'
        fill_in 'issue_description', with: 'bug description'

        click_button 'Submit issue'
      end
    end
  end

  context "when signed in as user with special characters in their name" do
    let(:user_special) { create(:user, name: "Jon O'Shea") }

    before do
      project.add_developer(user_special)
      sign_in(user_special)

      visit(new_project_issue_path(project))
    end

    it "will correctly escape user names with an apostrophe when clicking 'Assign to me'", :js do
      first('.assign-to-me-link').click

      expect(page).to have_content(user_special.name)
      expect(page.find('input[name="issue[assignee_ids][]"]', visible: false)['data-meta']).to eq(user_special.name)
    end
  end
end

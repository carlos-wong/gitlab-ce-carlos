# frozen_string_literal: true

shared_examples 'tableflip quick action' do |issuable_type|
  before do
    project.add_maintainer(maintainer)
    gitlab_sign_in(maintainer)
  end

  context "new #{issuable_type}", :js do
    before do
      case issuable_type
      when :merge_request
        visit public_send('namespace_project_new_merge_request_path', project.namespace, project, new_url_opts)
        wait_for_all_requests
      when :issue
        visit public_send('new_namespace_project_issue_path', project.namespace, project, new_url_opts)
        wait_for_all_requests
      end
    end

    it "creates the #{issuable_type} and interprets tableflip quick action accordingly" do
      fill_in "#{issuable_type}_title", with: 'bug 345'
      fill_in "#{issuable_type}_description", with: "bug description\n/tableflip oops"
      click_button "Submit #{issuable_type}".humanize

      issuable = project.public_send(issuable_type.to_s.pluralize).first

      expect(issuable.description).to eq "bug description\noops (╯°□°)╯︵ ┻━┻"
      expect(page).to have_content 'bug 345'
      expect(page).to have_content "bug description\noops (╯°□°)╯︵ ┻━┻"
    end
  end

  context "post note to existing #{issuable_type}" do
    before do
      visit public_send("project_#{issuable_type}_path", project, issuable)
      wait_for_all_requests
    end

    it 'creates the note and interprets tableflip quick action accordingly' do
      add_note("/tableflip oops")

      wait_for_requests
      expect(page).not_to have_content '/tableflip oops'
      expect(page).to have_content "oops (╯°□°)╯︵ ┻━┻"
      expect(issuable.notes.last.note).to eq "oops (╯°□°)╯︵ ┻━┻"
    end
  end

  context "preview of note on #{issuable_type}", :js do
    it 'explains tableflip quick action' do
      visit public_send("project_#{issuable_type}_path", project, issuable)

      preview_note('/tableflip oops')

      expect(page).not_to have_content '/tableflip'
      expect(page).to have_content "oops (╯°□°)╯︵ ┻━┻"
    end
  end
end

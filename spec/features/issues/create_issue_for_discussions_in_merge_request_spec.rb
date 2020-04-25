# frozen_string_literal: true

require 'spec_helper'

describe 'Resolving all open threads in a merge request from an issue', :js do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:merge_request) { create(:merge_request, source_project: project) }
  let!(:discussion) { create(:diff_note_on_merge_request, noteable: merge_request, project: project).to_discussion }

  def resolve_all_discussions_link_selector
    text = "Resolve all threads in new issue"
    url = new_project_issue_path(project, merge_request_to_resolve_discussions_of: merge_request.iid)
    %Q{a[title="#{text}"][href="#{url}"]}
  end

  describe 'as a user with access to the project' do
    before do
      project.add_maintainer(user)
      sign_in user
      visit project_merge_request_path(project, merge_request)
    end

    it 'shows a button to resolve all threads by creating a new issue' do
      within('.line-resolve-all-container') do
        expect(page).to have_selector resolve_all_discussions_link_selector
      end
    end

    context 'resolving the thread' do
      before do
        click_button 'Resolve thread'
      end

      it 'hides the link for creating a new issue' do
        expect(page).not_to have_selector resolve_all_discussions_link_selector
      end
    end

    context 'creating an issue for threads' do
      before do
        find(resolve_all_discussions_link_selector).click
      end

      it_behaves_like 'creating an issue for a thread'
    end

    context 'for a project where all threads need to be resolved before merging' do
      before do
        project.update_attribute(:only_allow_merge_if_all_discussions_are_resolved, true)
      end

      context 'with the internal tracker disabled' do
        before do
          project.project_feature.update_attribute(:issues_access_level, ProjectFeature::DISABLED)
          visit project_merge_request_path(project, merge_request)
        end

        it 'does not show a link to create a new issue' do
          expect(page).not_to have_link 'Create an issue to resolve them later'
        end
      end

      context 'merge request has threads that need to be resolved' do
        before do
          visit project_merge_request_path(project, merge_request)
        end

        it 'shows a warning that the merge request contains unresolved threads' do
          expect(page).to have_content 'There are unresolved threads.'
        end

        it 'has a link to resolve all threads by creating an issue' do
          page.within '.mr-widget-body' do
            expect(page).to have_link 'Create an issue to resolve them later', href: new_project_issue_path(project, merge_request_to_resolve_discussions_of: merge_request.iid)
          end
        end

        context 'creating an issue for threads' do
          before do
            page.click_link 'Create an issue to resolve them later', href: new_project_issue_path(project, merge_request_to_resolve_discussions_of: merge_request.iid)
          end

          it_behaves_like 'creating an issue for a thread'
        end
      end
    end
  end

  describe 'as a reporter' do
    before do
      project.add_reporter(user)
      sign_in user
      visit new_project_issue_path(project, merge_request_to_resolve_discussions_of: merge_request.iid)
    end

    it 'Shows a notice to ask someone else to resolve the threads' do
      expect(page).to have_content("The threads at #{merge_request.to_reference} will stay unresolved. Ask someone with permission to resolve them.")
    end
  end
end

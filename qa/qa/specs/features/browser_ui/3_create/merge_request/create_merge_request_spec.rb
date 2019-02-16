# frozen_string_literal: true

module QA
  context 'Create' do
    describe 'Merge request creation' do
      it 'user creates a new merge request' do
        gitlab_account_username = "@#{Runtime::User.username}"

        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.act { sign_in_using_credentials }

        current_project = Resource::Project.fabricate! do |project|
          project.name = 'project-with-merge-request-and-milestone'
        end

        current_milestone = Resource::ProjectMilestone.fabricate! do |milestone|
          milestone.title = 'unique-milestone'
          milestone.project = current_project
        end

        new_label = Resource::Label.fabricate! do |label|
          label.project = current_project
          label.title = 'qa-mr-test-label'
          label.description = 'Merge Request label'
        end

        Resource::MergeRequest.fabricate! do |merge_request|
          merge_request.title = 'This is a merge request with a milestone'
          merge_request.description = 'Great feature with milestone'
          merge_request.project = current_project
          merge_request.milestone = current_milestone
          merge_request.assignee = 'me'
          merge_request.labels.push(new_label)
        end

        Page::MergeRequest::Show.perform do |merge_request|
          expect(merge_request).to have_content('This is a merge request with a milestone')
          expect(merge_request).to have_content('Great feature with milestone')
          expect(merge_request).to have_content(/Opened [\w\s]+ ago/)
          expect(merge_request).to have_assignee(gitlab_account_username)
          expect(merge_request).to have_label(new_label.title)
        end

        Page::Issuable::Sidebar.perform do |sidebar|
          expect(sidebar).to have_milestone(current_milestone.title)
        end
      end
    end
  end

  describe 'creates a merge request', :smoke do
    it 'user creates a new merge request' do
      Runtime::Browser.visit(:gitlab, Page::Main::Login)
      Page::Main::Login.act { sign_in_using_credentials }

      current_project = Resource::Project.fabricate! do |project|
        project.name = 'project-with-merge-request'
      end

      Resource::MergeRequest.fabricate! do |merge_request|
        merge_request.title = 'This is a merge request'
        merge_request.description = 'Great feature'
        merge_request.project = current_project
      end

      expect(page).to have_content('This is a merge request')
      expect(page).to have_content('Great feature')
      expect(page).to have_content(/Opened [\w\s]+ ago/)
    end
  end
end

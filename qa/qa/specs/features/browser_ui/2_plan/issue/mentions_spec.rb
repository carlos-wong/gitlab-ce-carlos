# frozen_string_literal: true

module QA
  context 'Plan', :smoke, :reliable do
    describe 'mention' do
      before do
        Flow::Login.sign_in

        @user = Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_1, Runtime::Env.gitlab_qa_password_1)

        project = Resource::Project.fabricate_via_api! do |project|
          project.name = 'project-to-test-mention'
          project.visibility = 'private'
        end

        project.add_member(@user)

        Resource::Issue.fabricate_via_api! do |issue|
          issue.project = project
        end.visit!
      end

      it 'mentions another user in an issue' do
        Page::Project::Issue::Show.perform do |show|
          at_username = "@#{@user.username}"

          show.select_all_activities_filter
          show.comment(at_username)

          expect(show).to have_link(at_username)
        end
      end
    end
  end
end

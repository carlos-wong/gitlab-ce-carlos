# frozen_string_literal: true

module QA
  context 'Create' do
    describe 'Wiki management' do
      def validate_content(content)
        expect(page).to have_content('Wiki was successfully updated')
        expect(page).to have_content(/#{content}/)
      end

      it 'user creates, edits, clones, and pushes to the wiki' do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)

        wiki = Resource::Wiki.fabricate! do |resource|
          resource.title = 'Home'
          resource.content = '# My First Wiki Content'
          resource.message = 'Update home'
        end

        validate_content('My First Wiki Content')

        Page::Project::Wiki::Edit.perform(&:go_to_edit_page)
        Page::Project::Wiki::New.perform do |page|
          page.set_content("My Second Wiki Content")
          page.save_changes
        end

        validate_content('My Second Wiki Content')

        Resource::Repository::WikiPush.fabricate! do |push|
          push.wiki = wiki
          push.file_name = 'Home.md'
          push.file_content = '# My Third Wiki Content'
          push.commit_message = 'Update Home.md'
        end
        Page::Project::Menu.perform(&:click_wiki)

        expect(page).to have_content('My Third Wiki Content')
      end
    end
  end
end

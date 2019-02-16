# frozen_string_literal: true

module QA
  context 'Create' do
    describe 'push after setting the file size limit via admin/application_settings' do
      before(:all) do
        push = Resource::Repository::ProjectPush.fabricate! do |p|
          p.file_name = 'README.md'
          p.file_content = '# This is a test project'
          p.commit_message = 'Add README.md'
        end

        @project = push.project
      end

      before do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)
      end

      after(:all) do
        # need to set the default value after test
        # default value for file size limit is empty
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)

        set_file_size_limit('')
      end

      it 'push successful when the file size is under the limit' do
        set_file_size_limit(5)
        expect(page).to have_content("Application settings saved successfully")

        push = push_new_file('oversize_file_1.bin')
        expect(push.output).not_to have_content 'remote: fatal: pack exceeds maximum allowed size'
      end

      it 'push fails when the file size is above the limit' do
        set_file_size_limit(1)
        expect(page).to have_content("Application settings saved successfully")

        push = push_new_file('oversize_file_2.bin')
        expect(push.output).to have_content 'remote: fatal: pack exceeds maximum allowed size'
      end

      def set_file_size_limit(limit)
        Page::Main::Menu.perform(&:go_to_admin_area)
        Page::Admin::Menu.perform(&:go_to_general_settings)

        Page::Admin::Settings::General.perform do |setting|
          setting.expand_account_and_limit do |page|
            page.set_max_file_size(limit)
            page.save_settings
          end
        end
      end

      def push_new_file(file_name)
        @project.visit!

        Resource::Repository::ProjectPush.fabricate! do |p|
          p.project = @project
          p.file_name = file_name
          p.file_content = SecureRandom.random_bytes(2000000)
          p.commit_message = 'Adding a new file'
        end
      end
    end
  end
end

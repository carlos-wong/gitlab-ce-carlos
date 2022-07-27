# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'SSH keys support', :smoke do
      key_title = "key for ssh tests #{Time.now.to_f}"
      key = nil

      before do
        Flow::Login.sign_in
      end

      it 'user can add an SSH key', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347819' do
        key = Resource::SSHKey.fabricate_via_browser_ui! do |resource|
          resource.title = key_title
        end

        expect(page).to have_content(key.title)
        expect(page).to have_content(key.sha256_fingerprint)
      end

      # Note this context ensures that the example it contains is executed after the example above. Be aware of the order of execution if you add new examples in either context.
      context 'after adding an ssh key' do
        it 'can delete an ssh key', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347820' do
          Page::Main::Menu.perform(&:click_edit_profile_link)
          Page::Profile::Menu.perform(&:click_ssh_keys)
          Page::Profile::SSHKeys.perform do |ssh_keys|
            ssh_keys.remove_key(key.title)
          end

          expect(page).not_to have_content("Title: #{key.title}")
          expect(page).not_to have_content(key.sha256_fingerprint)
        end
      end
    end
  end
end

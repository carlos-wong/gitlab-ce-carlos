# frozen_string_literal: true

module QA
  context 'Create' do
    describe 'SSH keys support' do
      let(:key_title) { "key for ssh tests #{Time.now.to_f}" }

      it 'user adds and then removes an SSH key', :smoke do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.act { sign_in_using_credentials }

        key = Resource::SSHKey.fabricate! do |resource|
          resource.title = key_title
        end

        expect(page).to have_content("Title: #{key_title}")
        expect(page).to have_content(key.fingerprint)

        Page::Main::Menu.act { click_settings_link }
        Page::Profile::Menu.act { click_ssh_keys }

        Page::Profile::SSHKeys.perform do |ssh_keys|
          ssh_keys.remove_key(key_title)
        end

        expect(page).not_to have_content("Title: #{key_title}")
        expect(page).not_to have_content(key.fingerprint)
      end
    end
  end
end

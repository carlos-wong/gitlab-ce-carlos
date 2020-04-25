# frozen_string_literal: true

module QA
  context 'Create' do
    describe 'Web IDE file templates' do
      include Runtime::Fixtures

      before(:all) do
        @project = Resource::Project.fabricate_via_api! do |project|
          project.name = 'file-template-project'
          project.description = 'Add file templates via the Web IDE'
          project.initialize_with_readme = true
        end
      end

      templates = [
        {
          file_name: '.gitignore',
          name: 'Android',
          api_path: 'gitignores',
          api_key: 'Android'
        },
        {
          file_name: '.gitlab-ci.yml',
          name: 'Julia',
          api_path: 'gitlab_ci_ymls',
          api_key: 'Julia'
        },
        {
          file_name: 'Dockerfile',
          name: 'Python',
          api_path: 'dockerfiles',
          api_key: 'Python'
        },
        {
          file_name: 'LICENSE',
          name: 'Mozilla Public License 2.0',
          api_path: 'licenses',
          api_key: 'mpl-2.0'
        }
      ]

      templates.each do |template|
        it "user adds #{template[:file_name]} via file template #{template[:name]}" do
          content = fetch_template_from_api(template[:api_path], template[:api_key])

          Flow::Login.sign_in

          @project.visit!

          Page::Project::Show.perform(&:open_web_ide!)
          Page::Project::WebIDE::Edit.perform do |ide|
            ide.create_new_file_from_template template[:file_name], template[:name]

            expect(ide.has_file?(template[:file_name])).to be_truthy

            expect(ide).to have_button('Undo')
            expect(ide).to have_normalized_ws_text(content[0..100])

            ide.commit_changes

            expect(ide).to have_content(template[:file_name])
            expect(ide).to have_normalized_ws_text(content[0..100])
          end
        end
      end
    end
  end
end

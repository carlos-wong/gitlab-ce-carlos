# frozen_string_literal: true

module QA
  module Resource
    class DeployToken < Base
      attr_accessor :name, :expires_at

      attribute :username do
        Page::Project::Settings::CICD.perform do |cicd_page|
          cicd_page.expand_deploy_tokens do |token|
            token.token_username
          end
        end
      end

      attribute :password do
        Page::Project::Settings::CICD.perform do |cicd_page|
          cicd_page.expand_deploy_tokens do |token|
            token.token_password
          end
        end
      end

      attribute :project do
        Project.fabricate! do |resource|
          resource.name = 'project-to-deploy'
          resource.description = 'project for adding deploy token test'
        end
      end

      def fabricate!
        project.visit!

        Page::Project::Menu.perform(&:go_to_ci_cd_settings)

        Page::Project::Settings::CICD.perform do |cicd|
          cicd.expand_deploy_tokens do |page|
            page.fill_token_name(name)
            page.fill_token_expires_at(expires_at)
            page.fill_scopes(read_repository: true, read_registry: false)

            page.add_token
          end
        end
      end
    end
  end
end

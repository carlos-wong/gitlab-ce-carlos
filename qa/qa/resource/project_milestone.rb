# frozen_string_literal: true

module QA
  module Resource
    class ProjectMilestone < Base
      attr_reader :title
      attr_accessor :description

      attribute :project do
        Project.fabricate!
      end

      def title=(title)
        @title = "#{title}-#{SecureRandom.hex(4)}"
        @description = 'A milestone'
      end

      def fabricate!
        project.visit!

        Page::Project::Menu.perform do |page|
          page.click_issues
          page.click_milestones
        end

        Page::Project::Milestone::Index.perform(&:click_new_milestone)

        Page::Project::Milestone::New.perform do |milestone_new|
          milestone_new.set_title(@title)
          milestone_new.set_description(@description)
          milestone_new.click_milestone_create_button
        end
      end
    end
  end
end

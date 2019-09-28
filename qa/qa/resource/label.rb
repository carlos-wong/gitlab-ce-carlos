# frozen_string_literal: true

require 'securerandom'

module QA
  module Resource
    class Label < Base
      attr_accessor :description, :color

      attribute :id
      attribute :title

      attribute :project do
        Project.fabricate! do |resource|
          resource.name = 'project-with-label'
        end
      end

      def initialize
        @title = "qa-test-#{SecureRandom.hex(8)}"
        @description = 'This is a test label'
        @color = '#0033CC'
      end

      def fabricate!
        project.visit!

        Page::Project::Menu.perform(&:go_to_labels)
        Page::Label::Index.perform(&:click_new_label_button)

        Page::Label::New.perform do |page| # rubocop:disable QA/AmbiguousPageObjectName
          page.fill_title(@title)
          page.fill_description(@description)
          page.fill_color(@color)
          page.click_label_create_button
        end
      end

      def resource_web_url(resource)
        super
      rescue ResourceURLMissingError
        # this particular resource does not expose a web_url property
      end

      def api_get_path
        raise NotImplementedError, "The Labels API doesn't expose a single-resource endpoint so this method cannot be properly implemented."
      end

      def api_post_path
        "/projects/#{project.id}/labels"
      end

      def api_post_body
        {
          color: @color,
          name: @title
        }
      end
    end
  end
end

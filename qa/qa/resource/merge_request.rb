# frozen_string_literal: true

require 'securerandom'

module QA
  module Resource
    class MergeRequest < Base
      attr_accessor :title,
                    :description,
                    :source_branch,
                    :target_branch,
                    :assignee,
                    :milestone,
                    :labels,
                    :file_name,
                    :file_content

      attribute :project do
        Project.fabricate! do |resource|
          resource.name = 'project-with-merge-request'
        end
      end

      attribute :target do
        project.visit!

        Repository::ProjectPush.fabricate! do |resource|
          resource.project = project
          resource.branch_name = 'master'
          resource.remote_branch = target_branch
        end
      end

      attribute :source do
        Repository::ProjectPush.fabricate! do |resource|
          resource.project = project
          resource.branch_name = target_branch
          resource.remote_branch = source_branch
          resource.new_branch = false
          resource.file_name = file_name
          resource.file_content = file_content
        end
      end

      def initialize
        @title = 'QA test - merge request'
        @description = 'This is a test merge request'
        @source_branch = "qa-test-feature-#{SecureRandom.hex(8)}"
        @target_branch = "master"
        @assignee = nil
        @milestone = nil
        @labels = []
        @file_name = "added_file.txt"
        @file_content = "File Added"
      end

      def fabricate!
        populate(:target, :source)

        project.visit!
        Page::Project::Show.perform(&:new_merge_request)
        Page::MergeRequest::New.perform do |page|
          page.fill_title(@title)
          page.fill_description(@description)
          page.choose_milestone(@milestone) if @milestone
          page.assign_to_me if @assignee == 'me'
          labels.each do |label|
            page.select_label(label)
          end

          page.create_merge_request
        end
      end
    end
  end
end

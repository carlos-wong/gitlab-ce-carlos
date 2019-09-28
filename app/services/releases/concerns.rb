# frozen_string_literal: true

module Releases
  module Concerns
    extend ActiveSupport::Concern
    include Gitlab::Utils::StrongMemoize

    included do
      def tag_name
        params[:tag]
      end

      def ref
        params[:ref]
      end

      def name
        params[:name] || tag_name
      end

      def description
        params[:description]
      end

      def released_at
        params[:released_at]
      end

      def release
        strong_memoize(:release) do
          project.releases.find_by_tag(tag_name)
        end
      end

      def existing_tag
        strong_memoize(:existing_tag) do
          repository.find_tag(tag_name)
        end
      end

      def tag_exist?
        existing_tag.present?
      end

      def repository
        strong_memoize(:repository) do
          project.repository
        end
      end

      def milestones
        return [] unless param_for_milestone_titles_provided?

        strong_memoize(:milestones) do
          MilestonesFinder.new(
            project: project,
            current_user: current_user,
            project_ids: Array(project.id),
            state: 'all',
            title: params[:milestones]
          ).execute
        end
      end

      def inexistent_milestones
        return [] unless param_for_milestone_titles_provided?

        existing_milestone_titles = milestones.map(&:title)
        Array(params[:milestones]) - existing_milestone_titles
      end

      def param_for_milestone_titles_provided?
        params.key?(:milestones)
      end
    end
  end
end

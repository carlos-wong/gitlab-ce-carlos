# frozen_string_literal: true

module Releases
  class UpdateService < BaseService
    include Releases::Concerns

    def execute
      return error('Tag does not exist', 404) unless existing_tag
      return error('Release does not exist', 404) unless release
      return error('Access Denied', 403) unless allowed?
      return error('params is empty', 400) if empty_params?
      return error("Milestone(s) not found: #{inexistent_milestones.join(', ')}", 400) if inexistent_milestones.any?

      params[:milestones] = milestones if param_for_milestone_titles_provided?

      if release.update(params)
        success(tag: existing_tag, release: release)
      else
        error(release.errors.messages || '400 Bad request', 400)
      end
    end

    private

    def allowed?
      Ability.allowed?(current_user, :update_release, release)
    end

    def empty_params?
      params.except(:tag).empty?
    end
  end
end

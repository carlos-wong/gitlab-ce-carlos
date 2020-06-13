# frozen_string_literal: true

module Projects
  module Settings
    class RepositoryController < Projects::ApplicationController
      before_action :authorize_admin_project!
      before_action :remote_mirror, only: [:show]

      def show
        render_show
      end

      def cleanup
        cleanup_params = params.require(:project).permit(:bfg_object_map)
        result = Projects::UpdateService.new(project, current_user, cleanup_params).execute

        if result[:status] == :success
          RepositoryCleanupWorker.perform_async(project.id, current_user.id) # rubocop:disable CodeReuse/Worker
          flash[:notice] = _('Repository cleanup has started. You will receive an email once the cleanup operation is complete.')
        else
          flash[:alert] = _('Failed to upload object map file')
        end

        redirect_to project_settings_repository_path(project)
      end

      private

      def render_show
        define_protected_refs
        remote_mirror

        render 'show'
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def define_protected_refs
        @protected_branches = @project.protected_branches.order(:name).page(params[:page])
        @protected_tags = @project.protected_tags.order(:name).page(params[:page])
        @protected_branch = @project.protected_branches.new
        @protected_tag = @project.protected_tags.new

        @protected_branches_count = @protected_branches.reduce(0) { |sum, branch| sum + branch.matching(@project.repository.branches).size }
        @protected_tags_count = @protected_tags.reduce(0) { |sum, tag| sum + tag.matching(@project.repository.tags).size }

        load_gon_index
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def remote_mirror
        @remote_mirror = project.remote_mirrors.first_or_initialize
      end

      def access_levels_options
        {
          create_access_levels: levels_for_dropdown,
          push_access_levels: levels_for_dropdown,
          merge_access_levels: levels_for_dropdown
        }
      end

      def levels_for_dropdown
        roles = ProtectedRefAccess::HUMAN_ACCESS_LEVELS.map do |id, text|
          { id: id, text: text, before_divider: true }
        end
        { roles: roles }
      end

      def protectable_tags_for_dropdown
        { open_tags: ProtectableDropdown.new(@project, :tags).hash }
      end

      def protectable_branches_for_dropdown
        { open_branches: ProtectableDropdown.new(@project, :branches).hash }
      end

      def load_gon_index
        gon.push(protectable_tags_for_dropdown)
        gon.push(protectable_branches_for_dropdown)
        gon.push(access_levels_options)
      end
    end
  end
end

Projects::Settings::RepositoryController.prepend_if_ee('EE::Projects::Settings::RepositoryController')

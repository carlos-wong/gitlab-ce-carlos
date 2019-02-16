# frozen_string_literal: true

module ProtectedBranches
  class ApiService < BaseService
    def create
      @push_params = AccessLevelParams.new(:push, params)
      @merge_params = AccessLevelParams.new(:merge, params)

      protected_branch_params = {
        name: params[:name],
        push_access_levels_attributes: @push_params.access_levels,
        merge_access_levels_attributes: @merge_params.access_levels
      }

      ::ProtectedBranches::CreateService.new(@project, @current_user, protected_branch_params).execute
    end
  end
end

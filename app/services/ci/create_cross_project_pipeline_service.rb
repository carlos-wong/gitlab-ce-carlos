# frozen_string_literal: true

module Ci
  # TODO: rename this (and worker) to CreateDownstreamPipelineService
  class CreateCrossProjectPipelineService < ::BaseService
    include Gitlab::Utils::StrongMemoize

    DuplicateDownstreamPipelineError = Class.new(StandardError)

    def execute(bridge)
      @bridge = bridge

      if bridge.has_downstream_pipeline?
        Gitlab::ErrorTracking.track_exception(
          DuplicateDownstreamPipelineError.new,
          bridge_id: @bridge.id, project_id: @bridge.project_id
        )
        return
      end

      pipeline_params = @bridge.downstream_pipeline_params
      target_ref = pipeline_params.dig(:target_revision, :ref)

      return unless ensure_preconditions!(target_ref)

      service = ::Ci::CreatePipelineService.new(
        pipeline_params.fetch(:project),
        current_user,
        pipeline_params.fetch(:target_revision))

      downstream_pipeline = service.execute(
        pipeline_params.fetch(:source), pipeline_params[:execute_params]) do |pipeline|
          pipeline.variables.build(@bridge.downstream_variables)
        end

      downstream_pipeline.tap do |pipeline|
        next if Feature.disabled?(:ci_drop_bridge_on_downstream_errors, project, default_enabled: true)

        update_bridge_status!(@bridge, pipeline)
      end
    end

    private

    def update_bridge_status!(bridge, pipeline)
      Gitlab::OptimisticLocking.retry_lock(bridge) do |subject|
        if pipeline.created_successfully?
          # If bridge uses `strategy:depend` we leave it running
          # and update the status when the downstream pipeline completes.
          subject.success! unless subject.dependent?
        else
          subject.drop!(:downstream_pipeline_creation_failed)
        end
      end
    rescue StateMachines::InvalidTransition => e
      Gitlab::ErrorTracking.track_exception(
        Ci::Bridge::InvalidTransitionError.new(e.message),
        bridge_id: bridge.id,
        downstream_pipeline_id: pipeline.id)
    end

    def ensure_preconditions!(target_ref)
      unless downstream_project_accessible?
        @bridge.drop!(:downstream_bridge_project_not_found)
        return false
      end

      # TODO: Remove this condition if favour of model validation
      # https://gitlab.com/gitlab-org/gitlab/issues/38338
      if downstream_project == project && !@bridge.triggers_child_pipeline?
        @bridge.drop!(:invalid_bridge_trigger)
        return false
      end

      # TODO: Remove this condition if favour of model validation
      # https://gitlab.com/gitlab-org/gitlab/issues/38338
      if @bridge.triggers_child_pipeline? && @bridge.pipeline.parent_pipeline.present?
        @bridge.drop!(:bridge_pipeline_is_child_pipeline)
        return false
      end

      unless can_create_downstream_pipeline?(target_ref)
        @bridge.drop!(:insufficient_bridge_permissions)
        return false
      end

      true
    end

    def downstream_project_accessible?
      downstream_project.present? &&
        can?(current_user, :read_project, downstream_project)
    end

    def can_create_downstream_pipeline?(target_ref)
      can?(current_user, :update_pipeline, project) &&
        can?(current_user, :create_pipeline, downstream_project) &&
          can_update_branch?(target_ref)
    end

    def can_update_branch?(target_ref)
      ::Gitlab::UserAccess.new(current_user, project: downstream_project).can_update_branch?(target_ref)
    end

    def downstream_project
      strong_memoize(:downstream_project) do
        @bridge.downstream_project
      end
    end
  end
end

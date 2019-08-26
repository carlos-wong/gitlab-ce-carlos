# frozen_string_literal: true

class StageEntity < Grape::Entity
  include RequestAwareEntity

  expose :name

  expose :title do |stage|
    "#{stage.name}: #{detailed_status.label}"
  end

  expose :groups,
    if: -> (_, opts) { opts[:grouped] },
    with: JobGroupEntity

  expose :latest_statuses,
    if: -> (_, opts) { opts[:details] },
    with: JobEntity do |stage|
    latest_statuses
  end

  expose :retried,
         if: -> (_, opts) { opts[:retried] },
         with: JobEntity do |stage|
    retried_statuses
  end

  expose :detailed_status, as: :status, with: DetailedStatusEntity

  expose :path do |stage|
    project_pipeline_path(
      stage.pipeline.project,
      stage.pipeline,
      anchor: stage.name)
  end

  expose :dropdown_path do |stage|
    stage_project_pipeline_path(
      stage.pipeline.project,
      stage.pipeline,
      stage: stage.name,
      format: :json)
  end

  private

  alias_method :stage, :object

  def detailed_status
    stage.detailed_status(request.current_user)
  end

  def grouped_statuses
    @grouped_statuses ||= stage.statuses.latest_ordered.group_by(&:status)
  end

  def grouped_retried_statuses
    @grouped_retried_statuses ||= stage.statuses.retried_ordered.group_by(&:status)
  end

  def latest_statuses
    HasStatus::ORDERED_STATUSES.flat_map do |ordered_status|
      grouped_statuses.fetch(ordered_status, [])
    end
  end

  def retried_statuses
    HasStatus::ORDERED_STATUSES.flat_map do |ordered_status|
      grouped_retried_statuses.fetch(ordered_status, [])
    end
  end
end

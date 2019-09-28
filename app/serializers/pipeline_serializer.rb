# frozen_string_literal: true

class PipelineSerializer < BaseSerializer
  include WithPagination
  entity PipelineDetailsEntity

  # rubocop: disable CodeReuse/ActiveRecord
  def represent(resource, opts = {})
    if resource.is_a?(ActiveRecord::Relation)
      resource = resource.preload(preloaded_relations)
    end

    if paginated?
      resource = paginator.paginate(resource)
    end

    if opts.delete(:preload)
      resource = Gitlab::Ci::Pipeline::Preloader.preload!(resource)
    end

    super(resource, opts)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def represent_status(resource)
    return {} unless resource.present?

    data = represent(resource, { only: [{ details: [:status] }] })
    data.dig(:details, :status) || {}
  end

  def represent_stages(resource)
    return {} unless resource.present?

    data = represent(resource, { only: [{ details: [:stages] }], preload: true })
    data.dig(:details, :stages) || []
  end

  private

  def preloaded_relations
    [
      :stages,
      :retryable_builds,
      :cancelable_statuses,
      :trigger_requests,
      :manual_actions,
      :scheduled_actions,
      :artifacts,
      :merge_request,
      {
        pending_builds: :project,
        project: [:route, { namespace: :route }],
        artifacts: {
          project: [:route, { namespace: :route }]
        }
      }
    ]
  end
end

PipelineSerializer.prepend_if_ee('EE::PipelineSerializer')

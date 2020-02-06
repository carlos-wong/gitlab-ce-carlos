# frozen_string_literal: true

module Ci
  class LegacyStagePresenter < Gitlab::View::Presenter::Delegated
    presents :legacy_stage

    def latest_ordered_statuses
      preload_statuses(legacy_stage.statuses.latest_ordered)
    end

    def retried_ordered_statuses
      preload_statuses(legacy_stage.statuses.retried_ordered)
    end

    private

    def preload_statuses(statuses)
      loaded_statuses = statuses.load
      statuses.tap do |statuses|
        # rubocop: disable CodeReuse/ActiveRecord
        ActiveRecord::Associations::Preloader.new.preload(preloadable_statuses(loaded_statuses), %w[tags job_artifacts_archive metadata])
        # rubocop: enable CodeReuse/ActiveRecord
      end
    end

    def preloadable_statuses(statuses)
      statuses.reject do |status|
        status.instance_of?(::GenericCommitStatus) || status.instance_of?(::Ci::Bridge)
      end
    end
  end
end

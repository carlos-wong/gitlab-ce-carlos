# frozen_string_literal: true

class PipelineScheduleWorker
  include ApplicationWorker
  include CronjobQueue

  feature_category :continuous_integration
  worker_resource_boundary :cpu

  def perform
    Ci::PipelineSchedule.runnable_schedules.preloaded.find_in_batches do |schedules|
      schedules.each do |schedule|
        with_context(project: schedule.project, user: schedule.owner) do
          Ci::PipelineScheduleService.new(schedule.project, schedule.owner).execute(schedule)
        end
      end
    end
  end
end

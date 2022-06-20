# frozen_string_literal: true

module QA
  module Flow
    module Pipeline
      module_function

      # Acceptable statuses:
      # canceled, created, failed, manual, passed
      # pending, running, skipped
      def visit_latest_pipeline(status: nil, wait: nil, skip_wait: true)
        Page::Project::Menu.perform(&:click_ci_cd_pipelines)
        Page::Project::Pipeline::Index.perform do |index|
          index.has_any_pipeline?(wait: wait)
          index.wait_for_latest_pipeline(status: status, wait: wait) if status || !skip_wait
          index.click_on_latest_pipeline
        end
      end

      def wait_for_latest_pipeline(status: nil, wait: nil)
        Page::Project::Menu.perform(&:click_ci_cd_pipelines)
        Page::Project::Pipeline::Index.perform do |index|
          index.has_any_pipeline?(wait: wait)
          index.wait_for_latest_pipeline(status: status, wait: wait)
        end
      end
    end
  end
end

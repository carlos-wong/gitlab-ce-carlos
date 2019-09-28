# frozen_string_literal: true

module Ci
  class ProcessBuildService < BaseService
    def execute(build, current_status)
      if valid_statuses_for_when(build.when).include?(current_status)
        if build.schedulable?
          build.schedule
        elsif build.action?
          build.actionize
        else
          enqueue(build)
        end

        true
      else
        build.skip
        false
      end
    end

    private

    def enqueue(build)
      build.enqueue
    end

    def valid_statuses_for_when(value)
      case value
      when 'on_success'
        %w[success skipped]
      when 'on_failure'
        %w[failed]
      when 'always'
        %w[success failed skipped]
      when 'manual'
        %w[success skipped]
      when 'delayed'
        %w[success skipped]
      else
        []
      end
    end
  end
end

Ci::ProcessBuildService.prepend_if_ee('EE::Ci::ProcessBuildService')

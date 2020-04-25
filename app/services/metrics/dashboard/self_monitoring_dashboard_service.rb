# frozen_string_literal: true

# Fetches the self monitoring metrics dashboard and formats the output.
# Use Gitlab::Metrics::Dashboard::Finder to retrieve dashboards.
module Metrics
  module Dashboard
    class SelfMonitoringDashboardService < ::Metrics::Dashboard::PredefinedDashboardService
      DASHBOARD_PATH = 'config/prometheus/self_monitoring_default.yml'
      DASHBOARD_NAME = 'Default'

      SEQUENCE = [
        STAGES::ProjectMetricsInserter,
        STAGES::EndpointInserter,
        STAGES::Sorter
      ].freeze

      class << self
        def valid_params?(params)
          matching_dashboard?(params[:dashboard_path]) || self_monitoring_project?(params)
        end

        def all_dashboard_paths(_project)
          [{
            path: DASHBOARD_PATH,
            display_name: DASHBOARD_NAME,
            default: true,
            system_dashboard: false
          }]
        end

        def self_monitoring_project?(params)
          params[:dashboard_path].nil? && params[:environment]&.project&.self_monitoring?
        end
      end
    end
  end
end

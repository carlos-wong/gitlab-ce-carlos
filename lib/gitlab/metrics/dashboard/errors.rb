# frozen_string_literal: true

# Central point for managing errors from within the metrics
# dashboard module. Handles errors from dashboard retrieval
# and processing steps, as well as defines shared error classes.
module Gitlab
  module Metrics
    module Dashboard
      module Errors
        DashboardProcessingError = Class.new(StandardError)
        PanelNotFoundError = Class.new(StandardError)
        MissingIntegrationError = Class.new(StandardError)
        LayoutError = Class.new(DashboardProcessingError)
        MissingQueryError = Class.new(DashboardProcessingError)

        NOT_FOUND_ERROR = Gitlab::Template::Finders::RepoTemplateFinder::FileNotFoundError

        def handle_errors(error)
          case error
          when DashboardProcessingError
            error(error.message, :unprocessable_entity)
          when NOT_FOUND_ERROR
            error("#{dashboard_path} could not be found.", :not_found)
          when PanelNotFoundError
            error(error.message, :not_found)
          when ::Grafana::Client::Error
            error(error.message, :service_unavailable)
          when MissingIntegrationError
            error('Proxy support for this API is not available currently', :bad_request)
          else
            raise error
          end
        end

        def panels_not_found!(opts)
          raise PanelNotFoundError.new("No panels matching properties #{opts}")
        end
      end
    end
  end
end

# frozen_string_literal: true

# Searches a projects repository for a metrics dashboard and formats the output.
# Expects any custom dashboards will be located in `.gitlab/dashboards`
module Gitlab
  module Metrics
    module Dashboard
      class BaseService < ::BaseService
        PROCESSING_ERROR = Gitlab::Metrics::Dashboard::Stages::BaseStage::DashboardProcessingError
        NOT_FOUND_ERROR = Gitlab::Template::Finders::RepoTemplateFinder::FileNotFoundError

        def get_dashboard
          success(dashboard: process_dashboard)
        rescue NOT_FOUND_ERROR
          error("#{dashboard_path} could not be found.", :not_found)
        rescue PROCESSING_ERROR => e
          error(e.message, :unprocessable_entity)
        end

        # Summary of all known dashboards for the service.
        # @return [Array<Hash>] ex) [{ path: String, default: Boolean }]
        def self.all_dashboard_paths(_project)
          raise NotImplementedError
        end

        private

        # Returns a new dashboard Hash, supplemented with DB info
        def process_dashboard
          Gitlab::Metrics::Dashboard::Processor
            .new(project, params[:environment], raw_dashboard)
            .process(insert_project_metrics: insert_project_metrics?)
        end

        # @return [String] Relative filepath of the dashboard yml
        def dashboard_path
          params[:dashboard_path]
        end

        # Returns an un-processed dashboard from the cache.
        def raw_dashboard
          Gitlab::Metrics::Dashboard::Cache.fetch(cache_key) { get_raw_dashboard }
        end

        # @return [Hash] an unmodified dashboard
        def get_raw_dashboard
          raise NotImplementedError
        end

        # @return [String]
        def cache_key
          raise NotImplementedError
        end

        # Determines whether custom metrics should be included
        # in the processed output.
        def insert_project_metrics?
          false
        end
      end
    end
  end
end

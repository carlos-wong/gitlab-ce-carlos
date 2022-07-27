# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      class CoverageReportGenerator
        include Gitlab::Utils::StrongMemoize

        def initialize(pipeline)
          @pipeline = pipeline
        end

        def report
          coverage_report = Gitlab::Ci::Reports::CoverageReport.new

          # Return an empty report if the pipeline is a child pipeline.
          # Since the coverage report is used in a merge request report,
          # we are only interested in the coverage report from the root pipeline.
          return coverage_report if @pipeline.child?

          coverage_report.tap do |coverage_report|
            report_builds.find_each do |build|
              build.each_report(::Ci::JobArtifact::COVERAGE_REPORT_FILE_TYPES) do |file_type, blob|
                Gitlab::Ci::Parsers.fabricate!(file_type).parse!(
                  blob,
                  coverage_report,
                  project_path: @pipeline.project.full_path,
                  worktree_paths: @pipeline.all_worktree_paths
                )
              end
            end
          end
        end

        private

        def report_builds
          @pipeline.latest_report_builds_in_self_and_descendants(::Ci::JobArtifact.coverage_reports)
        end
      end
    end
  end
end

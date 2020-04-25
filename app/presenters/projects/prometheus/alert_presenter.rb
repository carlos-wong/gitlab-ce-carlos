# frozen_string_literal: true

module Projects
  module Prometheus
    class AlertPresenter < Gitlab::View::Presenter::Delegated
      RESERVED_ANNOTATIONS = %w(gitlab_incident_markdown title).freeze
      GENERIC_ALERT_SUMMARY_ANNOTATIONS = %w(monitoring_tool service hosts).freeze
      MARKDOWN_LINE_BREAK = "  \n".freeze

      def full_title
        [environment_name, alert_title].compact.join(': ')
      end

      def project_full_path
        project.full_path
      end

      def metric_query
        gitlab_alert&.full_query
      end

      def environment_name
        environment&.name
      end

      def performance_dashboard_link
        if environment
          metrics_project_environment_url(project, environment)
        else
          metrics_project_environments_url(project)
        end
      end

      def starts_at
        super&.rfc3339
      end

      def issue_summary_markdown
        <<~MARKDOWN.chomp
          #### Summary

          #{metadata_list}
          #{alert_details}
        MARKDOWN
      end

      private

      def alert_title
        query_title || title
      end

      def query_title
        return unless gitlab_alert

        "#{gitlab_alert.title} #{gitlab_alert.computed_operator} #{gitlab_alert.threshold} for 5 minutes"
      end

      def metadata_list
        metadata = []

        metadata << list_item('Start time', starts_at) if starts_at
        metadata << list_item('full_query', backtick(full_query)) if full_query
        metadata << list_item(service.label.humanize, service.value) if service
        metadata << list_item(monitoring_tool.label.humanize, monitoring_tool.value) if monitoring_tool
        metadata << list_item(hosts.label.humanize, host_links) if hosts

        metadata.join(MARKDOWN_LINE_BREAK)
      end

      def alert_details
        if annotation_list.present?
          <<~MARKDOWN.chomp

            #### Alert Details

            #{annotation_list}
          MARKDOWN
        end
      end

      def annotation_list
        strong_memoize(:annotation_list) do
          annotations
            .reject { |annotation| annotation.label.in?(RESERVED_ANNOTATIONS | GENERIC_ALERT_SUMMARY_ANNOTATIONS) }
            .map { |annotation| list_item(annotation.label, annotation.value) }
            .join(MARKDOWN_LINE_BREAK)
        end
      end

      def list_item(key, value)
        "**#{key}:** #{value}".strip
      end

      def backtick(value)
        "`#{value}`"
      end

      GENERIC_ALERT_SUMMARY_ANNOTATIONS.each do |annotation_name|
        define_method(annotation_name) do
          annotations.find { |a| a.label == annotation_name }
        end
      end

      def host_links
        Array(hosts.value).join(' ')
      end
    end
  end
end

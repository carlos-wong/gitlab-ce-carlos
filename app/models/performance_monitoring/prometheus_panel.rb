# frozen_string_literal: true

module PerformanceMonitoring
  class PrometheusPanel
    include ActiveModel::Model

    attr_accessor :type, :title, :y_label, :weight, :metrics

    validates :title, presence: true
    validates :metrics, presence: true

    def self.from_json(json_content)
      panel = new(
        type: json_content['type'],
        title: json_content['title'],
        y_label: json_content['y_label'],
        weight: json_content['weight'],
        metrics: json_content['metrics'].map { |metric| PrometheusMetric.from_json(metric) }
      )

      panel.tap(&:validate!)
    end
  end
end

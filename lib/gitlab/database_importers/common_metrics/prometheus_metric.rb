# frozen_string_literal: true

module Gitlab
  module DatabaseImporters
    module CommonMetrics
      class PrometheusMetric < ApplicationRecord
        enum group: PrometheusMetricEnums.groups
        scope :common, -> { where(common: true) }
      end
    end
  end
end

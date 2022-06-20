# frozen_string_literal: true

RSpec.shared_context 'stubbed service ping metrics definitions' do
  include UsageDataHelpers

  let(:metrics_definitions) { standard_metrics + subscription_metrics + operational_metrics + optional_metrics }
  let(:standard_metrics) do
    [
      metric_attributes('uuid', 'standard'),
      metric_attributes('recorded_at', 'standard'),
      metric_attributes('settings.collected_data_categories', 'standard', 'object')
    ]
  end

  let(:operational_metrics) do
    [
      metric_attributes('counts.merge_requests', 'operational'),
      metric_attributes('counts.todos', "operational")
    ]
  end

  let(:optional_metrics) do
    [
      metric_attributes('counts.boards', 'optional', 'number', 'CountBoardsMetric'),
      metric_attributes('gitaly.filesystems', '').except('data_category'),
      metric_attributes('usage_activity_by_stage.monitor.projects_with_enabled_alert_integrations_histogram', 'optional', 'object'),
      metric_attributes('topology', 'optional', 'object')
    ]
  end

  before do
    stub_usage_data_connections
    stub_object_store_settings

    allow(Gitlab::Usage::MetricDefinition).to(
      receive(:definitions)
        .and_return(metrics_definitions.to_h { |definition| [definition['key_path'], Gitlab::Usage::MetricDefinition.new('', definition.symbolize_keys)] })
    )
  end

  after do |example|
    Gitlab::Usage::Metric.instance_variable_set(:@all, nil)
    Gitlab::Usage::MetricDefinition.instance_variable_set(:@all, nil)
  end

  def metric_attributes(key_path, category, value_type = 'string', instrumentation_class = '')
    {
      'key_path' => key_path,
      'data_category' => category,
      'value_type' => value_type,
      'status' => 'active',
      'instrumentation_class' => instrumentation_class,
      'time_frame' => 'all'
    }
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::ServicePingReport, :use_clean_rails_memory_store_caching do
  include UsageDataHelpers

  let(:usage_data) { { uuid: "1111", counts: { issue: 0 } } }

  before do
    allow_next_instance_of(Gitlab::Usage::ServicePing::PayloadKeysProcessor) do |instance|
      allow(instance).to receive(:missing_key_paths).and_return([])
    end

    allow_next_instance_of(Gitlab::Usage::ServicePing::InstrumentedPayload) do |instance|
      allow(instance).to receive(:build).and_return({})
    end
  end

  context 'all_metrics_values' do
    it 'generates the service ping when there are no missing values' do
      expect(Gitlab::UsageData).to receive(:data).and_return(usage_data)
      expect(described_class.for(output: :all_metrics_values)).to eq({ uuid: "1111", counts: { issue: 0 } })
    end

    it 'generates the service ping with the missing values' do
      expect_next_instance_of(Gitlab::Usage::ServicePing::PayloadKeysProcessor, usage_data) do |instance|
        expect(instance).to receive(:missing_instrumented_metrics_key_paths).and_return(['counts.boards'])
      end

      expect_next_instance_of(Gitlab::Usage::ServicePing::InstrumentedPayload, ['counts.boards'], :with_value) do |instance|
        expect(instance).to receive(:build).and_return({ counts: { boards: 1 } })
      end

      expect(Gitlab::UsageData).to receive(:data).and_return(usage_data)
      expect(described_class.for(output: :all_metrics_values)).to eq({ uuid: "1111", counts: { issue: 0, boards: 1 } })
    end
  end

  context 'for output: :metrics_queries' do
    it 'generates the service ping' do
      expect(Gitlab::UsageData).to receive(:data).and_return(usage_data)

      described_class.for(output: :metrics_queries)
    end
  end

  context 'for output: :non_sql_metrics_values' do
    it 'generates the service ping' do
      expect(Gitlab::UsageData).to receive(:data).and_return(usage_data)

      described_class.for(output: :non_sql_metrics_values)
    end
  end

  context 'when using cached' do
    context 'for cached: true' do
      let(:new_usage_data) { { uuid: "1112" } }

      it 'caches the values' do
        allow(Gitlab::UsageData).to receive(:data).and_return(usage_data, new_usage_data)

        expect(described_class.for(output: :all_metrics_values)).to eq(usage_data)
        expect(described_class.for(output: :all_metrics_values, cached: true)).to eq(usage_data)

        expect(Rails.cache.fetch('usage_data')).to eq(usage_data)
      end

      it 'writes to cache and returns fresh data' do
        allow(Gitlab::UsageData).to receive(:data).and_return(usage_data, new_usage_data)

        expect(described_class.for(output: :all_metrics_values)).to eq(usage_data)
        expect(described_class.for(output: :all_metrics_values)).to eq(new_usage_data)
        expect(described_class.for(output: :all_metrics_values, cached: true)).to eq(new_usage_data)

        expect(Rails.cache.fetch('usage_data')).to eq(new_usage_data)
      end
    end

    context 'when no caching' do
      let(:new_usage_data) { { uuid: "1112" } }

      it 'returns fresh data' do
        allow(Gitlab::UsageData).to receive(:data).and_return(usage_data, new_usage_data)

        expect(described_class.for(output: :all_metrics_values)).to eq(usage_data)
        expect(described_class.for(output: :all_metrics_values)).to eq(new_usage_data)

        expect(Rails.cache.fetch('usage_data')).to eq(new_usage_data)
      end
    end
  end

  context 'cross test values against queries' do
    # TODO: fix failing metrics https://gitlab.com/gitlab-org/gitlab/-/issues/353559
    let(:failing_todo_metrics) do
      ["counts.labels",
       "counts.jira_imports_total_imported_issues_count",
       "counts.in_product_marketing_email_create_0_sent",
       "counts.in_product_marketing_email_create_0_cta_clicked",
       "counts.in_product_marketing_email_create_1_sent",
       "counts.in_product_marketing_email_create_1_cta_clicked",
       "counts.in_product_marketing_email_create_2_sent",
       "counts.in_product_marketing_email_create_2_cta_clicked",
       "counts.in_product_marketing_email_verify_0_sent",
       "counts.in_product_marketing_email_verify_0_cta_clicked",
       "counts.in_product_marketing_email_verify_1_sent",
       "counts.in_product_marketing_email_verify_1_cta_clicked",
       "counts.in_product_marketing_email_verify_2_sent",
       "counts.in_product_marketing_email_verify_2_cta_clicked",
       "counts.in_product_marketing_email_trial_0_sent",
       "counts.in_product_marketing_email_trial_0_cta_clicked",
       "counts.in_product_marketing_email_trial_1_sent",
       "counts.in_product_marketing_email_trial_1_cta_clicked",
       "counts.in_product_marketing_email_trial_2_sent",
       "counts.in_product_marketing_email_trial_2_cta_clicked",
       "counts.in_product_marketing_email_team_0_sent",
       "counts.in_product_marketing_email_team_0_cta_clicked",
       "counts.in_product_marketing_email_team_1_sent",
       "counts.in_product_marketing_email_team_1_cta_clicked",
       "counts.in_product_marketing_email_team_2_sent",
       "counts.in_product_marketing_email_team_2_cta_clicked",
       "counts.in_product_marketing_email_experience_0_sent",
       "counts.in_product_marketing_email_team_short_0_sent",
       "counts.in_product_marketing_email_team_short_0_cta_clicked",
       "counts.in_product_marketing_email_trial_short_0_sent",
       "counts.in_product_marketing_email_trial_short_0_cta_clicked",
       "counts.in_product_marketing_email_admin_verify_0_sent",
       "counts.in_product_marketing_email_admin_verify_0_cta_clicked",
       "counts.ldap_users",
       "usage_activity_by_stage.create.projects_with_sectional_code_owner_rules",
       "usage_activity_by_stage.monitor.clusters_integrations_prometheus",
       "usage_activity_by_stage.monitor.projects_with_enabled_alert_integrations_histogram",
       "usage_activity_by_stage_monthly.create.projects_with_sectional_code_owner_rules",
       "usage_activity_by_stage_monthly.monitor.clusters_integrations_prometheus"]
    end

    def fetch_value_by_query(query)
      # Because test cases are run inside a transaction, if any query raise and error all queries that follows
      # it are automatically canceled by PostgreSQL, to avoid that problem, and to provide exhaustive information
      # about every metric, queries are wrapped explicitly in sub transactions.
      ApplicationRecord.transaction do
        ApplicationRecord.connection.execute(query)&.first&.values&.first
      end
    rescue ActiveRecord::StatementInvalid => e
      e.message
    end

    def build_payload_from_queries(payload, accumulator = [], key_path = [])
      payload.each do |key, value|
        if value.is_a?(Hash)
          build_payload_from_queries(value, accumulator, key_path.dup << key)
        elsif value.is_a?(String) && /SELECT .* FROM.*/ =~ value
          accumulator << [key_path.dup << key, value, fetch_value_by_query(value)]
        end
      end
      accumulator
    end

    before do
      stub_usage_data_connections
      stub_object_store_settings
      stub_prometheus_queries
      memoized_constatns = Gitlab::UsageData::CE_MEMOIZED_VALUES
      memoized_constatns += Gitlab::UsageData::EE_MEMOIZED_VALUES if defined? Gitlab::UsageData::EE_MEMOIZED_VALUES
      memoized_constatns.each { |v| Gitlab::UsageData.clear_memoization(v) }
      stub_database_flavor_check('Cloud SQL for PostgreSQL')
    end

    let(:service_ping_payload) { described_class.for(output: :all_metrics_values) }
    let(:metrics_queries_with_values) { build_payload_from_queries(described_class.for(output: :metrics_queries)) }

    it 'generates queries that match collected data', :aggregate_failures do
      message = "Expected %{query} result to match %{value} for %{key_path} metric"

      metrics_queries_with_values.each do |key_path, query, value|
        next if failing_todo_metrics.include?(key_path.join('.'))

        expect(value).to(
          eq(service_ping_payload.dig(*key_path)),
          message % { query: query, value: (value || 'NULL'), key_path: key_path.join('.') }
        )
      end
    end
  end
end

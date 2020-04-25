# frozen_string_literal: true

require 'spec_helper'

describe Metrics::Dashboard::SystemDashboardService, :use_clean_rails_memory_store_caching do
  include MetricsDashboardHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:environment) { create(:environment, project: project) }

  before do
    project.add_maintainer(user)
  end

  describe '#get_dashboard' do
    let(:dashboard_path) { described_class::DASHBOARD_PATH }
    let(:service_params) { [project, user, { environment: environment, dashboard_path: dashboard_path }] }
    let(:service_call) { described_class.new(*service_params).get_dashboard }

    it_behaves_like 'valid dashboard service response'
    it_behaves_like 'raises error for users with insufficient permissions'
    it_behaves_like 'caches the unprocessed dashboard for subsequent calls'

    context 'when called with a non-system dashboard' do
      let(:dashboard_path) { 'garbage/dashboard/path' }

      # We want to always return the system dashboard.
      it_behaves_like 'valid dashboard service response'
    end
  end

  describe '.all_dashboard_paths' do
    it 'returns the dashboard attributes' do
      all_dashboards = described_class.all_dashboard_paths(project)

      expect(all_dashboards).to eq(
        [{
          path: described_class::DASHBOARD_PATH,
          display_name: described_class::DASHBOARD_NAME,
          default: true,
          system_dashboard: true
        }]
      )
    end
  end

  describe '.valid_params?' do
    let(:params) { { dashboard_path: described_class::DASHBOARD_PATH } }

    subject { described_class.valid_params?(params) }

    it { is_expected.to be_truthy }

    context 'missing dashboard_path' do
      let(:params) { {} }

      it { is_expected.to be_falsey }
    end

    context 'non-matching dashboard_path' do
      let(:params) { { dashboard_path: 'path/to/bunk.yml' } }

      it { is_expected.to be_falsey }
    end
  end
end

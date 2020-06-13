# frozen_string_literal: true

require 'spec_helper'

describe Metrics::Dashboard::UpdateDashboardService, :use_clean_rails_memory_store_caching do
  include MetricsDashboardHelpers

  set(:user) { create(:user) }
  set(:project) { create(:project, :repository) }
  set(:environment) { create(:environment, project: project) }

  describe '#execute' do
    subject(:service_call) { described_class.new(project, user, params).execute }

    let(:commit_message) { 'test' }
    let(:branch) { 'dashboard_new_branch' }
    let(:dashboard) { 'config/prometheus/common_metrics.yml' }
    let(:file_name) { 'custom_dashboard.yml' }
    let(:file_content_hash) { YAML.safe_load(File.read(dashboard)) }
    let(:params) do
      {
        file_name: file_name,
        file_content: file_content_hash,
        commit_message: commit_message,
        branch: branch
      }
    end

    context 'user does not have push right to repository' do
      it 'returns an appropriate message and status code', :aggregate_failures do
        result = service_call

        expect(result.keys).to contain_exactly(:message, :http_status, :status, :last_step)
        expect(result[:status]).to eq(:error)
        expect(result[:http_status]).to eq(:forbidden)
        expect(result[:message]).to eq("You are not allowed to push into this branch. Create another branch or open a merge request.")
      end
    end

    context 'with rights to push to the repository' do
      before do
        project.add_maintainer(user)
      end

      context 'path traversal attack attempt' do
        context 'with a yml extension' do
          let(:file_name) { 'config/prometheus/../database.yml' }

          it 'returns an appropriate message and status code', :aggregate_failures do
            result = service_call

            expect(result.keys).to contain_exactly(:message, :http_status, :status, :last_step)
            expect(result[:status]).to eq(:error)
            expect(result[:http_status]).to eq(:bad_request)
            expect(result[:message]).to eq("A file with this name doesn't exist")
          end
        end

        context 'without a yml extension' do
          let(:file_name) { '../../..../etc/passwd' }

          it 'returns an appropriate message and status code', :aggregate_failures do
            result = service_call

            expect(result.keys).to contain_exactly(:message, :http_status, :status, :last_step)
            expect(result[:status]).to eq(:error)
            expect(result[:http_status]).to eq(:bad_request)
            expect(result[:message]).to eq("The file name should have a .yml extension")
          end
        end
      end

      context 'valid parameters' do
        it_behaves_like 'valid dashboard update process'
      end

      context 'selected branch already exists' do
        let(:branch) { 'existing_branch' }

        before do
          project.repository.add_branch(user, branch, 'master')
        end

        it 'returns an appropriate message and status code', :aggregate_failures do
          result = service_call

          expect(result.keys).to contain_exactly(:message, :http_status, :status, :last_step)
          expect(result[:status]).to eq(:error)
          expect(result[:http_status]).to eq(:bad_request)
          expect(result[:message]).to eq("There was an error updating the dashboard, branch named: existing_branch already exists.")
        end
      end

      context 'Files::UpdateService success' do
        before do
          allow(::Files::UpdateService).to receive(:new).and_return(double(execute: { status: :success }))
        end

        it 'returns success', :aggregate_failures do
          dashboard_details = {
            path: '.gitlab/dashboards/custom_dashboard.yml',
            display_name: 'custom_dashboard.yml',
            default: false,
            system_dashboard: false
          }

          expect(service_call[:status]).to be :success
          expect(service_call[:http_status]).to be :created
          expect(service_call[:dashboard]).to match dashboard_details
        end

        context 'with escaped characters in file name' do
          let(:file_name) { "custom_dashboard%26copy.yml" }

          it 'escapes the special characters', :aggregate_failures do
            dashboard_details = {
              path: '.gitlab/dashboards/custom_dashboard&copy.yml',
              display_name: 'custom_dashboard&copy.yml',
              default: false,
              system_dashboard: false
            }

            expect(service_call[:status]).to be :success
            expect(service_call[:http_status]).to be :created
            expect(service_call[:dashboard]).to match dashboard_details
          end
        end
      end

      context 'Files::UpdateService fails' do
        before do
          allow(::Files::UpdateService).to receive(:new).and_return(double(execute: { status: :error }))
        end

        it 'returns error' do
          expect(service_call[:status]).to be :error
        end
      end
    end
  end
end

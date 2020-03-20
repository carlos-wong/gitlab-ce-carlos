# frozen_string_literal: true

require 'spec_helper'

describe Metrics::Dashboard::CloneDashboardService, :use_clean_rails_memory_store_caching do
  include MetricsDashboardHelpers

  set(:user) { create(:user) }
  set(:project) { create(:project, :repository) }
  set(:environment) { create(:environment, project: project) }

  describe '#execute' do
    subject(:service_call) { described_class.new(project, user, params).execute }

    let(:commit_message) { 'test' }
    let(:branch) { "dashboard_new_branch" }
    let(:dashboard) { 'config/prometheus/common_metrics.yml' }
    let(:file_name) { 'custom_dashboard.yml' }
    let(:params) do
      {
        dashboard: dashboard,
        file_name: file_name,
        commit_message: commit_message,
        branch: branch
      }
    end

    let(:dashboard_attrs) do
      {
        commit_message: commit_message,
        branch_name: branch,
        start_branch: project.default_branch,
        encoding: 'text',
        file_path: ".gitlab/dashboards/#{file_name}",
        file_content: File.read(dashboard)
      }
    end

    context 'user does not have push right to repository' do
      it_behaves_like 'misconfigured dashboard service response', :forbidden, %q(You can't commit to this project)
    end

    context 'with rights to push to the repository' do
      before do
        project.add_maintainer(user)
      end

      context 'wrong target file extension' do
        let(:file_name) { 'custom_dashboard.txt' }

        it_behaves_like 'misconfigured dashboard service response', :bad_request, 'The file name should have a .yml extension'
      end

      context 'wrong source dashboard file' do
        let(:dashboard) { 'config/prometheus/common_metrics_123.yml' }

        it_behaves_like 'misconfigured dashboard service response', :not_found, 'Not found.'
      end

      context 'path traversal attack attempt' do
        let(:dashboard) { 'config/prometheus/../database.yml' }

        it_behaves_like 'misconfigured dashboard service response', :not_found, 'Not found.'
      end

      context 'path traversal attack attempt on target file' do
        let(:file_name) { '../../custom_dashboard.yml' }
        let(:dashboard_attrs) do
          {
            commit_message: commit_message,
            branch_name: branch,
            start_branch: project.default_branch,
            encoding: 'text',
            file_path: ".gitlab/dashboards/custom_dashboard.yml",
            file_content: File.read(dashboard)
          }
        end

        it 'strips target file name to safe value', :aggregate_failures do
          service_instance = instance_double(::Files::CreateService)
          expect(::Files::CreateService).to receive(:new).with(project, user, dashboard_attrs).and_return(service_instance)
          expect(service_instance).to receive(:execute).and_return(status: :success)

          service_call
        end
      end

      context 'valid parameters' do
        it 'delegates commit creation to Files::CreateService', :aggregate_failures do
          service_instance = instance_double(::Files::CreateService)
          expect(::Files::CreateService).to receive(:new).with(project, user, dashboard_attrs).and_return(service_instance)
          expect(service_instance).to receive(:execute).and_return(status: :success)

          service_call
        end

        context 'selected branch already exists' do
          let(:branch) { 'existing_branch' }

          before do
            project.repository.add_branch(user, branch, 'master')
          end

          it_behaves_like 'misconfigured dashboard service response', :bad_request, "There was an error creating the dashboard, branch named: existing_branch already exists."

          # temporary not available function for first iteration
          # follow up issue https://gitlab.com/gitlab-org/gitlab/issues/196237 which
          # require this feature
          # it 'pass correct params to Files::CreateService', :aggregate_failures do
          #   project.repository.add_branch(user, branch, 'master')
          #
          #   service_instance = instance_double(::Files::CreateService)
          #   expect(::Files::CreateService).to receive(:new).with(project, user, dashboard_attrs).and_return(service_instance)
          #   expect(service_instance).to receive(:execute).and_return(status: :success)
          #
          #   service_call
          # end
        end

        context 'blank branch name' do
          let(:branch) { '' }

          it_behaves_like 'misconfigured dashboard service response', :bad_request, 'There was an error creating the dashboard, branch name is invalid.'
        end

        context 'dashboard file already exists' do
          let(:branch) { 'custom_dashboard' }

          before do
            Files::CreateService.new(
              project,
              user,
              commit_message: 'Create custom dashboard custom_dashboard.yml',
              branch_name: 'master',
              start_branch: 'master',
              file_path: ".gitlab/dashboards/custom_dashboard.yml",
              file_content: File.read('config/prometheus/common_metrics.yml')
            ).execute
          end

          it_behaves_like 'misconfigured dashboard service response', :bad_request, "A file with 'custom_dashboard.yml' already exists in custom_dashboard branch"
        end

        it 'extends dashboard template path to absolute url' do
          allow(::Files::CreateService).to receive(:new).and_return(double(execute: { status: :success }))

          expect(File).to receive(:read).with(Rails.root.join('config/prometheus/common_metrics.yml')).and_return('')

          service_call
        end

        context 'Files::CreateService success' do
          before do
            allow(::Files::CreateService).to receive(:new).and_return(double(execute: { status: :success }))
          end

          it 'clears dashboards cache' do
            expect(project.repository).to receive(:refresh_method_caches).with([:metrics_dashboard])

            service_call
          end

          it 'returns success', :aggregate_failures do
            result = service_call
            dashboard_details = {
              path: '.gitlab/dashboards/custom_dashboard.yml',
              display_name: 'custom_dashboard.yml',
              default: false,
              system_dashboard: false
            }

            expect(result[:status]).to be :success
            expect(result[:http_status]).to be :created
            expect(result[:dashboard]).to match dashboard_details
          end
        end

        context 'Files::CreateService fails' do
          before do
            allow(::Files::CreateService).to receive(:new).and_return(double(execute: { status: :error }))
          end

          it 'does NOT clear dashboards cache' do
            expect(project.repository).not_to receive(:refresh_method_caches)

            service_call
          end

          it 'returns error' do
            result = service_call
            expect(result[:status]).to be :error
          end
        end
      end
    end
  end
end

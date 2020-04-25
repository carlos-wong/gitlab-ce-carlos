# frozen_string_literal: true

require 'spec_helper'

describe 'Self-Monitoring project requests' do
  let(:admin) { create(:admin) }

  describe 'POST #create_self_monitoring_project' do
    let(:worker_class) { SelfMonitoringProjectCreateWorker }

    subject { post create_self_monitoring_project_admin_application_settings_path }

    it_behaves_like 'not accessible to non-admin users'

    context 'with admin user' do
      before do
        login_as(admin)
      end

      context 'when the self monitoring project is created' do
        let(:status_api) { status_create_self_monitoring_project_admin_application_settings_path }

        it_behaves_like 'triggers async worker, returns sidekiq job_id with response accepted'
      end
    end
  end

  describe 'GET #status_create_self_monitoring_project' do
    let(:worker_class) { SelfMonitoringProjectCreateWorker }
    let(:job_id) { 'job_id' }

    subject do
      get status_create_self_monitoring_project_admin_application_settings_path,
        params: { job_id: job_id }
    end

    it_behaves_like 'not accessible to non-admin users'

    context 'with admin user' do
      before do
        login_as(admin)
      end

      context 'when the self monitoring project is being created' do
        it_behaves_like 'handles invalid job_id'

        context 'when job is in progress' do
          before do
            allow(worker_class).to receive(:in_progress?)
              .with(job_id)
              .and_return(true)
          end

          it_behaves_like 'sets polling header and returns accepted' do
            let(:in_progress_message) { 'Job to create self-monitoring project is in progress' }
          end
        end

        context 'when self-monitoring project and job do not exist' do
          let(:job_id) { nil }

          it 'returns bad_request' do
            create(:application_setting)

            subject

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response).to eq(
                'message' => 'Self-monitoring project does not exist. Please check logs ' \
                  'for any error messages'
              )
            end
          end
        end

        context 'when self-monitoring project exists' do
          let(:project) { create(:project) }

          before do
            create(:application_setting, self_monitoring_project_id: project.id)
          end

          it 'does not need job_id' do
            get status_create_self_monitoring_project_admin_application_settings_path

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:success)
              expect(json_response).to eq(
                'project_id' => project.id,
                'project_full_path' => project.full_path
              )
            end
          end

          it 'returns success with job_id' do
            subject

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:success)
              expect(json_response).to eq(
                'project_id' => project.id,
                'project_full_path' => project.full_path
              )
            end
          end
        end
      end
    end
  end

  describe 'DELETE #delete_self_monitoring_project' do
    let(:worker_class) { SelfMonitoringProjectDeleteWorker }

    subject { delete delete_self_monitoring_project_admin_application_settings_path }

    it_behaves_like 'not accessible to non-admin users'

    context 'with admin user' do
      before do
        login_as(admin)
      end

      context 'when the self monitoring project is deleted' do
        let(:status_api) { status_delete_self_monitoring_project_admin_application_settings_path }

        it_behaves_like 'triggers async worker, returns sidekiq job_id with response accepted'
      end
    end
  end

  describe 'GET #status_delete_self_monitoring_project' do
    let(:worker_class) { SelfMonitoringProjectDeleteWorker }
    let(:job_id) { 'job_id' }

    subject do
      get status_delete_self_monitoring_project_admin_application_settings_path,
        params: { job_id: job_id }
    end

    it_behaves_like 'not accessible to non-admin users'

    context 'with admin user' do
      before do
        login_as(admin)
      end

      context 'when the self monitoring project is being deleted' do
        it_behaves_like 'handles invalid job_id'

        context 'when job is in progress' do
          before do
            allow(worker_class).to receive(:in_progress?)
              .with(job_id)
              .and_return(true)

            stub_application_setting(self_monitoring_project_id: 1)
          end

          it_behaves_like 'sets polling header and returns accepted' do
            let(:in_progress_message) { 'Job to delete self-monitoring project is in progress' }
          end
        end

        context 'when self-monitoring project exists and job does not exist' do
          before do
            create(:application_setting, self_monitoring_project_id: create(:project).id)
          end

          it 'returns bad_request' do
            subject

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response).to eq(
                'message' => 'Self-monitoring project was not deleted. Please check logs ' \
                  'for any error messages'
              )
            end
          end
        end

        context 'when self-monitoring project does not exist' do
          before do
            create(:application_setting)
          end

          it 'does not need job_id' do
            get status_delete_self_monitoring_project_admin_application_settings_path

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:success)
              expect(json_response).to eq(
                'message' => 'Self-monitoring project has been successfully deleted'
              )
            end
          end

          it 'returns success with job_id' do
            subject

            aggregate_failures do
              expect(response).to have_gitlab_http_status(:success)
              expect(json_response).to eq(
                'message' => 'Self-monitoring project has been successfully deleted'
              )
            end
          end
        end
      end
    end
  end
end

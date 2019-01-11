require 'spec_helper'

describe 'Clusters Applications', :js do
  include GoogleApi::CloudPlatformHelpers

  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  describe 'Installing applications' do
    before do
      visit project_cluster_path(project, cluster)
    end

    context 'when cluster is being created' do
      let(:cluster) { create(:cluster, :providing_by_gcp, projects: [project])}

      it 'user is unable to install applications' do
        page.within('.js-cluster-application-row-helm') do
          expect(page.find(:css, '.js-cluster-application-install-button')['disabled']).to eq('true')
          expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Install')
        end
      end
    end

    context 'when cluster is created' do
      let(:cluster) { create(:cluster, :provided_by_gcp, projects: [project])}

      it 'user can install applications' do
        page.within('.js-cluster-application-row-helm') do
          expect(page.find(:css, '.js-cluster-application-install-button')['disabled']).to be_nil
          expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Install')
        end
      end

      context 'when user installs Helm' do
        before do
          allow(ClusterInstallAppWorker).to receive(:perform_async)

          page.within('.js-cluster-application-row-helm') do
            page.find(:css, '.js-cluster-application-install-button').click
          end
        end

        it 'they see status transition' do
          page.within('.js-cluster-application-row-helm') do
            # FE sends request and gets the response, then the buttons is "Install"
            expect(page.find(:css, '.js-cluster-application-install-button')['disabled']).to eq('true')
            expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Install')

            wait_until_helm_created!

            Clusters::Cluster.last.application_helm.make_installing!

            # FE starts polling and update the buttons to "Installing"
            expect(page.find(:css, '.js-cluster-application-install-button')['disabled']).to eq('true')
            expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Installing')

            Clusters::Cluster.last.application_helm.make_installed!

            expect(page.find(:css, '.js-cluster-application-install-button')['disabled']).to eq('true')
            expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Installed')
          end

          expect(page).to have_content('Helm Tiller was successfully installed on your Kubernetes cluster')
        end
      end

      context 'when user installs Knative' do
        before do
          create(:clusters_applications_helm, :installed, cluster: cluster)
        end

        context 'on an abac cluster' do
          let(:cluster) { create(:cluster, :provided_by_gcp, :rbac_disabled, projects: [project])}

          it 'should show info block and not be installable' do
            page.within('.js-cluster-application-row-knative') do
              expect(page).to have_css('.bs-callout-info')
              expect(page.find(:css, '.js-cluster-application-install-button')['disabled']).to eq('true')
            end
          end
        end

        context 'on an rbac cluster' do
          let(:cluster) { create(:cluster, :provided_by_gcp, projects: [project])}

          it 'should not show callout block and be installable' do
            page.within('.js-cluster-application-row-knative') do
              expect(page).not_to have_css('.bs-callout-info')
              expect(page).to have_css('.js-cluster-application-install-button:not([disabled])')
            end
          end
        end
      end

      context 'when user installs Cert Manager' do
        before do
          allow(ClusterInstallAppWorker).to receive(:perform_async)
          allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_in)
          allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_async)

          create(:clusters_applications_helm, :installed, cluster: cluster)

          page.within('.js-cluster-application-row-cert_manager') do
            click_button 'Install'
          end
        end

        it 'shows status transition' do
          def email_form_value
            page.find('.js-email').value
          end

          page.within('.js-cluster-application-row-cert_manager') do
            expect(email_form_value).to eq(cluster.user.email)
            expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Install')

            page.find('.js-email').set("new_email@example.org")
            Clusters::Cluster.last.application_cert_manager.make_installing!

            expect(email_form_value).to eq('new_email@example.org')
            expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Installing')

            Clusters::Cluster.last.application_cert_manager.make_installed!

            expect(email_form_value).to eq('new_email@example.org')
            expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Installed')
          end

          expect(page).to have_content('Cert-Manager was successfully installed on your Kubernetes cluster')
        end
      end

      context 'when user installs Ingress' do
        context 'when user installs application: Ingress' do
          before do
            allow(ClusterInstallAppWorker).to receive(:perform_async)
            allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_in)
            allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_async)

            create(:clusters_applications_helm, :installed, cluster: cluster)

            page.within('.js-cluster-application-row-ingress') do
              expect(page).to have_css('.js-cluster-application-install-button:not([disabled])')
              page.find(:css, '.js-cluster-application-install-button').click
            end
          end

          it 'they see status transition' do
            page.within('.js-cluster-application-row-ingress') do
              # FE sends request and gets the response, then the buttons is "Install"
              expect(page).to have_css('.js-cluster-application-install-button[disabled]')
              expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Install')

              Clusters::Cluster.last.application_ingress.make_installing!

              # FE starts polling and update the buttons to "Installing"
              expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Installing')
              expect(page).to have_css('.js-cluster-application-install-button[disabled]')

              # The application becomes installed but we keep waiting for external IP address
              Clusters::Cluster.last.application_ingress.make_installed!

              expect(page).to have_css('.js-cluster-application-install-button', exact_text: 'Installed')
              expect(page).to have_css('.js-cluster-application-install-button[disabled]')
              expect(page).to have_selector('.js-no-ip-message')
              expect(page.find('.js-ip-address').value).to eq('?')

              # We receive the external IP address and display
              Clusters::Cluster.last.application_ingress.update!(external_ip: '192.168.1.100')

              expect(page).not_to have_selector('.js-no-ip-message')
              expect(page.find('.js-ip-address').value).to eq('192.168.1.100')
            end

            expect(page).to have_content('Ingress was successfully installed on your Kubernetes cluster')
          end
        end
      end
    end
  end

  def wait_until_helm_created!
    retries = 0

    while Clusters::Cluster.last.application_helm.nil?
      raise "Timed out waiting for helm application to be created in DB" if (retries += 1) > 3

      sleep(1)
    end
  end
end

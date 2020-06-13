# frozen_string_literal: true

module QA
  module Page
    module Project
      module Operations
        module Kubernetes
          class Show < Page::Base
            view 'app/assets/javascripts/clusters/components/applications.vue' do
              element :ingress_ip_address, 'id="ingress-endpoint"' # rubocop:disable QA/ElementWithPattern
            end

            view 'app/views/clusters/clusters/_gitlab_integration_form.html.haml' do
              element :integration_status_toggle, required: true
              element :base_domain_field, required: true
              element :save_changes_button, required: true
            end

            view 'app/views/clusters/clusters/_details_tab.html.haml' do
              element :details, required: true
            end

            view 'app/views/clusters/clusters/_applications_tab.html.haml' do
              element :applications, required: true
            end

            view 'app/assets/javascripts/clusters/components/application_row.vue' do
              element :install_button
              element :uninstall_button
            end

            def open_details
              has_element?(:details, wait: 30)
              click_element :details
            end

            def open_applications
              has_element?(:applications, wait: 30)
              click_element :applications
            end

            def install!(application_name)
              within_element(application_name) do
                has_element?(:install_button, application: application_name, wait: 30)
                click_element :install_button
              end
            end

            def await_installed(application_name)
              within_element(application_name) do
                has_element?(:uninstall_button, application: application_name, wait: 300)
              end
            end

            def has_application_installed?(application_name)
              within_element(application_name) do
                has_element?(:uninstall_button, application: application_name, wait: 300)
              end
            end

            def ingress_ip
              # We need to wait longer since it can take some time before the
              # ip address is assigned for the ingress controller
              page.find('#ingress-endpoint', wait: 1200).value
            end

            def set_domain(domain)
              fill_element :base_domain_field, domain
            end

            def save_domain
              click_element :save_changes_button, Page::Project::Operations::Kubernetes::Show
            end
          end
        end
      end
    end
  end
end

QA::Page::Project::Operations::Kubernetes::Show.prepend_if_ee('QA::EE::Page::Project::Operations::Kubernetes::Show')

# frozen_string_literal: true

module Clusters
  module Applications
    class Ingress < ApplicationRecord
      VERSION = '1.22.1'

      self.table_name = 'clusters_applications_ingress'

      include ::Clusters::Concerns::ApplicationCore
      include ::Clusters::Concerns::ApplicationStatus
      include ::Clusters::Concerns::ApplicationVersion
      include ::Clusters::Concerns::ApplicationData
      include AfterCommitQueue

      default_value_for :ingress_type, :nginx
      default_value_for :version, VERSION

      enum ingress_type: {
        nginx: 1
      }

      FETCH_IP_ADDRESS_DELAY = 30.seconds

      state_machine :status do
        after_transition any => [:installed] do |application|
          application.run_after_commit do
            ClusterWaitForIngressIpAddressWorker.perform_in(
              FETCH_IP_ADDRESS_DELAY, application.name, application.id)
          end
        end
      end

      def chart
        'stable/nginx-ingress'
      end

      def values
        content_values.to_yaml
      end

      def allowed_to_uninstall?
        external_ip_or_hostname? && application_jupyter_nil_or_installable?
      end

      def install_command
        Gitlab::Kubernetes::Helm::InstallCommand.new(
          name: name,
          version: VERSION,
          rbac: cluster.platform_kubernetes_rbac?,
          chart: chart,
          files: files
        )
      end

      def external_ip_or_hostname?
        external_ip.present? || external_hostname.present?
      end

      def schedule_status_update
        return unless installed?
        return if external_ip
        return if external_hostname

        ClusterWaitForIngressIpAddressWorker.perform_async(name, id)
      end

      def ingress_service
        cluster.kubeclient.get_service('ingress-nginx-ingress-controller', Gitlab::Kubernetes::Helm::NAMESPACE)
      end

      private

      def specification
        return {} unless Feature.enabled?(:ingress_modsecurity)

        {
          "controller" => {
            "config" => {
              "enable-modsecurity" => "true",
              "enable-owasp-modsecurity-crs" => "true"
            }
          }
        }
      end

      def content_values
        YAML.load_file(chart_values_file).deep_merge!(specification)
      end

      def application_jupyter_nil_or_installable?
        cluster.application_jupyter.nil? || cluster.application_jupyter&.installable?
      end
    end
  end
end

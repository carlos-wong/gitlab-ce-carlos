# frozen_string_literal: true

module Clusters
  module Applications
    class Prometheus < ApplicationRecord
      include PrometheusAdapter

      VERSION = '6.7.3'

      self.table_name = 'clusters_applications_prometheus'

      include ::Clusters::Concerns::ApplicationCore
      include ::Clusters::Concerns::ApplicationStatus
      include ::Clusters::Concerns::ApplicationVersion
      include ::Clusters::Concerns::ApplicationData

      default_value_for :version, VERSION

      after_destroy :disable_prometheus_integration

      state_machine :status do
        after_transition any => [:installed] do |application|
          application.cluster.projects.each do |project|
            project.find_or_initialize_service('prometheus').update!(active: true)
          end
        end
      end

      def chart
        'stable/prometheus'
      end

      def service_name
        'prometheus-prometheus-server'
      end

      def service_port
        80
      end

      def install_command
        Gitlab::Kubernetes::Helm::InstallCommand.new(
          name: name,
          version: VERSION,
          rbac: cluster.platform_kubernetes_rbac?,
          chart: chart,
          files: files,
          postinstall: install_knative_metrics
        )
      end

      def upgrade_command(values)
        ::Gitlab::Kubernetes::Helm::InstallCommand.new(
          name: name,
          version: VERSION,
          rbac: cluster.platform_kubernetes_rbac?,
          chart: chart,
          files: files_with_replaced_values(values)
        )
      end

      def uninstall_command
        Gitlab::Kubernetes::Helm::DeleteCommand.new(
          name: name,
          rbac: cluster.platform_kubernetes_rbac?,
          files: files,
          predelete: delete_knative_istio_metrics
        )
      end

      # Returns a copy of files where the values of 'values.yaml'
      # are replaced by the argument.
      #
      # See #values for the data format required
      def files_with_replaced_values(replaced_values)
        files.merge('values.yaml': replaced_values)
      end

      def prometheus_client
        return unless kube_client

        proxy_url = kube_client.proxy_url('service', service_name, service_port, Gitlab::Kubernetes::Helm::NAMESPACE)

        # ensures headers containing auth data are appended to original k8s client options
        options = kube_client.rest_client.options.merge(headers: kube_client.headers)
        Gitlab::PrometheusClient.new(proxy_url, options)
      rescue Kubeclient::HttpError
        # If users have mistakenly set parameters or removed the depended clusters,
        # `proxy_url` could raise an exception because gitlab can not communicate with the cluster.
        # Since `PrometheusAdapter#can_query?` is eargely loaded on environement pages in gitlab,
        # we need to silence the exceptions
      end

      private

      def disable_prometheus_integration
        cluster.projects.each do |project|
          project.prometheus_service&.update!(active: false)
        end
      end

      def kube_client
        cluster&.kubeclient&.core_client
      end

      def install_knative_metrics
        return [] unless cluster.application_knative_available?

        [Gitlab::Kubernetes::KubectlCmd.apply_file(Clusters::Applications::Knative::METRICS_CONFIG)]
      end

      def delete_knative_istio_metrics
        return [] unless cluster.application_knative_available?

        [
          Gitlab::Kubernetes::KubectlCmd.delete(
            "-f", Clusters::Applications::Knative::METRICS_CONFIG,
            "--ignore-not-found"
          )
        ]
      end
    end
  end
end

Clusters::Applications::Prometheus.prepend_if_ee('EE::Clusters::Applications::Prometheus')

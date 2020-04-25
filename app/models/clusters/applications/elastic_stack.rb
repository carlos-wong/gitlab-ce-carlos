# frozen_string_literal: true

module Clusters
  module Applications
    class ElasticStack < ApplicationRecord
      VERSION = '1.8.0'

      ELASTICSEARCH_PORT = 9200

      self.table_name = 'clusters_applications_elastic_stacks'

      include ::Clusters::Concerns::ApplicationCore
      include ::Clusters::Concerns::ApplicationStatus
      include ::Clusters::Concerns::ApplicationVersion
      include ::Clusters::Concerns::ApplicationData
      include ::Gitlab::Utils::StrongMemoize

      include IgnorableColumns
      ignore_column :kibana_hostname, remove_with: '12.9', remove_after: '2020-02-22'

      default_value_for :version, VERSION

      def chart
        'stable/elastic-stack'
      end

      def install_command
        Gitlab::Kubernetes::Helm::InstallCommand.new(
          name: 'elastic-stack',
          version: VERSION,
          rbac: cluster.platform_kubernetes_rbac?,
          chart: chart,
          files: files,
          postinstall: post_install_script
        )
      end

      def uninstall_command
        Gitlab::Kubernetes::Helm::DeleteCommand.new(
          name: 'elastic-stack',
          rbac: cluster.platform_kubernetes_rbac?,
          files: files,
          postdelete: post_delete_script
        )
      end

      def files
        super.merge('wait-for-elasticsearch.sh': File.read("#{Rails.root}/vendor/elastic_stack/wait-for-elasticsearch.sh"))
      end

      def elasticsearch_client
        strong_memoize(:elasticsearch_client) do
          next unless kube_client

          proxy_url = kube_client.proxy_url('service', 'elastic-stack-elasticsearch-client', ::Clusters::Applications::ElasticStack::ELASTICSEARCH_PORT, Gitlab::Kubernetes::Helm::NAMESPACE)

          Elasticsearch::Client.new(url: proxy_url) do |faraday|
            # ensures headers containing auth data are appended to original client options
            faraday.headers.merge!(kube_client.headers)
            # ensure TLS certs are properly verified
            faraday.ssl[:verify] = kube_client.ssl_options[:verify_ssl]
            faraday.ssl[:cert_store] = kube_client.ssl_options[:cert_store]
          end

        rescue Kubeclient::HttpError => error
          # If users have mistakenly set parameters or removed the depended clusters,
          # `proxy_url` could raise an exception because gitlab can not communicate with the cluster.
          # We check for a nil client in downstream use and behaviour is equivalent to an empty state
          log_exception(error, :failed_to_create_elasticsearch_client)

          nil
        end
      end

      private

      def post_install_script
        [
          "timeout -t60 sh /data/helm/elastic-stack/config/wait-for-elasticsearch.sh http://elastic-stack-elasticsearch-client:9200"
        ]
      end

      def post_delete_script
        [
          Gitlab::Kubernetes::KubectlCmd.delete("pvc", "--selector", "release=elastic-stack")
        ]
      end

      def kube_client
        cluster&.kubeclient&.core_client
      end
    end
  end
end

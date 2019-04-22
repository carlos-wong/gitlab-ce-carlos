# frozen_string_literal: true

module Clusters
  module Platforms
    class Kubernetes < ApplicationRecord
      include Gitlab::Kubernetes
      include ReactiveCaching
      include EnumWithNil
      include AfterCommitQueue

      RESERVED_NAMESPACES = %w(gitlab-managed-apps).freeze

      self.table_name = 'cluster_platforms_kubernetes'
      self.reactive_cache_key = ->(kubernetes) { [kubernetes.class.model_name.singular, kubernetes.id] }

      belongs_to :cluster, inverse_of: :platform_kubernetes, class_name: 'Clusters::Cluster'

      attr_encrypted :password,
        mode: :per_attribute_iv,
        key: Settings.attr_encrypted_db_key_base_truncated,
        algorithm: 'aes-256-cbc'

      attr_encrypted :token,
        mode: :per_attribute_iv,
        key: Settings.attr_encrypted_db_key_base_truncated,
        algorithm: 'aes-256-cbc'

      before_validation :enforce_namespace_to_lower_case
      before_validation :enforce_ca_whitespace_trimming

      validates :namespace,
        allow_blank: true,
        length: 1..63,
        format: {
          with: Gitlab::Regex.kubernetes_namespace_regex,
          message: Gitlab::Regex.kubernetes_namespace_regex_message
        }

      validates :namespace, exclusion: { in: RESERVED_NAMESPACES }

      validate :no_namespace, unless: :allow_user_defined_namespace?

      # We expect to be `active?` only when enabled and cluster is created (the api_url is assigned)
      validates :api_url, public_url: true, presence: true
      validates :token, presence: true
      validates :ca_cert, certificate: true, allow_blank: true, if: :ca_cert_changed?

      validate :prevent_modification, on: :update

      after_save :clear_reactive_cache!
      after_update :update_kubernetes_namespace

      alias_attribute :ca_pem, :ca_cert

      delegate :project, to: :cluster, allow_nil: true
      delegate :enabled?, to: :cluster, allow_nil: true
      delegate :provided_by_user?, to: :cluster, allow_nil: true
      delegate :allow_user_defined_namespace?, to: :cluster, allow_nil: true
      delegate :kubernetes_namespace, to: :cluster

      alias_method :active?, :enabled?

      enum_with_nil authorization_type: {
        unknown_authorization: nil,
        rbac: 1,
        abac: 2
      }

      default_value_for :authorization_type, :rbac

      def actual_namespace
        if namespace.present?
          namespace
        else
          default_namespace
        end
      end

      def predefined_variables(project:)
        Gitlab::Ci::Variables::Collection.new.tap do |variables|
          variables.append(key: 'KUBE_URL', value: api_url)

          if ca_pem.present?
            variables
              .append(key: 'KUBE_CA_PEM', value: ca_pem)
              .append(key: 'KUBE_CA_PEM_FILE', value: ca_pem, file: true)
          end

          if kubernetes_namespace = cluster.kubernetes_namespaces.has_service_account_token.find_by(project: project)
            variables.concat(kubernetes_namespace.predefined_variables)
          elsif cluster.project_type?
            # From 11.5, every Clusters::Project should have at least one
            # Clusters::KubernetesNamespace, so once migration has been completed,
            # this 'else' branch will be removed. For more information, please see
            # https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/22433
            variables
              .append(key: 'KUBE_URL', value: api_url)
              .append(key: 'KUBE_TOKEN', value: token, public: false, masked: true)
              .append(key: 'KUBE_NAMESPACE', value: actual_namespace)
              .append(key: 'KUBECONFIG', value: kubeconfig, public: false, file: true)
          end

          variables.concat(cluster.predefined_variables)
        end
      end

      # Constructs a list of terminals from the reactive cache
      #
      # Returns nil if the cache is empty, in which case you should try again a
      # short time later
      def terminals(environment)
        with_reactive_cache do |data|
          pods = filter_by_project_environment(data[:pods], project.full_path_slug, environment.slug)
          terminals = pods.flat_map { |pod| terminals_for_pod(api_url, actual_namespace, pod) }.compact
          terminals.each { |terminal| add_terminal_auth(terminal, terminal_auth) }
        end
      end

      # Caches resources in the namespace so other calls don't need to block on
      # network access
      def calculate_reactive_cache
        return unless enabled? && project && !project.pending_delete?

        # We may want to cache extra things in the future
        { pods: read_pods }
      end

      def kubeclient
        @kubeclient ||= build_kube_client!
      end

      private

      def kubeconfig
        to_kubeconfig(
          url: api_url,
          namespace: actual_namespace,
          token: token,
          ca_pem: ca_pem)
      end

      def default_namespace
        kubernetes_namespace&.namespace.presence || fallback_default_namespace
      end

      # DEPRECATED
      #
      # On 11.4 Clusters::KubernetesNamespace was introduced, this model will allow to
      # have multiple namespaces per project. This method will be removed after migration
      # has been completed.
      def fallback_default_namespace
        return unless project

        slug = "#{project.path}-#{project.id}".downcase
        Gitlab::NamespaceSanitizer.sanitize(slug)
      end

      def build_kube_client!
        raise "Incomplete settings" unless api_url
        raise "No namespace" if cluster.project_type? && actual_namespace.empty? # can probably remove this line once we remove #actual_namespace

        unless (username && password) || token
          raise "Either username/password or token is required to access API"
        end

        Gitlab::Kubernetes::KubeClient.new(
          api_url,
          auth_options: kubeclient_auth_options,
          ssl_options: kubeclient_ssl_options,
          http_proxy_uri: ENV['http_proxy']
        )
      end

      # Returns a hash of all pods in the namespace
      def read_pods
        kubeclient = build_kube_client!

        kubeclient.get_pods(namespace: actual_namespace).as_json
      rescue Kubeclient::ResourceNotFoundError
        []
      end

      def kubeclient_ssl_options
        opts = { verify_ssl: OpenSSL::SSL::VERIFY_PEER }

        if ca_pem.present?
          opts[:cert_store] = OpenSSL::X509::Store.new
          opts[:cert_store].add_cert(OpenSSL::X509::Certificate.new(ca_pem))
        end

        opts
      end

      def kubeclient_auth_options
        { bearer_token: token }
      end

      def terminal_auth
        {
          token: token,
          ca_pem: ca_pem,
          max_session_time: Gitlab::CurrentSettings.terminal_max_session_time
        }
      end

      def enforce_namespace_to_lower_case
        self.namespace = self.namespace&.downcase
      end

      def enforce_ca_whitespace_trimming
        self.ca_pem = self.ca_pem&.strip
        self.token = self.token&.strip
      end

      def no_namespace
        if namespace
          errors.add(:namespace, 'only allowed for project cluster')
        end
      end

      def prevent_modification
        return if provided_by_user?

        if api_url_changed? || token_changed? || ca_pem_changed?
          errors.add(:base, _('Cannot modify managed Kubernetes cluster'))
          return false
        end

        true
      end

      def update_kubernetes_namespace
        return unless namespace_changed?

        run_after_commit do
          ClusterConfigureWorker.perform_async(cluster_id)
        end
      end
    end
  end
end

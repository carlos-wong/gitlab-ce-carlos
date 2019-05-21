# frozen_string_literal: true

module Gitlab
  module Kubernetes
    module Helm
      class DeleteCommand
        include BaseCommand
        include ClientCommand

        attr_accessor :name, :files

        def initialize(name:, rbac:, files:)
          @name = name
          @files = files
          @rbac = rbac
        end

        def generate_script
          super + [
            init_command,
            wait_for_tiller_command,
            delete_command
          ].compact.join("\n")
        end

        def pod_name
          "uninstall-#{name}"
        end

        def rbac?
          @rbac
        end

        private

        def delete_command
          command = ['helm', 'delete', '--purge', name] + optional_tls_flags

          command.shelljoin
        end

        def optional_tls_flags
          return [] unless files.key?(:'ca.pem')

          [
            '--tls',
            '--tls-ca-cert', "#{files_dir}/ca.pem",
            '--tls-cert', "#{files_dir}/cert.pem",
            '--tls-key', "#{files_dir}/key.pem"
          ]
        end
      end
    end
  end
end

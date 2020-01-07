# frozen_string_literal: true

require_relative '../gitlab/popen' unless defined?(Gitlab::Popen)

module Quality
  class KubernetesClient
    CommandFailedError = Class.new(StandardError)

    attr_reader :namespace

    def initialize(namespace:)
      @namespace = namespace
    end

    def cleanup(release_name:, wait: true)
      selector = case release_name
                 when String
                   %(-l release="#{release_name}")
                 when Array
                   %(-l 'release in (#{release_name.join(', ')})')
                 else
                   raise ArgumentError, 'release_name must be a string or an array'
                 end

      command = [
        %(--namespace "#{namespace}"),
        'delete',
        'ingress,svc,pdb,hpa,deploy,statefulset,job,pod,secret,configmap,pvc,secret,clusterrole,clusterrolebinding,role,rolebinding,sa',
        '--now',
        '--ignore-not-found',
        '--include-uninitialized',
        %(--wait=#{wait}),
        selector
      ]

      run_command(command)
    end

    private

    def run_command(command)
      final_command = ['kubectl', *command].join(' ')
      puts "Running command: `#{final_command}`" # rubocop:disable Rails/Output

      result = Gitlab::Popen.popen_with_detail([final_command])

      if result.status.success?
        result.stdout.chomp.freeze
      else
        raise CommandFailedError, "The `#{final_command}` command failed (status: #{result.status}) with the following error:\n#{result.stderr}"
      end
    end
  end
end

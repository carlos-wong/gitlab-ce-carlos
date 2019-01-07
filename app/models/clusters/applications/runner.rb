# frozen_string_literal: true

module Clusters
  module Applications
    class Runner < ActiveRecord::Base
      VERSION = '0.1.43'.freeze

      self.table_name = 'clusters_applications_runners'

      include ::Clusters::Concerns::ApplicationCore
      include ::Clusters::Concerns::ApplicationStatus
      include ::Clusters::Concerns::ApplicationVersion
      include ::Clusters::Concerns::ApplicationData

      belongs_to :runner, class_name: 'Ci::Runner', foreign_key: :runner_id
      delegate :project, to: :cluster

      default_value_for :version, VERSION

      def chart
        "#{name}/gitlab-runner"
      end

      def repository
        'https://charts.gitlab.io'
      end

      def values
        content_values.to_yaml
      end

      def install_command
        Gitlab::Kubernetes::Helm::InstallCommand.new(
          name: name,
          version: VERSION,
          rbac: cluster.platform_kubernetes_rbac?,
          chart: chart,
          files: files,
          repository: repository
        )
      end

      private

      def ensure_runner
        runner || create_and_assign_runner
      end

      def create_and_assign_runner
        transaction do
          Ci::Runner.create!(runner_create_params).tap do |runner|
            update!(runner_id: runner.id)
          end
        end
      end

      def runner_create_params
        {
          name: 'kubernetes-cluster',
          runner_type: :project_type,
          tag_list: %w(kubernetes cluster),
          projects: [project]
        }
      end

      def gitlab_url
        Gitlab::Routing.url_helpers.root_url(only_path: false)
      end

      def specification
        {
          "gitlabUrl" => gitlab_url,
          "runnerToken" => ensure_runner.token,
          "runners" => { "privileged" => privileged }
        }
      end

      def content_values
        YAML.load_file(chart_values_file).deep_merge!(specification)
      end
    end
  end
end

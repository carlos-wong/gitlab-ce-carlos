# frozen_string_literal: true

module Clusters
  module Concerns
    module ApplicationCore
      extend ActiveSupport::Concern

      included do
        belongs_to :cluster, class_name: 'Clusters::Cluster', foreign_key: :cluster_id

        validates :cluster, presence: true

        after_initialize :set_initial_status

        def set_initial_status
          return unless not_installable?

          self.status = 'installable' if cluster&.application_helm_available?
        end

        def self.application_name
          self.to_s.demodulize.underscore
        end

        def name
          self.class.application_name
        end

        def schedule_status_update
          # Override if you need extra data synchronized
          # from K8s after installation
        end

        def update_command
          install_command.tap do |command|
            command.version = version
          end
        end
      end
    end
  end
end

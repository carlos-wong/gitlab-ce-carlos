# frozen_string_literal: true

module Gitlab
  module Database
    class Migration
      module LockRetriesConcern
        extend ActiveSupport::Concern

        class_methods do
          def enable_lock_retries!
            @enable_lock_retries = true # rubocop:disable Gitlab/ModuleWithInstanceVariables
          end

          def enable_lock_retries?
            @enable_lock_retries
          end
        end

        delegate :enable_lock_retries?, to: :class
      end

      # This implements a simple versioning scheme for migration helpers.
      #
      # We need to be able to version helpers, so we can change their behavior without
      # altering the behavior of already existing migrations in incompatible ways.
      #
      # We can continue to change the behavior of helpers without bumping the version here,
      # *if* the change is backwards-compatible.
      #
      # If not, we would typically override the helper method in a new MigrationHelpers::V[0-9]+
      # class and create a new entry with a bumped version below.
      #
      # We use major version bumps to indicate significant changes and minor version bumps
      # to indicate backwards-compatible or otherwise minor changes (e.g. a Rails version bump).
      # However, this hasn't been strictly formalized yet.

      class V1_0 < ActiveRecord::Migration[6.1] # rubocop:disable Naming/ClassAndModuleCamelCase
        include LockRetriesConcern
        include Gitlab::Database::MigrationHelpers::V2
      end

      class V2_0 < V1_0 # rubocop:disable Naming/ClassAndModuleCamelCase
        include Gitlab::Database::MigrationHelpers::RestrictGitlabSchema

        # When running migrations, the `db:migrate` switches connection of
        # ActiveRecord::Base depending where the migration runs.
        # This helper class is provided to avoid confusion using `ActiveRecord::Base`
        class MigrationRecord < ActiveRecord::Base
        end
      end

      def self.[](version)
        version = version.to_s
        name = "V#{version.tr('.', '_')}"
        raise ArgumentError, "Unknown migration version: #{version}" unless const_defined?(name, false)

        const_get(name, false)
      end

      # The current version to be used in new migrations
      def self.current_version
        2.0
      end
    end
  end
end

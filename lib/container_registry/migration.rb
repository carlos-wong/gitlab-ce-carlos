# frozen_string_literal: true

module ContainerRegistry
  module Migration
    # Some container repositories do not have a plan associated with them, they will be imported with
    # the free tiers
    FREE_TIERS = ['free', 'early_adopter', nil].freeze
    PREMIUM_TIERS = %w[premium bronze silver premium_trial].freeze
    ULTIMATE_TIERS = %w[ultimate gold ultimate_trial].freeze
    PLAN_GROUPS = {
      'free' => FREE_TIERS,
      'premium' => PREMIUM_TIERS,
      'ultimate' => ULTIMATE_TIERS
    }.freeze

    class << self
      delegate :container_registry_import_max_tags_count, to: ::Gitlab::CurrentSettings
      delegate :container_registry_import_max_retries, to: ::Gitlab::CurrentSettings
      delegate :container_registry_import_start_max_retries, to: ::Gitlab::CurrentSettings
      delegate :container_registry_import_max_step_duration, to: ::Gitlab::CurrentSettings
      delegate :container_registry_import_target_plan, to: ::Gitlab::CurrentSettings
      delegate :container_registry_import_created_before, to: ::Gitlab::CurrentSettings

      alias_method :max_tags_count, :container_registry_import_max_tags_count
      alias_method :max_retries, :container_registry_import_max_retries
      alias_method :start_max_retries, :container_registry_import_start_max_retries
      alias_method :max_step_duration, :container_registry_import_max_step_duration
      alias_method :target_plan_name, :container_registry_import_target_plan
      alias_method :created_before, :container_registry_import_created_before
    end

    def self.enabled?
      Feature.enabled?(:container_registry_migration_phase2_enabled)
    end

    def self.limit_gitlab_org?
      Feature.enabled?(:container_registry_migration_limit_gitlab_org)
    end

    def self.enqueue_waiting_time
      return 0 if Feature.enabled?(:container_registry_migration_phase2_enqueue_speed_fast)
      return 165.minutes if Feature.enabled?(:container_registry_migration_phase2_enqueue_speed_slow)

      45.minutes
    end

    def self.capacity
      # Increasing capacity numbers will increase the n+1 API calls we can have
      # in ContainerRegistry::Migration::GuardWorker#external_migration_in_progress?
      #
      # TODO: See https://gitlab.com/gitlab-org/container-registry/-/issues/582
      #
      return 25 if Feature.enabled?(:container_registry_migration_phase2_capacity_25)
      return 10 if Feature.enabled?(:container_registry_migration_phase2_capacity_10)
      return 1 if Feature.enabled?(:container_registry_migration_phase2_capacity_1)

      0
    end

    def self.target_plans
      PLAN_GROUPS[target_plan_name]
    end

    def self.all_plans?
      Feature.enabled?(:container_registry_migration_phase2_all_plans)
    end
  end
end

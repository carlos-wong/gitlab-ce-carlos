# frozen_string_literal: true

class OnboardingProgress < ApplicationRecord
  belongs_to :namespace, optional: false

  validate :namespace_is_root_namespace

  ACTIONS = [
    :git_pull,
    :git_write,
    :merge_request_created,
    :pipeline_created,
    :user_added,
    :trial_started,
    :subscription_created,
    :required_mr_approvals_enabled,
    :code_owners_enabled,
    :scoped_label_created,
    :security_scan_enabled,
    :issue_created,
    :issue_auto_closed,
    :repository_imported,
    :repository_mirrored,
    :secure_dependency_scanning_run,
    :secure_container_scanning_run,
    :secure_dast_run,
    :secure_secret_detection_run,
    :secure_coverage_fuzzing_run,
    :secure_api_fuzzing_run,
    :secure_cluster_image_scanning_run,
    :license_scanning_run
  ].freeze

  scope :incomplete_actions, -> (actions) do
    Array.wrap(actions).inject(self) { |scope, action| scope.where(column_name(action) => nil) }
  end

  scope :completed_actions, -> (actions) do
    Array.wrap(actions).inject(self) { |scope, action| scope.where.not(column_name(action) => nil) }
  end

  scope :completed_actions_with_latest_in_range, -> (actions, range) do
    actions = Array(actions)
    if actions.size == 1
      where(column_name(actions[0]) => range)
    else
      action_columns = actions.map { |action| arel_table[column_name(action)] }
      completed_actions(actions).where(Arel::Nodes::NamedFunction.new('GREATEST', action_columns).between(range))
    end
  end

  class << self
    def onboard(namespace)
      return unless root_namespace?(namespace)

      create(namespace: namespace)
    end

    def onboarding?(namespace)
      where(namespace: namespace).any?
    end

    def register(namespace, actions)
      actions = Array(actions)
      return unless root_namespace?(namespace) && actions.difference(ACTIONS).empty?

      onboarding_progress = find_by(namespace: namespace)
      return unless onboarding_progress

      now = Time.current
      nil_actions = actions.select { |action| onboarding_progress[column_name(action)].nil? }
      return if nil_actions.empty?

      updates = nil_actions.inject({}) { |sum, action| sum.merge!({ column_name(action) => now }) }
      onboarding_progress.update!(updates)
    end

    def completed?(namespace, action)
      return unless root_namespace?(namespace) && ACTIONS.include?(action)

      action_column = column_name(action)
      where(namespace: namespace).where.not(action_column => nil).exists?
    end

    def not_completed?(namespace_id, action)
      return unless ACTIONS.include?(action)

      action_column = column_name(action)
      where(namespace_id: namespace_id).where(action_column => nil).exists?
    end

    def column_name(action)
      :"#{action}_at"
    end

    private

    def root_namespace?(namespace)
      namespace && namespace.root?
    end
  end

  def number_of_completed_actions
    attributes.extract!(*ACTIONS.map { |action| self.class.column_name(action).to_s }).compact!.size
  end

  private

  def namespace_is_root_namespace
    return unless namespace

    errors.add(:namespace, _('must be a root namespace')) if namespace.has_parent?
  end
end

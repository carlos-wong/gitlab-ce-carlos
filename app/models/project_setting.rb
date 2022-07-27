# frozen_string_literal: true

class ProjectSetting < ApplicationRecord
  ALLOWED_TARGET_PLATFORMS = %w(ios osx tvos watchos android).freeze

  belongs_to :project, inverse_of: :project_setting

  scope :for_projects, ->(projects) { where(project_id: projects) }

  enum squash_option: {
    never: 0,
    always: 1,
    default_on: 2,
    default_off: 3
  }, _prefix: 'squash'

  self.primary_key = :project_id

  validates :merge_commit_template, length: { maximum: Project::MAX_COMMIT_TEMPLATE_LENGTH }
  validates :squash_commit_template, length: { maximum: Project::MAX_COMMIT_TEMPLATE_LENGTH }
  validates :target_platforms, inclusion: { in: ALLOWED_TARGET_PLATFORMS }

  validate :validates_mr_default_target_self

  default_value_for(:legacy_open_source_license_available) do
    Feature.enabled?(:legacy_open_source_license_available, type: :ops)
  end

  def squash_enabled_by_default?
    %w[always default_on].include?(squash_option)
  end

  def squash_readonly?
    %w[always never].include?(squash_option)
  end

  def target_platforms=(val)
    super(val&.map(&:to_s)&.sort)
  end

  def human_squash_option
    case squash_option
    when 'never' then 'Do not allow'
    when 'always' then 'Require'
    when 'default_on' then 'Encourage'
    when 'default_off' then 'Allow'
    end
  end

  private

  def validates_mr_default_target_self
    if mr_default_target_self_changed? && !project.forked?
      errors.add :mr_default_target_self, _('This setting is allowed for forked projects only')
    end
  end
end

ProjectSetting.prepend_mod

# frozen_string_literal: true

class NotificationSetting < ApplicationRecord
  enum level: { global: 3, watch: 2, participating: 1, mention: 4, disabled: 0, custom: 5 }

  default_value_for :level, NotificationSetting.levels[:global]

  belongs_to :user
  belongs_to :source, polymorphic: true # rubocop:disable Cop/PolymorphicAssociations
  belongs_to :project, foreign_key: 'source_id'

  validates :user, presence: true
  validates :level, presence: true
  validates :user_id, uniqueness: { scope: [:source_type, :source_id],
                                    message: "already exists in source",
                                    allow_nil: true }

  scope :for_groups, -> { where(source_type: 'Namespace') }

  # Exclude projects not included by the Project model's default scope (those that are
  # pending delete).
  #
  scope :for_projects, -> do
    includes(:project).references(:projects)
      .where(source_type: 'Project')
      .where.not(projects: { id: nil })
      .where.not(projects: { pending_delete: true })
  end

  scope :preload_source_route, -> { preload(source: [:route]) }

  EMAIL_EVENTS = [
    :new_release,
    :new_note,
    :new_issue,
    :reopen_issue,
    :close_issue,
    :reassign_issue,
    :issue_due,
    :new_merge_request,
    :push_to_merge_request,
    :reopen_merge_request,
    :close_merge_request,
    :reassign_merge_request,
    :merge_merge_request,
    :failed_pipeline,
    :success_pipeline
  ].freeze

  # Update unfound_translations.rb when events are changed
  def self.email_events(source = nil)
    EMAIL_EVENTS
  end

  def self.allowed_fields(source = nil)
    NotificationSetting.email_events(source).dup + %i(level notification_email)
  end

  def email_events
    self.class.email_events(source)
  end

  EXCLUDED_WATCHER_EVENTS = [
    :push_to_merge_request,
    :issue_due,
    :success_pipeline
  ].freeze

  def self.find_or_create_for(source)
    setting = find_or_initialize_by(source: source)

    unless setting.persisted?
      setting.save
    end

    setting
  end

  # Allow people to receive failed pipeline notifications if they already have
  # custom notifications enabled, as these are more like mentions than the other
  # custom settings.
  def failed_pipeline
    bool = super

    bool.nil? || bool
  end
  alias_method :failed_pipeline?, :failed_pipeline

  def event_enabled?(event)
    respond_to?(event) && !!public_send(event) # rubocop:disable GitlabSecurity/PublicSend
  end
end

NotificationSetting.prepend_if_ee('EE::NotificationSetting')

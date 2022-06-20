# frozen_string_literal: true

# The BulkImport model links all models required for a bulk import of groups and
# projects to a GitLab instance. It associates the import with the responsible
# user.
class BulkImport < ApplicationRecord
  MIN_MAJOR_VERSION = 14
  MIN_MINOR_VERSION_FOR_PROJECT = 4

  belongs_to :user, optional: false

  has_one :configuration, class_name: 'BulkImports::Configuration'
  has_many :entities, class_name: 'BulkImports::Entity'

  validates :source_type, :status, presence: true

  enum source_type: { gitlab: 0 }

  scope :stale, -> { where('created_at < ?', 8.hours.ago).where(status: [0, 1]) }
  scope :order_by_created_at, -> (direction) { order(created_at: direction) }

  state_machine :status, initial: :created do
    state :created, value: 0
    state :started, value: 1
    state :finished, value: 2
    state :timeout, value: 3
    state :failed, value: -1

    event :start do
      transition created: :started
    end

    event :finish do
      transition started: :finished
    end

    event :cleanup_stale do
      transition created: :timeout
      transition started: :timeout
    end

    event :fail_op do
      transition any => :failed
    end
  end

  def source_version_info
    Gitlab::VersionInfo.parse(source_version)
  end

  def self.min_gl_version_for_project_migration
    Gitlab::VersionInfo.new(MIN_MAJOR_VERSION, MIN_MINOR_VERSION_FOR_PROJECT)
  end

  def self.all_human_statuses
    state_machine.states.map(&:human_name)
  end
end

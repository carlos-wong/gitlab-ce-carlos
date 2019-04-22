# frozen_string_literal: true

# An InternalId is a strictly monotone sequence of integers
# generated for a given scope and usage.
#
# The monotone sequence may be broken if an ID is explicitly provided
# to `.track_greatest_and_save!` or `#track_greatest`.
#
# For example, issues use their project to scope internal ids:
# In that sense, scope is "project" and usage is "issues".
# Generated internal ids for an issue are unique per project.
#
# See InternalId#usage enum for available usages.
#
# In order to leverage InternalId for other usages, the idea is to
# * Add `usage` value to enum
# * (Optionally) add columns to `internal_ids` if needed for scope.
class InternalId < ApplicationRecord
  belongs_to :project
  belongs_to :namespace

  enum usage: { issues: 0, merge_requests: 1, deployments: 2, milestones: 3, epics: 4, ci_pipelines: 5 }

  validates :usage, presence: true

  REQUIRED_SCHEMA_VERSION = 20180305095250

  # Increments #last_value and saves the record
  #
  # The operation locks the record and gathers a `ROW SHARE` lock (in PostgreSQL).
  # As such, the increment is atomic and safe to be called concurrently.
  def increment_and_save!
    update_and_save { self.last_value = (last_value || 0) + 1 }
  end

  # Increments #last_value with new_value if it is greater than the current,
  # and saves the record
  #
  # The operation locks the record and gathers a `ROW SHARE` lock (in PostgreSQL).
  # As such, the increment is atomic and safe to be called concurrently.
  def track_greatest_and_save!(new_value)
    update_and_save { self.last_value = [last_value || 0, new_value].max }
  end

  private

  def update_and_save(&block)
    lock!
    yield
    save!
    last_value
  end

  class << self
    def track_greatest(subject, scope, usage, new_value, init)
      return new_value unless available?

      InternalIdGenerator.new(subject, scope, usage, init).track_greatest(new_value)
    end

    def generate_next(subject, scope, usage, init)
      # Shortcut if `internal_ids` table is not available (yet)
      # This can be the case in other (unrelated) migration specs
      return (init.call(subject) || 0) + 1 unless available?

      InternalIdGenerator.new(subject, scope, usage, init).generate
    end

    # Flushing records is generally safe in a sense that those
    # records are going to be re-created when needed.
    #
    # A filter condition has to be provided to not accidentally flush
    # records for all projects.
    def flush_records!(filter)
      raise ArgumentError, "filter cannot be empty" if filter.blank?

      where(filter).delete_all
    end

    def available?
      @available_flag ||= ActiveRecord::Migrator.current_version >= REQUIRED_SCHEMA_VERSION # rubocop:disable Gitlab/PredicateMemoization
    end

    # Flushes cached information about schema
    def reset_column_information
      @available_flag = nil
      super
    end
  end

  class InternalIdGenerator
    # Generate next internal id for a given scope and usage.
    #
    # For currently supported usages, see #usage enum.
    #
    # The method implements a locking scheme that has the following properties:
    # 1) Generated sequence of internal ids is unique per (scope and usage)
    # 2) The method is thread-safe and may be used in concurrent threads/processes.
    # 3) The generated sequence is gapless.
    # 4) In the absence of a record in the internal_ids table, one will be created
    #    and last_value will be calculated on the fly.
    #
    # subject: The instance we're generating an internal id for. Gets passed to init if called.
    # scope: Attributes that define the scope for id generation.
    # usage: Symbol to define the usage of the internal id, see InternalId.usages
    # init: Block that gets called to initialize InternalId record if not present
    #       Make sure to not throw exceptions in the absence of records (if this is expected).
    attr_reader :subject, :scope, :init, :scope_attrs, :usage

    def initialize(subject, scope, usage, init)
      @subject = subject
      @scope = scope
      @init = init
      @usage = usage

      raise ArgumentError, 'Scope is not well-defined, need at least one column for scope (given: 0)' if scope.empty?

      unless InternalId.usages.has_key?(usage.to_s)
        raise ArgumentError, "Usage '#{usage}' is unknown. Supported values are #{InternalId.usages.keys} from InternalId.usages"
      end
    end

    # Generates next internal id and returns it
    def generate
      subject.transaction do
        # Create a record in internal_ids if one does not yet exist
        # and increment its last value
        #
        # Note this will acquire a ROW SHARE lock on the InternalId record
        (lookup || create_record).increment_and_save!
      end
    end

    # Create a record in internal_ids if one does not yet exist
    # and set its new_value if it is higher than the current last_value
    #
    # Note this will acquire a ROW SHARE lock on the InternalId record
    def track_greatest(new_value)
      subject.transaction do
        (lookup || create_record).track_greatest_and_save!(new_value)
      end
    end

    private

    # Retrieve InternalId record for (project, usage) combination, if it exists
    def lookup
      InternalId.find_by(**scope, usage: usage_value)
    end

    def usage_value
      @usage_value ||= InternalId.usages[usage.to_s]
    end

    # Create InternalId record for (scope, usage) combination, if it doesn't exist
    #
    # We blindly insert without synchronization. If another process
    # was faster in doing this, we'll realize once we hit the unique key constraint
    # violation. We can safely roll-back the nested transaction and perform
    # a lookup instead to retrieve the record.
    def create_record
      subject.transaction(requires_new: true) do
        InternalId.create!(
          **scope,
          usage: usage_value,
          last_value: init.call(subject) || 0
        )
      end
    rescue ActiveRecord::RecordNotUnique
      lookup
    end
  end
end

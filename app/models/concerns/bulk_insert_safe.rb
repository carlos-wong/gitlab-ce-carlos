# frozen_string_literal: true

##
# A mixin for ActiveRecord models that enables callers to insert instances of the
# target class into the database en-bloc via the [bulk_insert] method.
#
# Upon inclusion in the target class, the mixin will perform a number of checks to
# ensure that the target is eligible for bulk insertions. For instance, it must not
# use ActiveRecord callbacks that fire between [save]s, since these would not run
# properly when instances are inserted in bulk.
#
# The mixin uses ActiveRecord 6's [InsertAll] type internally for bulk insertions.
# Unlike [InsertAll], however, it requires you to pass instances of the target type
# rather than row hashes, since it will run validations prior to insertion.
#
# @example
#
#   class MyRecord < ApplicationRecord
#     include BulkInsertSafe # must be included _last_ i.e. after any other concerns
#   end
#
#   # simple
#   MyRecord.bulk_insert!(items)
#
#   # with custom batch size
#   MyRecord.bulk_insert!(items, batch_size: 100)
#
#   # without validations
#   MyRecord.bulk_insert!(items, validate: false)
#
#   # with attribute hash modification
#   MyRecord.bulk_insert!(items) { |item_attrs| item_attrs['col'] = 42 }
#
#
module BulkInsertSafe
  extend ActiveSupport::Concern

  # These are the callbacks we think safe when used on models that are
  # written to the database in bulk
  CALLBACK_NAME_WHITELIST = Set[
    :initialize,
    :validate,
    :validation,
    :find,
    :destroy
  ].freeze

  DEFAULT_BATCH_SIZE = 500

  MethodNotAllowedError = Class.new(StandardError)
  PrimaryKeySetError = Class.new(StandardError)

  class_methods do
    def set_callback(name, *args)
      unless _bulk_insert_callback_allowed?(name, args)
        raise MethodNotAllowedError.new(
          "Not allowed to call `set_callback(#{name}, #{args})` when model extends `BulkInsertSafe`." \
            "Callbacks that fire per each record being inserted do not work with bulk-inserts.")
      end

      super
    end

    # Inserts the given ActiveRecord [items] to the table mapped to this class.
    # Items will be inserted in batches of a given size, where insertion semantics are
    # "atomic across all batches".
    #
    # @param [Boolean] validate          Whether validations should run on [items]
    # @param [Integer] batch_size        How many items should at most be inserted at once
    # @param [Boolean] skip_duplicates   Marks duplicates as allowed, and skips inserting them
    # @param [Proc]    handle_attributes Block that will receive each item attribute hash
    #                                    prior to insertion for further processing
    #
    # Note that this method will throw on the following occasions:
    # - [PrimaryKeySetError]            when primary keys are set on entities prior to insertion
    # - [ActiveRecord::RecordInvalid]   on entity validation failures
    # - [ActiveRecord::RecordNotUnique] on duplicate key errors
    #
    # @return true if operation succeeded, throws otherwise.
    #
    def bulk_insert!(items, validate: true, skip_duplicates: false, batch_size: DEFAULT_BATCH_SIZE, &handle_attributes)
      _bulk_insert_all!(items,
        validate: validate,
        on_duplicate: skip_duplicates ? :skip : :raise,
        unique_by: nil,
        batch_size: batch_size,
        &handle_attributes)
    end

    # Upserts the given ActiveRecord [items] to the table mapped to this class.
    # Items will be inserted or updated in batches of a given size,
    # where insertion semantics are "atomic across all batches".
    #
    # @param [Boolean] validate          Whether validations should run on [items]
    # @param [Integer] batch_size        How many items should at most be inserted at once
    # @param [Symbol/Array] unique_by    Defines index or columns to use to consider item duplicate
    # @param [Proc]    handle_attributes Block that will receive each item attribute hash
    #                                    prior to insertion for further processing
    #
    # Unique indexes can be identified by columns or name:
    #  - unique_by: :isbn
    #  - unique_by: %i[ author_id name ]
    #  - unique_by: :index_books_on_isbn
    #
    # Note that this method will throw on the following occasions:
    # - [PrimaryKeySetError]            when primary keys are set on entities prior to insertion
    # - [ActiveRecord::RecordInvalid]   on entity validation failures
    # - [ActiveRecord::RecordNotUnique] on duplicate key errors
    #
    # @return true if operation succeeded, throws otherwise.
    #
    def bulk_upsert!(items, unique_by:, validate: true, batch_size: DEFAULT_BATCH_SIZE, &handle_attributes)
      _bulk_insert_all!(items,
        validate: validate,
        on_duplicate: :update,
        unique_by: unique_by,
        batch_size: batch_size,
        &handle_attributes)
    end

    private

    def _bulk_insert_all!(items, on_duplicate:, unique_by:, validate:, batch_size:, &handle_attributes)
      return true if items.empty?

      transaction do
        items.each_slice(batch_size) do |item_batch|
          attributes = _bulk_insert_item_attributes(
            item_batch, validate, &handle_attributes)

          ActiveRecord::InsertAll
            .new(self, attributes, on_duplicate: on_duplicate, unique_by: unique_by)
            .execute
        end
      end

      true
    end

    def _bulk_insert_item_attributes(items, validate_items)
      items.map do |item|
        item.validate! if validate_items

        attributes = {}
        column_names.each do |name|
          value = item.read_attribute(name)
          value = item.type_for_attribute(name).serialize(value) # rubocop:disable Cop/ActiveRecordSerialize
          attributes[name] = value
        end

        _bulk_insert_reject_primary_key!(attributes, item.class.primary_key)

        yield attributes if block_given?

        attributes
      end
    end

    def _bulk_insert_reject_primary_key!(attributes, primary_key)
      if existing_pk = attributes.delete(primary_key)
        raise PrimaryKeySetError, "Primary key set: #{primary_key}:#{existing_pk}\n" \
          "Bulk-inserts are only supported for rows that don't already have PK set"
      end
    end

    def _bulk_insert_callback_allowed?(name, args)
      _bulk_insert_whitelisted?(name) || _bulk_insert_saved_from_belongs_to?(name, args)
    end

    # belongs_to associations will install a before_save hook during class loading
    def _bulk_insert_saved_from_belongs_to?(name, args)
      args.first == :before && args.second.to_s.start_with?('autosave_associated_records_for_')
    end

    def _bulk_insert_whitelisted?(name)
      CALLBACK_NAME_WHITELIST.include?(name)
    end
  end
end

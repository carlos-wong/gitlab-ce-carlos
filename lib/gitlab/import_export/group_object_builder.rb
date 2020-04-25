# frozen_string_literal: true

module Gitlab
  module ImportExport
    # Given a class, it finds or creates a new object at group level.
    #
    # Example:
    #   `GroupObjectBuilder.build(Label, label_attributes)`
    #    finds or initializes a label with the given attributes.
    class GroupObjectBuilder < BaseObjectBuilder
      def self.build(*args)
        Group.transaction do
          super
        end
      end

      def initialize(klass, attributes)
        super

        @group = @attributes['group']

        update_description
      end

      private

      attr_reader :group

      # Convert description empty string to nil
      # due to existing object being saved with description: nil
      # Which makes object lookup to fail since nil != ''
      def update_description
        attributes['description'] = nil if attributes['description'] == ''
      end

      def where_clauses
        [
          where_clause_base,
          where_clause_for_title,
          where_clause_for_description,
          where_clause_for_created_at
        ].compact
      end

      # Returns Arel clause `"{table_name}"."group_id" = {group.id}`
      def where_clause_base
        table[:group_id].in(group_and_ancestor_ids)
      end

      def group_and_ancestor_ids
        group.ancestors.map(&:id) << group.id
      end
    end
  end
end

# frozen_string_literal: true

module Banzai
  module Filter
    # The actual filter is implemented in the EE mixin
    class EpicReferenceFilter < IssuableReferenceFilter
      prepend_if_ee('EE::Banzai::Filter::EpicReferenceFilter') # rubocop: disable Cop/InjectEnterpriseEditionModule

      self.reference_type = :epic

      def self.object_class
        Epic
      end

      private

      def group
        context[:group] || context[:project]&.group
      end
    end
  end
end

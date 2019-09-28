# frozen_string_literal: true

module Banzai
  module ReferenceParser
    # The actual parser is implemented in the EE mixin
    class EpicParser < IssuableParser
      prepend_if_ee('::EE::Banzai::ReferenceParser::EpicParser') # rubocop: disable Cop/InjectEnterpriseEditionModule

      self.reference_type = :epic

      def records_for_nodes(_nodes)
        {}
      end
    end
  end
end

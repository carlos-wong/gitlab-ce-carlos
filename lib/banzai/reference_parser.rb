# frozen_string_literal: true

module Banzai
  module ReferenceParser
    # Returns the reference parser class for the given type
    #
    # Example:
    #
    #     Banzai::ReferenceParser['issue']
    #
    # This would return the `Banzai::ReferenceParser::IssueParser` class.
    def self.[](name)
      const_get("#{name.to_s.camelize}Parser", false)
    end
  end
end

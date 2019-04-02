# frozen_string_literal: true

module Gitlab
  module Config
    module Entry
      module LegacyValidationHelpers
        private

        def validate_duration(value)
          value.is_a?(String) && ChronicDuration.parse(value)
        rescue ChronicDuration::DurationParseError
          false
        end

        def validate_duration_limit(value, limit)
          return false unless value.is_a?(String)

          ChronicDuration.parse(value).second.from_now <
            ChronicDuration.parse(limit).second.from_now
        rescue ChronicDuration::DurationParseError
          false
        end

        def validate_array_of_strings(values)
          values.is_a?(Array) && values.all? { |value| validate_string(value) }
        end

        def validate_array_of_strings_or_regexps(values)
          values.is_a?(Array) && values.all? { |value| validate_string_or_regexp(value) }
        end

        def validate_variables(variables)
          variables.is_a?(Hash) &&
            variables.flatten.all? do |value|
              validate_string(value) || validate_integer(value)
            end
        end

        def validate_integer(value)
          value.is_a?(Integer)
        end

        def validate_string(value)
          value.is_a?(String) || value.is_a?(Symbol)
        end

        def validate_regexp(value)
          Gitlab::UntrustedRegexp::RubySyntax.valid?(value)
        end

        def validate_string_or_regexp(value)
          return true if value.is_a?(Symbol)
          return false unless value.is_a?(String)

          if Gitlab::UntrustedRegexp::RubySyntax.matches_syntax?(value)
            validate_regexp(value)
          else
            true
          end
        end

        def validate_boolean(value)
          value.in?([true, false])
        end
      end
    end
  end
end

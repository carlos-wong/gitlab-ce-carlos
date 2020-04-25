# frozen_string_literal: true

module Gitlab
  module Utils
    module LogLimitedArray
      MAXIMUM_ARRAY_LENGTH = 10.kilobytes

      # Prepare an array for logging by limiting its JSON representation
      # to around 10 kilobytes. Once we hit the limit, add "..." as the
      # last item in the returned array.
      def self.log_limited_array(array)
        return [] unless array.is_a?(Array)

        total_length = 0
        limited_array = array.take_while do |arg|
          total_length += arg.to_json.length

          total_length <= MAXIMUM_ARRAY_LENGTH
        end

        limited_array.push('...') if total_length > MAXIMUM_ARRAY_LENGTH

        limited_array
      end
    end
  end
end

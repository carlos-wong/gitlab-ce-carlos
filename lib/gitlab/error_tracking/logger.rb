# frozen_string_literal: true

module Gitlab
  module ErrorTracking
    class Logger < ::Gitlab::JsonLogger
      def self.file_name_noext
        'exceptions_json'
      end
    end
  end
end

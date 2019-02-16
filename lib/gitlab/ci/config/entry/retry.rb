# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Entry
        ##
        # Entry that represents a retry config for a job.
        #
        class Retry < ::Gitlab::Config::Entry::Simplifiable
          strategy :SimpleRetry, if: -> (config) { config.is_a?(Integer) }
          strategy :FullRetry, if: -> (config) { config.is_a?(Hash) }

          class SimpleRetry < ::Gitlab::Config::Entry::Node
            include ::Gitlab::Config::Entry::Validatable

            validations do
              validates :config, numericality: { only_integer: true,
                                                 greater_than_or_equal_to: 0,
                                                 less_than_or_equal_to: 2 }
            end

            def value
              {
                max: config
              }
            end

            def location
              'retry'
            end
          end

          class FullRetry < ::Gitlab::Config::Entry::Node
            include ::Gitlab::Config::Entry::Validatable
            include ::Gitlab::Config::Entry::Attributable

            ALLOWED_KEYS = %i[max when].freeze
            attributes :max, :when

            validations do
              validates :config, allowed_keys: ALLOWED_KEYS

              with_options allow_nil: true do
                validates :max, numericality: { only_integer: true,
                                                greater_than_or_equal_to: 0,
                                                less_than_or_equal_to: 2 }

                validates :when, array_of_strings_or_string: true
                validates :when,
                          allowed_array_values: { in: FullRetry.possible_retry_when_values },
                          if: -> (config) { config.when.is_a?(Array) }
                validates :when,
                          inclusion: { in: FullRetry.possible_retry_when_values },
                          if: -> (config) { config.when.is_a?(String) }
              end
            end

            def self.possible_retry_when_values
              @possible_retry_when_values ||= ::Ci::Build.failure_reasons.keys.map(&:to_s) + ['always']
            end

            def value
              super.tap do |config|
                # make sure that `when` is an array, because we allow it to
                # be passed as a String in config for simplicity
                config[:when] = Array.wrap(config[:when]) if config[:when]
              end
            end

            def location
              'retry'
            end
          end

          class UnknownStrategy < ::Gitlab::Config::Entry::Node
            def errors
              ["#{location} has to be either an integer or a hash"]
            end

            def location
              'retry config'
            end
          end
        end
      end
    end
  end
end

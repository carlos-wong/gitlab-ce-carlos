# frozen_string_literal: true

module Gitlab
  module Config
    module Entry
      class Simplifiable < SimpleDelegator
        EntryStrategy = Struct.new(:name, :condition)

        attr_reader :subject

        def initialize(config, **metadata)
          unless self.class.const_defined?(:UnknownStrategy)
            raise ArgumentError, 'UndefinedStrategy not available!'
          end

          strategy = self.class.strategies.find do |variant|
            variant.condition.call(config)
          end

          entry = self.class.entry_class(strategy)

          super(@subject = entry.new(config, metadata))
        end

        def self.strategy(name, **opts)
          EntryStrategy.new(name, opts.fetch(:if)).tap do |strategy|
            strategies.append(strategy)
          end
        end

        def self.strategies
          @strategies ||= []
        end

        def self.entry_class(strategy)
          if strategy.present?
            self.const_get(strategy.name)
          else
            self::UnknownStrategy
          end
        end

        def self.default
        end
      end
    end
  end
end

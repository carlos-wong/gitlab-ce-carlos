# frozen_string_literal: true

module Gitlab
  module Config
    module Entry
      ##
      # This mixin is responsible for adding DSL, which purpose is to
      # simplifly process of adding child nodes.
      #
      # This can be used only if parent node is a configuration entry that
      # holds a hash as a configuration value, for example:
      #
      # job:
      #   script: ...
      #   artifacts: ...
      #
      module Configurable
        extend ActiveSupport::Concern

        included do
          include Validatable

          validations do
            validates :config, type: Hash
          end
        end

        # rubocop: disable CodeReuse/ActiveRecord
        def compose!(deps = nil)
          return unless valid?

          self.class.nodes.each do |key, factory|
            factory
              .value(config[key])
              .with(key: key, parent: self)

            entries[key] = factory.create!
          end

          yield if block_given?

          entries.each_value do |entry|
            entry.compose!(deps)
          end
        end
        # rubocop: enable CodeReuse/ActiveRecord

        class_methods do
          def nodes
            Hash[(@nodes || {}).map { |key, factory| [key, factory.dup] }]
          end

          private

          # rubocop: disable CodeReuse/ActiveRecord
          def entry(key, entry, metadata)
            factory = ::Gitlab::Config::Entry::Factory.new(entry)
              .with(description: metadata[:description])
              .with(default: metadata[:default])

            (@nodes ||= {}).merge!(key.to_sym => factory)
          end
          # rubocop: enable CodeReuse/ActiveRecord

          def helpers(*nodes)
            nodes.each do |symbol|
              define_method("#{symbol}_defined?") do
                entries[symbol]&.specified?
              end

              define_method("#{symbol}_value") do
                return unless entries[symbol] && entries[symbol].valid?

                entries[symbol].value
              end
            end
          end
        end
      end
    end
  end
end

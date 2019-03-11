# frozen_string_literal: true

module Gitlab
  module QuickActions
    class CommandDefinition
      attr_accessor :name, :aliases, :description, :explanation, :params,
        :condition_block, :parse_params_block, :action_block, :warning

      def initialize(name, attributes = {})
        @name = name

        @aliases = attributes[:aliases] || []
        @description = attributes[:description] || ''
        @warning = attributes[:warning] || ''
        @explanation = attributes[:explanation] || ''
        @params = attributes[:params] || []
        @condition_block = attributes[:condition_block]
        @parse_params_block = attributes[:parse_params_block]
        @action_block = attributes[:action_block]
      end

      def all_names
        [name, *aliases]
      end

      def noop?
        action_block.nil?
      end

      def available?(context)
        return true unless condition_block

        context.instance_exec(&condition_block)
      end

      def explain(context, arg)
        return unless available?(context)

        message = if explanation.respond_to?(:call)
                    execute_block(explanation, context, arg)
                  else
                    explanation
                  end

        warning.empty? ? message : "#{message} (#{warning})"
      end

      def execute(context, arg)
        return if noop? || !available?(context)

        count_commands_executed_in(context)

        execute_block(action_block, context, arg)
      end

      def to_h(context)
        desc = description
        if desc.respond_to?(:call)
          desc = context.instance_exec(&desc) rescue ''
        end

        prms = params
        if prms.respond_to?(:call)
          prms = Array(context.instance_exec(&prms)) rescue params
        end

        {
          name: name,
          aliases: aliases,
          description: desc,
          warning: warning,
          params: prms
        }
      end

      private

      def count_commands_executed_in(context)
        return unless context.respond_to?(:commands_executed_count=)

        context.commands_executed_count ||= 0
        context.commands_executed_count += 1
      end

      def execute_block(block, context, arg)
        if arg.present?
          parsed = parse_params(arg, context)
          context.instance_exec(parsed, &block)
        elsif block.arity == 0
          context.instance_exec(&block)
        end
      end

      def parse_params(arg, context)
        return arg unless parse_params_block

        context.instance_exec(arg, &parse_params_block)
      end
    end
  end
end

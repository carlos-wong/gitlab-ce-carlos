# frozen_string_literal: true

module Gitlab
  module CycleAnalytics
    class GroupStageSummary
      attr_reader :group, :current_user, :options

      def initialize(group, options:)
        @group = group
        @current_user = options[:current_user]
        @options = options
      end

      def data
        [serialize(Summary::Group::Issue.new(group: group, current_user: current_user, options: options)),
         serialize(Summary::Group::Deploy.new(group: group, options: options))]
      end

      private

      def serialize(summary_object)
        AnalyticsSummarySerializer.new.represent(summary_object)
      end
    end
  end
end

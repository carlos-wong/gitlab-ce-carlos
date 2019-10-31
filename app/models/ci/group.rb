# frozen_string_literal: true

module Ci
  ##
  # This domain model is a representation of a group of jobs that are related
  # to each other, like `rspec 0 1`, `rspec 0 2`.
  #
  # It is not persisted in the database.
  #
  class Group
    include StaticModel
    include Gitlab::Utils::StrongMemoize

    attr_reader :stage, :name, :jobs

    delegate :size, to: :jobs

    def initialize(stage, name:, jobs:)
      @stage = stage
      @name = name
      @jobs = jobs
    end

    def status
      strong_memoize(:status) do
        if Feature.enabled?(:ci_composite_status, default_enabled: false)
          Gitlab::Ci::Status::Composite
            .new(@jobs)
            .status
        else
          CommitStatus
            .where(id: @jobs)
            .legacy_status
        end
      end
    end

    def detailed_status(current_user)
      if jobs.one?
        jobs.first.detailed_status(current_user)
      else
        Gitlab::Ci::Status::Group::Factory
          .new(self, current_user).fabricate!
      end
    end

    def self.fabricate(stage)
      stage.statuses.ordered.latest
        .sort_by(&:sortable_name).group_by(&:group_name)
        .map do |group_name, grouped_statuses|
          self.new(stage, name: group_name, jobs: grouped_statuses)
        end
    end
  end
end

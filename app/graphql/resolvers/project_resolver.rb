# frozen_string_literal: true

module Resolvers
  class ProjectResolver < BaseResolver
    prepend FullPathResolver

    type Types::ProjectType, null: true

    def resolve(full_path:)
      model_by_full_path(Project, full_path)
    end

    def self.complexity_multiplier(args)
      0
    end
  end
end

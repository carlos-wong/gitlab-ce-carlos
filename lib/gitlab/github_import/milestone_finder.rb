# frozen_string_literal: true

module Gitlab
  module GithubImport
    class MilestoneFinder
      attr_reader :project

      # The base cache key to use for storing/retrieving milestone IDs.
      CACHE_KEY = 'github-import/milestone-finder/%{project}/%{iid}'

      # project - An instance of `Project`
      def initialize(project)
        @project = project
      end

      # issuable - An instance of `Gitlab::GithubImport::Representation::Issue`
      #            or `Gitlab::GithubImport::Representation::PullRequest`.
      def id_for(issuable)
        return unless issuable.milestone_number

        Gitlab::Cache::Import::Caching.read_integer(cache_key_for(issuable.milestone_number))
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def build_cache
        mapping = @project
          .milestones
          .pluck(:id, :iid)
          .each_with_object({}) do |(id, iid), hash|
            hash[cache_key_for(iid)] = id
          end

        Gitlab::Cache::Import::Caching.write_multiple(mapping)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def cache_key_for(iid)
        CACHE_KEY % { project: project.id, iid: iid }
      end
    end
  end
end

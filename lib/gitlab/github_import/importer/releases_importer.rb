# frozen_string_literal: true

module Gitlab
  module GithubImport
    module Importer
      class ReleasesImporter
        include BulkImporting

        attr_reader :project, :client, :existing_tags

        # project - An instance of `Project`
        # client - An instance of `Gitlab::GithubImport::Client`
        # rubocop: disable CodeReuse/ActiveRecord
        def initialize(project, client)
          @project = project
          @client = client
          @existing_tags = project.releases.pluck(:tag).to_set
        end
        # rubocop: enable CodeReuse/ActiveRecord

        def execute
          bulk_insert(Release, build_releases)
        end

        def build_releases
          build_database_rows(each_release)
        end

        def already_imported?(release)
          existing_tags.include?(release.tag_name)
        end

        def build(release)
          {
            name: release.name,
            tag: release.tag_name,
            description: description_for(release),
            created_at: release.created_at,
            updated_at: release.created_at,
            # Draft releases will have a null published_at
            released_at: release.published_at || Time.current,
            project_id: project.id
          }
        end

        def each_release
          client.releases(project.import_source)
        end

        def description_for(release)
          release.body.presence || "Release for tag #{release.tag_name}"
        end
      end
    end
  end
end

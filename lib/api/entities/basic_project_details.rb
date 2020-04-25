# frozen_string_literal: true

module API
  module Entities
    class BasicProjectDetails < Entities::ProjectIdentity
      include ::API::ProjectsRelationBuilder

      expose :default_branch, if: -> (project, options) { Ability.allowed?(options[:current_user], :download_code, project) }
      # Avoids an N+1 query: https://github.com/mbleigh/acts-as-taggable-on/issues/91#issuecomment-168273770
      expose :tag_list do |project|
        # project.tags.order(:name).pluck(:name) is the most suitable option
        # to avoid loading all the ActiveRecord objects but, if we use it here
        # it override the preloaded associations and makes a query
        # (fixed in https://github.com/rails/rails/pull/25976).
        project.tags.map(&:name).sort
      end

      expose :ssh_url_to_repo, :http_url_to_repo, :web_url, :readme_url

      expose :license_url, if: :license do |project|
        license = project.repository.license_blob

        if license
          Gitlab::Routing.url_helpers.project_blob_url(project, File.join(project.default_branch, license.path))
        end
      end

      expose :license, with: 'API::Entities::LicenseBasic', if: :license do |project|
        project.repository.license
      end

      expose :avatar_url do |project, options|
        project.avatar_url(only_path: false)
      end

      expose :star_count, :forks_count
      expose :last_activity_at
      expose :namespace, using: 'API::Entities::NamespaceBasic'
      expose :custom_attributes, using: 'API::Entities::CustomAttribute', if: :with_custom_attributes

      # rubocop: disable CodeReuse/ActiveRecord
      def self.preload_relation(projects_relation, options = {})
        # Preloading tags, should be done with using only `:tags`,
        # as `:tags` are defined as: `has_many :tags, through: :taggings`
        # N+1 is solved then by using `subject.tags.map(&:name)`
        # MR describing the solution: https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/20555
        projects_relation.preload(:project_feature, :route)
                         .preload(:import_state, :tags)
                         .preload(:auto_devops)
                         .preload(namespace: [:route, :owner])
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end

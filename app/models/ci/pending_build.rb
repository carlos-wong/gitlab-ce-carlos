# frozen_string_literal: true

module Ci
  class PendingBuild < Ci::ApplicationRecord
    include EachBatch

    belongs_to :project
    belongs_to :build, class_name: 'Ci::Build'
    belongs_to :namespace, inverse_of: :pending_builds, class_name: 'Namespace'

    validates :namespace, presence: true

    scope :ref_protected, -> { where(protected: true) }
    scope :queued_before, ->(time) { where(arel_table[:created_at].lt(time)) }
    scope :with_instance_runners, -> { where(instance_runners_enabled: true) }
    scope :for_tags, ->(tag_ids) do
      if tag_ids.present?
        where('ci_pending_builds.tag_ids <@ ARRAY[?]::int[]', Array.wrap(tag_ids))
      else
        where("ci_pending_builds.tag_ids = '{}'")
      end
    end

    class << self
      def upsert_from_build!(build)
        entry = self.new(args_from_build(build))

        entry.validate!

        self.upsert(entry.attributes.compact, returning: %w[build_id], unique_by: :build_id)
      end

      private

      def args_from_build(build)
        project = build.project

        args = {
          build: build,
          project: project,
          protected: build.protected?,
          namespace: project.namespace,
          tag_ids: build.tags_ids,
          instance_runners_enabled: shared_runners_enabled?(project)
        }

        if group_runners_enabled?(project)
          args.store(:namespace_traversal_ids, project.namespace.traversal_ids)
        end

        args
      end

      def shared_runners_enabled?(project)
        builds_enabled?(project) && project.shared_runners_enabled?
      end

      def group_runners_enabled?(project)
        builds_enabled?(project) && project.group_runners_enabled?
      end

      def builds_enabled?(project)
        project.builds_enabled? && !project.pending_delete?
      end
    end
  end
end

Ci::PendingBuild.prepend_mod_with('Ci::PendingBuild')

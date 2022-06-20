# frozen_string_literal: true

module BulkImports
  module Groups
    class Stage < ::BulkImports::Stage
      private

      def config
        @config ||= {
          group: {
            pipeline: BulkImports::Groups::Pipelines::GroupPipeline,
            stage: 0
          },
          subgroups: {
            pipeline: BulkImports::Groups::Pipelines::SubgroupEntitiesPipeline,
            stage: 1
          },
          members: {
            pipeline: BulkImports::Common::Pipelines::MembersPipeline,
            stage: 1
          },
          labels: {
            pipeline: BulkImports::Common::Pipelines::LabelsPipeline,
            stage: 1
          },
          milestones: {
            pipeline: BulkImports::Common::Pipelines::MilestonesPipeline,
            stage: 1
          },
          badges: {
            pipeline: BulkImports::Common::Pipelines::BadgesPipeline,
            stage: 1
          },
          boards: {
            pipeline: BulkImports::Common::Pipelines::BoardsPipeline,
            stage: 2
          },
          uploads: {
            pipeline: BulkImports::Common::Pipelines::UploadsPipeline,
            stage: 2
          },
          finisher: {
            pipeline: BulkImports::Common::Pipelines::EntityFinisher,
            stage: 3
          }
        }.merge(project_entities_pipeline)
      end

      def project_entities_pipeline
        if project_pipeline_available? && feature_flag_enabled?
          {
            project_entities: {
              pipeline: BulkImports::Groups::Pipelines::ProjectEntitiesPipeline,
              stage: 1
            }
          }
        else
          {}
        end
      end

      def project_pipeline_available?
        @bulk_import.source_version_info >= BulkImport.min_gl_version_for_project_migration
      end

      def feature_flag_enabled?
        destination_namespace = @bulk_import_entity.destination_namespace

        if destination_namespace.present?
          root_ancestor = Namespace.find_by_full_path(destination_namespace)&.root_ancestor

          ::Feature.enabled?(:bulk_import_projects, root_ancestor, default_enabled: :yaml)
        else
          ::Feature.enabled?(:bulk_import_projects, default_enabled: :yaml)
        end
      end
    end
  end
end

::BulkImports::Groups::Stage.prepend_mod_with('BulkImports::Groups::Stage')

# frozen_string_literal: true

module Projects
  module ImportExport
    class RelationExportUpload < ApplicationRecord
      include WithUploads
      include ObjectStorage::BackgroundMove

      self.table_name = 'project_relation_export_uploads'

      belongs_to :relation_export,
        class_name: 'Projects::ImportExport::RelationExport',
        foreign_key: :project_relation_export_id,
        inverse_of: :upload

      mount_uploader :export_file, ImportExportUploader
    end
  end
end

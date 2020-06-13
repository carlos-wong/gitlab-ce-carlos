# frozen_string_literal: true

module Gitlab
  module ImportExport
    module AfterExportStrategies
      class MoveFileStrategy < BaseAfterExportStrategy
        def initialize(archive_path:)
          @archive_path = archive_path
        end

        private

        def strategy_execute
          FileUtils.mv(project.export_file.path, @archive_path)
        end
      end
    end
  end
end

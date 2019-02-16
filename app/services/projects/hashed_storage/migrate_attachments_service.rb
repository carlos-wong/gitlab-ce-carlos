# frozen_string_literal: true

module Projects
  module HashedStorage
    AttachmentMigrationError = Class.new(StandardError)

    class MigrateAttachmentsService < BaseService
      attr_reader :logger, :old_disk_path, :new_disk_path

      def initialize(project, old_disk_path, logger: nil)
        @project = project
        @logger = logger || Rails.logger
        @old_disk_path = old_disk_path
        @new_disk_path = project.disk_path
        @skipped = false
      end

      def execute
        origin = FileUploader.absolute_base_dir(project)
        # It's possible that old_disk_path does not match project.disk_path. For example, that happens when we rename a project
        origin.sub!(/#{Regexp.escape(project.full_path)}\z/, old_disk_path)

        project.storage_version = ::Project::HASHED_STORAGE_FEATURES[:attachments]
        target = FileUploader.absolute_base_dir(project)

        result = move_folder!(origin, target)
        project.save!

        if result && block_given?
          yield
        end

        result
      end

      def skipped?
        @skipped
      end

      private

      def move_folder!(old_path, new_path)
        unless File.directory?(old_path)
          logger.info("Skipped attachments migration from '#{old_path}' to '#{new_path}', source path doesn't exist or is not a directory (PROJECT_ID=#{project.id})")
          @skipped = true
          return true
        end

        if File.exist?(new_path)
          logger.error("Cannot migrate attachments from '#{old_path}' to '#{new_path}', target path already exist (PROJECT_ID=#{project.id})")
          raise AttachmentMigrationError, "Target path '#{new_path}' already exist"
        end

        # Create hashed storage base path folder
        FileUtils.mkdir_p(File.dirname(new_path))

        FileUtils.mv(old_path, new_path)
        logger.info("Migrated project attachments from '#{old_path}' to '#{new_path}' (PROJECT_ID=#{project.id})")

        true
      end
    end
  end
end

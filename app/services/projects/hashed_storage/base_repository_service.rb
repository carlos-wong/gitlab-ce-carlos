# frozen_string_literal: true

module Projects
  module HashedStorage
    # Returned when there is an error with the Hashed Storage migration
    RepositoryMigrationError = Class.new(StandardError)

    # Returned when there is an error with the Hashed Storage rollback
    RepositoryRollbackError = Class.new(StandardError)

    class BaseRepositoryService < BaseService
      include Gitlab::ShellAdapter

      attr_reader :old_disk_path, :new_disk_path, :old_wiki_disk_path, :old_storage_version, :logger, :move_wiki

      def initialize(project, old_disk_path, logger: nil)
        @project = project
        @logger = logger || Gitlab::AppLogger
        @old_disk_path = old_disk_path
        @old_wiki_disk_path = "#{old_disk_path}.wiki"
        @move_wiki = has_wiki?
      end

      protected

      # rubocop: disable CodeReuse/ActiveRecord
      def has_wiki?
        gitlab_shell.exists?(project.repository_storage, "#{old_wiki_disk_path}.git")
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def move_repository(from_name, to_name)
        from_exists = gitlab_shell.exists?(project.repository_storage, "#{from_name}.git")
        to_exists = gitlab_shell.exists?(project.repository_storage, "#{to_name}.git")

        # If we don't find the repository on either original or target we should log that as it could be an issue if the
        # project was not originally empty.
        if !from_exists && !to_exists
          logger.warn "Can't find a repository on either source or target paths for #{project.full_path} (ID=#{project.id}) ..."
          return false
        elsif !from_exists
          # Repository have been moved already.
          return true
        end

        gitlab_shell.mv_repository(project.repository_storage, from_name, to_name)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def rollback_folder_move
        move_repository(new_disk_path, old_disk_path)
        move_repository("#{new_disk_path}.wiki", old_wiki_disk_path)
      end
    end
  end
end

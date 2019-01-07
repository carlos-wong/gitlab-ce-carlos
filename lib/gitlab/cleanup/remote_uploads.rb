# frozen_string_literal: true
module Gitlab
  module Cleanup
    class RemoteUploads
      attr_reader :logger

      BATCH_SIZE = 100

      def initialize(logger: nil)
        @logger = logger || Rails.logger
      end

      def run!(dry_run: false)
        unless configuration.enabled
          logger.warn "Object storage not enabled. Exit".color(:yellow)

          return
        end

        logger.info "Looking for orphaned remote uploads to remove#{'. Dry run' if dry_run}..."

        each_orphan_file do |file|
          info = if dry_run
                   "Can be moved to lost and found: #{file.key}"
                 else
                   new_path = move_to_lost_and_found(file)
                   "Moved to lost and found: #{file.key} -> #{new_path}"
                 end

          logger.info(info)
        end
      end

      private

      # rubocop: disable CodeReuse/ActiveRecord
      def each_orphan_file
        # we want to skip files already moved to lost_and_found directory
        lost_dir_match = "^#{lost_and_found_dir}\/"

        remote_directory.files.each_slice(BATCH_SIZE) do |remote_files|
          remote_files.reject! { |file| file.key.match(/#{lost_dir_match}/) }
          file_paths = remote_files.map(&:key)
          tracked_paths = Upload
            .where(store: ObjectStorage::Store::REMOTE, path: file_paths)
            .pluck(:path)

          remote_files.reject! { |file| tracked_paths.include?(file.key) }
          remote_files.each do |file|
            yield file
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def move_to_lost_and_found(file)
        new_path = "#{lost_and_found_dir}/#{file.key}"

        file.copy(configuration['remote_directory'], new_path)
        file.destroy

        new_path
      end

      def lost_and_found_dir
        'lost_and_found'
      end

      def remote_directory
        connection.directories.new(key: configuration['remote_directory'])
      end

      def connection
        ::Fog::Storage.new(configuration['connection'].symbolize_keys)
      end

      def configuration
        Gitlab.config.uploads.object_store
      end
    end
  end
end

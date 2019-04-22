# frozen_string_literal: true
require 'set'

namespace :gitlab do
  namespace :cleanup do
    desc "GitLab | Cleanup | Clean namespaces"
    task dirs: :gitlab_environment do
      namespaces = Set.new(Namespace.pluck(:path))
      namespaces << Storage::HashedProject::REPOSITORY_PATH_PREFIX

      Gitaly::Server.all.each do |server|
        all_dirs = Gitlab::GitalyClient::StorageService
          .new(server.storage)
          .list_directories(depth: 0)
          .reject { |dir| dir.ends_with?('.git') || namespaces.include?(File.basename(dir)) }

        puts "Looking for directories to remove... "
        all_dirs.each do |dir_path|
          if remove?
            begin
              Gitlab::GitalyClient::NamespaceService.new(server.storage)
                .remove(dir_path)

              puts "Removed...#{dir_path}"
            rescue StandardError => e
              puts "Cannot remove #{dir_path}: #{e.message}".color(:red)
            end
          else
            puts "Can be removed: #{dir_path}".color(:red)
          end
        end
      end

      unless remove?
        puts "To cleanup this directories run this command with REMOVE=true".color(:yellow)
      end
    end

    desc "GitLab | Cleanup | Clean repositories"
    task repos: :gitlab_environment do
      move_suffix = "+orphaned+#{Time.now.to_i}"

      Gitaly::Server.all.each do |server|
        Gitlab::GitalyClient::StorageService
          .new(server.storage)
          .list_directories
          .each do |path|
          repo_with_namespace = path.chomp('.git').chomp('.wiki')

          # TODO ignoring hashed repositories for now.  But revisit to fully support
          # possible orphaned hashed repos
          next if repo_with_namespace.start_with?(Storage::HashedProject::REPOSITORY_PATH_PREFIX)
          next if Project.find_by_full_path(repo_with_namespace)

          new_path = path + move_suffix
          puts path.inspect + ' -> ' + new_path.inspect

          begin
            Gitlab::GitalyClient::NamespaceService
              .new(server.storage)
              .rename(path, new_path)
          rescue StandardError => e
            puts "Error occurred while moving the repository: #{e.message}".color(:red)
          end
        end
      end
    end

    desc "GitLab | Cleanup | Block users that have been removed in LDAP"
    task block_removed_ldap_users: :gitlab_environment do
      warn_user_is_not_gitlab
      block_flag = ENV['BLOCK']

      User.find_each do |user|
        next unless user.ldap_user?

        print "#{user.name} (#{user.ldap_identity.extern_uid}) ..."

        if Gitlab::Auth::LDAP::Access.allowed?(user)
          puts " [OK]".color(:green)
        else
          if block_flag
            user.block! unless user.blocked?
            puts " [BLOCKED]".color(:red)
          else
            puts " [NOT IN LDAP]".color(:yellow)
          end
        end
      end

      unless block_flag
        puts "To block these users run this command with BLOCK=true".color(:yellow)
      end
    end

    desc "GitLab | Cleanup | Clean orphaned project uploads"
    task project_uploads: :gitlab_environment do
      warn_user_is_not_gitlab

      cleaner = Gitlab::Cleanup::ProjectUploads.new(logger: logger)
      cleaner.run!(dry_run: dry_run?)

      if dry_run?
        logger.info "To clean up these files run this command with DRY_RUN=false".color(:yellow)
      end
    end

    desc 'GitLab | Cleanup | Clean orphan remote upload files that do not exist in the db'
    task remote_upload_files: :environment do
      cleaner = Gitlab::Cleanup::RemoteUploads.new(logger: logger)
      cleaner.run!(dry_run: dry_run?)

      if dry_run?
        logger.info "To cleanup these files run this command with DRY_RUN=false".color(:yellow)
      end
    end

    def remove?
      ENV['REMOVE'] == 'true'
    end

    def dry_run?
      ENV['DRY_RUN'] != 'false'
    end

    def logger
      return @logger if defined?(@logger)

      @logger = if Rails.env.development? || Rails.env.production?
                  Logger.new(STDOUT).tap do |stdout_logger|
                    stdout_logger.extend(ActiveSupport::Logger.broadcast(Rails.logger))
                  end
                else
                  Rails.logger
                end
    end
  end
end

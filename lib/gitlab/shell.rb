# frozen_string_literal: true

# Gitaly note: SSH key operations are not part of Gitaly so will never be migrated.

require 'securerandom'

module Gitlab
  class Shell
    GITLAB_SHELL_ENV_VARS = %w(GIT_TERMINAL_PROMPT).freeze

    Error = Class.new(StandardError)

    class << self
      def secret_token
        @secret_token ||= begin
          File.read(Gitlab.config.gitlab_shell.secret_file).chomp
        end
      end

      def ensure_secret_token!
        return if File.exist?(File.join(Gitlab.config.gitlab_shell.path, '.gitlab_shell_secret'))

        generate_and_link_secret_token
      end

      def version_required
        @version_required ||= File.read(Rails.root
                                        .join('GITLAB_SHELL_VERSION')).strip
      end

      private

      # Create (if necessary) and link the secret token file
      def generate_and_link_secret_token
        secret_file = Gitlab.config.gitlab_shell.secret_file
        shell_path = Gitlab.config.gitlab_shell.path

        unless File.size?(secret_file)
          # Generate a new token of 16 random hexadecimal characters and store it in secret_file.
          @secret_token = SecureRandom.hex(16)
          File.write(secret_file, @secret_token)
        end

        link_path = File.join(shell_path, '.gitlab_shell_secret')
        if File.exist?(shell_path) && !File.exist?(link_path)
          FileUtils.symlink(secret_file, link_path)
        end
      end
    end

    # Convenience methods for initializing a new repository with a Project model.
    def create_project_repository(project)
      create_repository(project.repository_storage, project.disk_path, project.full_path)
    end

    def create_wiki_repository(project)
      create_repository(project.repository_storage, project.wiki.disk_path, project.wiki.full_path)
    end

    # Init new repository
    #
    # storage - the shard key
    # disk_path - project disk path
    # gl_project_path - project name
    #
    # Ex.
    #   create_repository("default", "path/to/gitlab-ci", "gitlab/gitlab-ci")
    #
    def create_repository(storage, disk_path, gl_project_path)
      relative_path = disk_path.dup
      relative_path << '.git' unless relative_path.end_with?('.git')

      # During creation of a repository, gl_repository may not be known
      # because that depends on a yet-to-be assigned project ID in the
      # database (e.g. project-1234), so for now it is blank.
      repository = Gitlab::Git::Repository.new(storage, relative_path, '', gl_project_path)
      wrapped_gitaly_errors { repository.gitaly_repository_client.create_repository }

      true
    rescue => err # Once the Rugged codes gets removes this can be improved
      Rails.logger.error("Failed to add repository #{storage}/#{disk_path}: #{err}")
      false
    end

    def import_wiki_repository(project, wiki_formatter)
      import_repository(project.repository_storage, wiki_formatter.disk_path, wiki_formatter.import_url, project.wiki.full_path)
    end

    def import_project_repository(project)
      import_repository(project.repository_storage, project.disk_path, project.import_url, project.full_path)
    end

    # Import repository
    #
    # storage - project's storage name
    # name - project disk path
    # url - URL to import from
    #
    # Ex.
    #   import_repository("nfs-file06", "gitlab/gitlab-ci", "https://gitlab.com/gitlab-org/gitlab-test.git")
    #
    def import_repository(storage, name, url, gl_project_path)
      if url.start_with?('.', '/')
        raise Error.new("don't use disk paths with import_repository: #{url.inspect}")
      end

      relative_path = "#{name}.git"
      cmd = GitalyGitlabProjects.new(storage, relative_path, gl_project_path)

      success = cmd.import_project(url, git_timeout)
      raise Error, cmd.output unless success

      success
    end

    # Move repository reroutes to mv_directory which is an alias for
    # mv_namespace. Given the underlying implementation is a move action,
    # indescriminate of what the folders might be.
    #
    # storage - project's storage path
    # path - project disk path
    # new_path - new project disk path
    #
    # Ex.
    #   mv_repository("/path/to/storage", "gitlab/gitlab-ci", "randx/gitlab-ci-new")
    def mv_repository(storage, path, new_path)
      return false if path.empty? || new_path.empty?

      !!mv_directory(storage, "#{path}.git", "#{new_path}.git")
    end

    # Fork repository to new path
    # source_project - forked-from Project
    # target_project - forked-to Project
    def fork_repository(source_project, target_project)
      forked_from_relative_path = "#{source_project.disk_path}.git"
      fork_args = [target_project.repository_storage, "#{target_project.disk_path}.git", target_project.full_path]

      GitalyGitlabProjects.new(source_project.repository_storage, forked_from_relative_path, source_project.full_path).fork_repository(*fork_args)
    end

    # Removes a repository from file system, using rm_diretory which is an alias
    # for rm_namespace. Given the underlying implementation removes the name
    # passed as second argument on the passed storage.
    #
    # storage - project's storage path
    # name - project disk path
    #
    # Ex.
    #   remove_repository("/path/to/storage", "gitlab/gitlab-ci")
    def remove_repository(storage, name)
      return false if name.empty?

      !!rm_directory(storage, "#{name}.git")
    rescue ArgumentError => e
      Rails.logger.warn("Repository does not exist: #{e} at: #{name}.git")
      false
    end

    # Add new key to authorized_keys
    #
    # Ex.
    #   add_key("key-42", "sha-rsa ...")
    #
    def add_key(key_id, key_content)
      return unless self.authorized_keys_enabled?

      if shell_out_for_gitlab_keys?
        gitlab_shell_fast_execute([
          gitlab_shell_keys_path,
          'add-key',
          key_id,
          strip_key(key_content)
        ])
      else
        gitlab_authorized_keys.add_key(key_id, key_content)
      end
    end

    # Batch-add keys to authorized_keys
    #
    # Ex.
    #   batch_add_keys(Key.all)
    def batch_add_keys(keys)
      return unless self.authorized_keys_enabled?

      if shell_out_for_gitlab_keys?
        begin
          IO.popen("#{gitlab_shell_keys_path} batch-add-keys", 'w') do |io|
            add_keys_to_io(keys, io)
          end

          $?.success?
        rescue Error
          false
        end
      else
        gitlab_authorized_keys.batch_add_keys(keys)
      end
    end

    # Remove ssh key from authorized_keys
    #
    # Ex.
    #   remove_key("key-342")
    #
    def remove_key(id, _ = nil)
      return unless self.authorized_keys_enabled?

      if shell_out_for_gitlab_keys?
        gitlab_shell_fast_execute([gitlab_shell_keys_path, 'rm-key', id])
      else
        gitlab_authorized_keys.rm_key(id)
      end
    end

    # Remove all ssh keys from gitlab shell
    #
    # Ex.
    #   remove_all_keys
    #
    def remove_all_keys
      return unless self.authorized_keys_enabled?

      if shell_out_for_gitlab_keys?
        gitlab_shell_fast_execute([gitlab_shell_keys_path, 'clear'])
      else
        gitlab_authorized_keys.clear
      end
    end

    # Remove ssh keys from gitlab shell that are not in the DB
    #
    # Ex.
    #   remove_keys_not_found_in_db
    #
    # rubocop: disable CodeReuse/ActiveRecord
    def remove_keys_not_found_in_db
      return unless self.authorized_keys_enabled?

      Rails.logger.info("Removing keys not found in DB")

      batch_read_key_ids do |ids_in_file|
        ids_in_file.uniq!
        keys_in_db = Key.where(id: ids_in_file)

        next unless ids_in_file.size > keys_in_db.count # optimization

        ids_to_remove = ids_in_file - keys_in_db.pluck(:id)
        ids_to_remove.each do |id|
          Rails.logger.info("Removing key-#{id} not found in DB")
          remove_key("key-#{id}")
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # Add empty directory for storing repositories
    #
    # Ex.
    #   add_namespace("default", "gitlab")
    #
    def add_namespace(storage, name)
      # https://gitlab.com/gitlab-org/gitlab-ce/issues/58012
      Gitlab::GitalyClient.allow_n_plus_1_calls do
        Gitlab::GitalyClient::NamespaceService.new(storage).add(name)
      end
    rescue GRPC::InvalidArgument => e
      raise ArgumentError, e.message
    end

    # Remove directory from repositories storage
    # Every repository inside this directory will be removed too
    #
    # Ex.
    #   rm_namespace("default", "gitlab")
    #
    def rm_namespace(storage, name)
      Gitlab::GitalyClient::NamespaceService.new(storage).remove(name)
    rescue GRPC::InvalidArgument => e
      raise ArgumentError, e.message
    end
    alias_method :rm_directory, :rm_namespace

    # Move namespace directory inside repositories storage
    #
    # Ex.
    #   mv_namespace("/path/to/storage", "gitlab", "gitlabhq")
    #
    def mv_namespace(storage, old_name, new_name)
      Gitlab::GitalyClient::NamespaceService.new(storage).rename(old_name, new_name)
    rescue GRPC::InvalidArgument => e
      Gitlab::Sentry.track_acceptable_exception(e, extra: { old_name: old_name, new_name: new_name, storage: storage })

      false
    end
    alias_method :mv_directory, :mv_namespace # Note: ShellWorker uses this alias

    def url_to_repo(path)
      Gitlab.config.gitlab_shell.ssh_path_prefix + "#{path}.git"
    end

    # Return GitLab shell version
    def version
      gitlab_shell_version_file = "#{gitlab_shell_path}/VERSION"

      if File.readable?(gitlab_shell_version_file)
        File.read(gitlab_shell_version_file).chomp
      end
    end

    # Check if such directory exists in repositories.
    #
    # Usage:
    #   exists?(storage, 'gitlab')
    #   exists?(storage, 'gitlab/cookies.git')
    #
    # rubocop: disable CodeReuse/ActiveRecord
    def exists?(storage, dir_name)
      Gitlab::GitalyClient::NamespaceService.new(storage).exists?(dir_name)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def hooks_path
      File.join(gitlab_shell_path, 'hooks')
    end

    protected

    def gitlab_shell_path
      File.expand_path(Gitlab.config.gitlab_shell.path)
    end

    def gitlab_shell_user_home
      File.expand_path("~#{Gitlab.config.gitlab_shell.ssh_user}")
    end

    def full_path(storage, dir_name)
      raise ArgumentError.new("Directory name can't be blank") if dir_name.blank?

      File.join(Gitlab.config.repositories.storages[storage].legacy_disk_path, dir_name)
    end

    def gitlab_shell_projects_path
      File.join(gitlab_shell_path, 'bin', 'gitlab-projects')
    end

    def gitlab_shell_keys_path
      File.join(gitlab_shell_path, 'bin', 'gitlab-keys')
    end

    def authorized_keys_enabled?
      # Return true if nil to ensure the authorized_keys methods work while
      # fixing the authorized_keys file during migration.
      return true if Gitlab::CurrentSettings.current_application_settings.authorized_keys_enabled.nil?

      Gitlab::CurrentSettings.current_application_settings.authorized_keys_enabled
    end

    private

    def shell_out_for_gitlab_keys?
      Gitlab.config.gitlab_shell.authorized_keys_file.blank?
    end

    def gitlab_shell_fast_execute(cmd)
      output, status = gitlab_shell_fast_execute_helper(cmd)

      return true if status.zero?

      Rails.logger.error("gitlab-shell failed with error #{status}: #{output}")
      false
    end

    def gitlab_shell_fast_execute_raise_error(cmd, vars = {})
      output, status = gitlab_shell_fast_execute_helper(cmd, vars)

      raise Error, output unless status.zero?

      true
    end

    def gitlab_shell_fast_execute_helper(cmd, vars = {})
      vars.merge!(ENV.to_h.slice(*GITLAB_SHELL_ENV_VARS))

      # Don't pass along the entire parent environment to prevent gitlab-shell
      # from wasting I/O by searching through GEM_PATH
      Bundler.with_original_env { Popen.popen(cmd, nil, vars) }
    end

    def git_timeout
      Gitlab.config.gitlab_shell.git_timeout
    end

    def wrapped_gitaly_errors
      yield
    rescue GRPC::NotFound, GRPC::BadStatus => e
      # Old Popen code returns [Error, output] to the caller, so we
      # need to do the same here...
      raise Error, e
    end

    def gitlab_authorized_keys
      @gitlab_authorized_keys ||= Gitlab::AuthorizedKeys.new
    end

    def batch_read_key_ids(batch_size: 100, &block)
      return unless self.authorized_keys_enabled?

      if shell_out_for_gitlab_keys?
        IO.popen("#{gitlab_shell_keys_path} list-key-ids") do |key_id_stream|
          key_id_stream.lazy.each_slice(batch_size) do |lines|
            yield(lines.map { |l| l.chomp.to_i })
          end
        end
      else
        gitlab_authorized_keys.list_key_ids.lazy.each_slice(batch_size) do |key_ids|
          yield(key_ids)
        end
      end
    end

    def strip_key(key)
      key.split(/[ ]+/)[0, 2].join(' ')
    end

    def add_keys_to_io(keys, io)
      keys.each do |k|
        key = strip_key(k.key)

        raise Error.new("Invalid key: #{key.inspect}") if key.include?("\t") || key.include?("\n")

        io.puts("#{k.shell_id}\t#{key}")
      end
    end

    class GitalyGitlabProjects
      attr_reader :shard_name, :repository_relative_path, :output, :gl_project_path

      def initialize(shard_name, repository_relative_path, gl_project_path)
        @shard_name = shard_name
        @repository_relative_path = repository_relative_path
        @output = ''
        @gl_project_path = gl_project_path
      end

      def import_project(source, _timeout)
        raw_repository = Gitlab::Git::Repository.new(shard_name, repository_relative_path, nil, gl_project_path)

        Gitlab::GitalyClient::RepositoryService.new(raw_repository).import_repository(source)
        true
      rescue GRPC::BadStatus => e
        @output = e.message
        false
      end

      def fork_repository(new_shard_name, new_repository_relative_path, new_project_name)
        target_repository = Gitlab::Git::Repository.new(new_shard_name, new_repository_relative_path, nil, new_project_name)
        raw_repository = Gitlab::Git::Repository.new(shard_name, repository_relative_path, nil, gl_project_path)

        Gitlab::GitalyClient::RepositoryService.new(target_repository).fork_repository(raw_repository)
      rescue GRPC::BadStatus => e
        logger.error "fork-repository failed: #{e.message}"
        false
      end

      def logger
        Rails.logger
      end
    end
  end
end

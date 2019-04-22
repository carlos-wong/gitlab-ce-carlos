require 'spec_helper'
require 'rake'

describe 'gitlab:app namespace rake task' do
  let(:enable_registry) { true }

  def tars_glob
    Dir.glob(File.join(Gitlab.config.backup.path, '*_gitlab_backup.tar'))
  end

  def backup_tar
    tars_glob.first
  end

  before(:all) do
    Rake.application.rake_require 'tasks/gitlab/helpers'
    Rake.application.rake_require 'tasks/gitlab/backup'
    Rake.application.rake_require 'tasks/gitlab/shell'
    Rake.application.rake_require 'tasks/gitlab/db'
    Rake.application.rake_require 'tasks/cache'

    # empty task as env is already loaded
    Rake::Task.define_task :environment
  end

  before do
    stub_env('force', 'yes')
    FileUtils.rm(tars_glob, force: true)
    reenable_backup_sub_tasks
    stub_container_registry_config(enabled: enable_registry)
  end

  after do
    FileUtils.rm(tars_glob, force: true)
  end

  def run_rake_task(task_name)
    FileUtils.mkdir_p('tmp/tests/public/uploads')
    Rake::Task[task_name].reenable
    Rake.application.invoke_task task_name
  end

  def reenable_backup_sub_tasks
    %w{db repo uploads builds artifacts pages lfs registry}.each do |subtask|
      Rake::Task["gitlab:backup:#{subtask}:create"].reenable
    end
  end

  describe 'backup_restore' do
    context 'gitlab version' do
      before do
        allow(Dir).to receive(:glob).and_return(['1_gitlab_backup.tar'])
        allow(File).to receive(:exist?).and_return(true)
        allow(Kernel).to receive(:system).and_return(true)
        allow(FileUtils).to receive(:cp_r).and_return(true)
        allow(FileUtils).to receive(:mv).and_return(true)
        allow(Rake::Task["gitlab:shell:setup"])
          .to receive(:invoke).and_return(true)
      end

      let(:gitlab_version) { Gitlab::VERSION }

      it 'fails on mismatch' do
        allow(YAML).to receive(:load_file)
          .and_return({ gitlab_version: "not #{gitlab_version}" })

        expect do
          expect { run_rake_task('gitlab:backup:restore') }.to output.to_stdout
        end.to raise_error(SystemExit)
      end

      context 'restore with matching gitlab version' do
        before do
          allow(YAML).to receive(:load_file)
            .and_return({ gitlab_version: gitlab_version })
          expect(Rake::Task['gitlab:db:drop_tables']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:db:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:repo:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:builds:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:uploads:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:artifacts:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:pages:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:lfs:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:backup:registry:restore']).to receive(:invoke)
          expect(Rake::Task['gitlab:shell:setup']).to receive(:invoke)
        end

        it 'invokes restoration on match' do
          expect { run_rake_task('gitlab:backup:restore') }.to output.to_stdout
        end

        it 'prints timestamps on messages' do
          expect { run_rake_task('gitlab:backup:restore') }.to output(/.*\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s[-+]\d{4}\s--\s.*/).to_stdout
        end
      end
    end

    context 'when the restore directory is not empty' do
      before do
        # We only need a backup of the repositories for this test
        stub_env('SKIP', 'db,uploads,builds,artifacts,lfs,registry')
      end

      it 'removes stale data' do
        expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

        excluded_project = create(:project, :repository, name: 'mepmep')

        expect { run_rake_task('gitlab:backup:restore') }.to output.to_stdout

        raw_repo = excluded_project.repository.raw

        # The restore will not find the repository in the backup, but will create
        # an empty one in its place
        expect(raw_repo.empty?).to be(true)
      end
    end
  end # backup_restore task

  describe 'backup' do
    before do
      # This reconnect makes our project fixture disappear, breaking the restore. Stub it out.
      allow(ActiveRecord::Base.connection).to receive(:reconnect!)
    end

    describe 'backup creation and deletion using custom_hooks' do
      let(:project) { create(:project, :repository) }
      let(:user_backup_path) { "repositories/#{project.disk_path}" }

      before do
        stub_env('SKIP', 'db')
        path = Gitlab::GitalyClient::StorageSettings.allow_disk_access do
          File.join(project.repository.path_to_repo, 'custom_hooks')
        end
        FileUtils.mkdir_p(path)
        FileUtils.touch(File.join(path, "dummy.txt"))
      end

      context 'project uses custom_hooks and successfully creates backup' do
        it 'creates custom_hooks.tar and project bundle' do
          expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

          tar_contents, exit_status = Gitlab::Popen.popen(%W{tar -tvf #{backup_tar}})

          expect(exit_status).to eq(0)
          expect(tar_contents).to match(user_backup_path)
          expect(tar_contents).to match("#{user_backup_path}/custom_hooks.tar")
          expect(tar_contents).to match("#{user_backup_path}.bundle")
        end

        it 'restores files correctly' do
          expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout
          expect { run_rake_task('gitlab:backup:restore') }.to output.to_stdout

          repo_path = Gitlab::GitalyClient::StorageSettings.allow_disk_access do
            project.repository.path
          end
          expect(Dir.entries(File.join(repo_path, 'custom_hooks'))).to include("dummy.txt")
        end
      end

      context 'specific backup tasks' do
        let(:task_list) { %w(db repo uploads builds artifacts pages lfs registry) }

        it 'prints a progress message to stdout' do
          task_list.each do |task|
            expect { run_rake_task("gitlab:backup:#{task}:create") }.to output(/Dumping /).to_stdout
          end
        end
      end
    end

    context 'tar creation' do
      context 'archive file permissions' do
        it 'sets correct permissions on the tar file' do
          expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

          expect(File.exist?(backup_tar)).to be_truthy
          expect(File::Stat.new(backup_tar).mode.to_s(8)).to eq('100600')
        end

        context 'with custom archive_permissions' do
          before do
            allow(Gitlab.config.backup).to receive(:archive_permissions).and_return(0651)
          end

          it 'uses the custom permissions' do
            expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

            expect(File::Stat.new(backup_tar).mode.to_s(8)).to eq('100651')
          end
        end
      end

      it 'sets correct permissions on the tar contents' do
        expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

        tar_contents, exit_status = Gitlab::Popen.popen(
          %W{tar -tvf #{backup_tar} db uploads.tar.gz repositories builds.tar.gz artifacts.tar.gz pages.tar.gz lfs.tar.gz registry.tar.gz}
        )

        expect(exit_status).to eq(0)
        expect(tar_contents).to match('db/')
        expect(tar_contents).to match('uploads.tar.gz')
        expect(tar_contents).to match('repositories/')
        expect(tar_contents).to match('builds.tar.gz')
        expect(tar_contents).to match('artifacts.tar.gz')
        expect(tar_contents).to match('pages.tar.gz')
        expect(tar_contents).to match('lfs.tar.gz')
        expect(tar_contents).to match('registry.tar.gz')
        expect(tar_contents).not_to match(%r{^.{4,9}[rwx].* (database.sql.gz|uploads.tar.gz|repositories|builds.tar.gz|pages.tar.gz|artifacts.tar.gz|registry.tar.gz)/$})
      end

      it 'deletes temp directories' do
        expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

        temp_dirs = Dir.glob(
          File.join(Gitlab.config.backup.path, '{db,repositories,uploads,builds,artifacts,pages,lfs,registry}')
        )

        expect(temp_dirs).to be_empty
      end

      context 'registry disabled' do
        let(:enable_registry) { false }

        it 'does not create registry.tar.gz' do
          expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

          tar_contents, exit_status = Gitlab::Popen.popen(
            %W{tar -tvf #{backup_tar}}
          )

          expect(exit_status).to eq(0)
          expect(tar_contents).not_to match('registry.tar.gz')
        end
      end
    end

    context 'multiple repository storages' do
      let(:test_second_storage) do
        Gitlab::GitalyClient::StorageSettings.new(@default_storage_hash.merge('path' => 'tmp/tests/custom_storage'))
      end
      let(:storages) do
        {
          'default' => Gitlab.config.repositories.storages.default,
          'test_second_storage' => test_second_storage
        }
      end

      before(:all) do
        @default_storage_hash = Gitlab.config.repositories.storages.default.to_h
      end

      before do
        # We only need a backup of the repositories for this test
        stub_env('SKIP', 'db,uploads,builds,artifacts,lfs,registry')

        allow(Gitlab.config.repositories).to receive(:storages).and_return(storages)

        # Avoid asking gitaly about the root ref (which will fail because of the
        # mocked storages)
        allow_any_instance_of(Repository).to receive(:empty?).and_return(false)
      end

      after do
        FileUtils.rm_rf(Settings.absolute('tmp/tests/custom_storage'))
      end

      it 'includes repositories in all repository storages' do
        project_a = create(:project, :repository)
        project_b = create(:project, :repository, repository_storage: 'test_second_storage')

        b_storage_dir = File.join(Settings.absolute('tmp/tests/custom_storage'), File.dirname(project_b.disk_path))

        FileUtils.mkdir_p(b_storage_dir)

        # Even when overriding the storage, we have to move it there, so it exists
        Gitlab::GitalyClient::StorageSettings.allow_disk_access do
          FileUtils.mv(
            File.join(Settings.absolute(storages['default'].legacy_disk_path), project_b.repository.disk_path + '.git'),
            Rails.root.join(storages['test_second_storage'].legacy_disk_path, project_b.repository.disk_path + '.git')
          )
        end

        expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

        tar_contents, exit_status = Gitlab::Popen.popen(
          %W{tar -tvf #{backup_tar} repositories}
        )

        expect(exit_status).to eq(0)
        expect(tar_contents).to match("repositories/#{project_a.disk_path}.bundle")
        expect(tar_contents).to match("repositories/#{project_b.disk_path}.bundle")
      end
    end
  end # backup_create task

  describe "Skipping items" do
    before do
      stub_env('SKIP', 'repositories,uploads')
    end

    it "does not contain skipped item" do
      expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

      tar_contents, _exit_status = Gitlab::Popen.popen(
        %W{tar -tvf #{backup_tar} db uploads.tar.gz repositories builds.tar.gz artifacts.tar.gz pages.tar.gz lfs.tar.gz registry.tar.gz}
      )

      expect(tar_contents).to match('db/')
      expect(tar_contents).to match('uploads.tar.gz')
      expect(tar_contents).to match('builds.tar.gz')
      expect(tar_contents).to match('artifacts.tar.gz')
      expect(tar_contents).to match('lfs.tar.gz')
      expect(tar_contents).to match('pages.tar.gz')
      expect(tar_contents).to match('registry.tar.gz')
      expect(tar_contents).not_to match('repositories/')
    end

    it 'does not invoke repositories restore' do
      expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

      allow(Rake::Task['gitlab:shell:setup'])
        .to receive(:invoke).and_return(true)

      expect(Rake::Task['gitlab:db:drop_tables']).to receive :invoke
      expect(Rake::Task['gitlab:backup:db:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:repo:restore']).not_to receive :invoke
      expect(Rake::Task['gitlab:backup:uploads:restore']).not_to receive :invoke
      expect(Rake::Task['gitlab:backup:builds:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:artifacts:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:pages:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:lfs:restore']).to receive :invoke
      expect(Rake::Task['gitlab:backup:registry:restore']).to receive :invoke
      expect(Rake::Task['gitlab:shell:setup']).to receive :invoke
      expect { run_rake_task('gitlab:backup:restore') }.to output.to_stdout
    end
  end

  describe "Human Readable Backup Name" do
    it 'name has human readable time' do
      expect { run_rake_task('gitlab:backup:create') }.to output.to_stdout

      expect(backup_tar).to match(/\d+_\d{4}_\d{2}_\d{2}_\d+\.\d+\.\d+.*_gitlab_backup.tar$/)
    end
  end
end # gitlab:app namespace

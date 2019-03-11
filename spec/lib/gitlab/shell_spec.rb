require 'spec_helper'
require 'stringio'

describe Gitlab::Shell do
  set(:project) { create(:project, :repository) }

  let(:repository) { project.repository }
  let(:gitlab_shell) { described_class.new }
  let(:popen_vars) { { 'GIT_TERMINAL_PROMPT' => ENV['GIT_TERMINAL_PROMPT'] } }
  let(:timeout) { Gitlab.config.gitlab_shell.git_timeout }

  before do
    allow(Project).to receive(:find).and_return(project)
  end

  it { is_expected.to respond_to :add_key }
  it { is_expected.to respond_to :remove_key }
  it { is_expected.to respond_to :create_repository }
  it { is_expected.to respond_to :remove_repository }
  it { is_expected.to respond_to :fork_repository }

  it { expect(gitlab_shell.url_to_repo('diaspora')).to eq(Gitlab.config.gitlab_shell.ssh_path_prefix + "diaspora.git") }

  describe 'memoized secret_token' do
    let(:secret_file) { 'tmp/tests/.secret_shell_test' }
    let(:link_file) { 'tmp/tests/shell-secret-test/.gitlab_shell_secret' }

    before do
      allow(Gitlab.config.gitlab_shell).to receive(:secret_file).and_return(secret_file)
      allow(Gitlab.config.gitlab_shell).to receive(:path).and_return('tmp/tests/shell-secret-test')
      FileUtils.mkdir('tmp/tests/shell-secret-test')
      described_class.ensure_secret_token!
    end

    after do
      FileUtils.rm_rf('tmp/tests/shell-secret-test')
      FileUtils.rm_rf(secret_file)
    end

    it 'creates and links the secret token file' do
      secret_token = described_class.secret_token

      expect(File.exist?(secret_file)).to be(true)
      expect(File.read(secret_file).chomp).to eq(secret_token)
      expect(File.symlink?(link_file)).to be(true)
      expect(File.readlink(link_file)).to eq(secret_file)
    end
  end

  describe '#add_key' do
    context 'when authorized_keys_enabled is true' do
      it 'removes trailing garbage' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
          [:gitlab_shell_keys_path, 'add-key', 'key-123', 'ssh-rsa foobar']
        )

        gitlab_shell.add_key('key-123', 'ssh-rsa foobar trailing garbage')
      end
    end

    context 'when authorized_keys_enabled is false' do
      before do
        stub_application_setting(authorized_keys_enabled: false)
      end

      it 'does nothing' do
        expect(gitlab_shell).not_to receive(:gitlab_shell_fast_execute)

        gitlab_shell.add_key('key-123', 'ssh-rsa foobar trailing garbage')
      end
    end

    context 'when authorized_keys_enabled is nil' do
      before do
        stub_application_setting(authorized_keys_enabled: nil)
      end

      it 'removes trailing garbage' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
          [:gitlab_shell_keys_path, 'add-key', 'key-123', 'ssh-rsa foobar']
        )

        gitlab_shell.add_key('key-123', 'ssh-rsa foobar trailing garbage')
      end
    end
  end

  describe '#batch_add_keys' do
    context 'when authorized_keys_enabled is true' do
      it 'instantiates KeyAdder' do
        expect_any_instance_of(Gitlab::Shell::KeyAdder).to receive(:add_key).with('key-123', 'ssh-rsa foobar')

        gitlab_shell.batch_add_keys do |adder|
          adder.add_key('key-123', 'ssh-rsa foobar')
        end
      end
    end

    context 'when authorized_keys_enabled is false' do
      before do
        stub_application_setting(authorized_keys_enabled: false)
      end

      it 'does nothing' do
        expect_any_instance_of(Gitlab::Shell::KeyAdder).not_to receive(:add_key)

        gitlab_shell.batch_add_keys do |adder|
          adder.add_key('key-123', 'ssh-rsa foobar')
        end
      end
    end

    context 'when authorized_keys_enabled is nil' do
      before do
        stub_application_setting(authorized_keys_enabled: nil)
      end

      it 'instantiates KeyAdder' do
        expect_any_instance_of(Gitlab::Shell::KeyAdder).to receive(:add_key).with('key-123', 'ssh-rsa foobar')

        gitlab_shell.batch_add_keys do |adder|
          adder.add_key('key-123', 'ssh-rsa foobar')
        end
      end
    end
  end

  describe '#remove_key' do
    context 'when authorized_keys_enabled is true' do
      it 'removes trailing garbage' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
          [:gitlab_shell_keys_path, 'rm-key', 'key-123', 'ssh-rsa foobar']
        )

        gitlab_shell.remove_key('key-123', 'ssh-rsa foobar')
      end
    end

    context 'when authorized_keys_enabled is false' do
      before do
        stub_application_setting(authorized_keys_enabled: false)
      end

      it 'does nothing' do
        expect(gitlab_shell).not_to receive(:gitlab_shell_fast_execute)

        gitlab_shell.remove_key('key-123', 'ssh-rsa foobar')
      end
    end

    context 'when authorized_keys_enabled is nil' do
      before do
        stub_application_setting(authorized_keys_enabled: nil)
      end

      it 'removes trailing garbage' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
          [:gitlab_shell_keys_path, 'rm-key', 'key-123', 'ssh-rsa foobar']
        )

        gitlab_shell.remove_key('key-123', 'ssh-rsa foobar')
      end
    end

    context 'when key content is not given' do
      it 'calls rm-key with only one argument' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
          [:gitlab_shell_keys_path, 'rm-key', 'key-123']
        )

        gitlab_shell.remove_key('key-123')
      end
    end
  end

  describe '#remove_all_keys' do
    context 'when authorized_keys_enabled is true' do
      it 'removes trailing garbage' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with([:gitlab_shell_keys_path, 'clear'])

        gitlab_shell.remove_all_keys
      end
    end

    context 'when authorized_keys_enabled is false' do
      before do
        stub_application_setting(authorized_keys_enabled: false)
      end

      it 'does nothing' do
        expect(gitlab_shell).not_to receive(:gitlab_shell_fast_execute)

        gitlab_shell.remove_all_keys
      end
    end

    context 'when authorized_keys_enabled is nil' do
      before do
        stub_application_setting(authorized_keys_enabled: nil)
      end

      it 'removes trailing garbage' do
        allow(gitlab_shell).to receive(:gitlab_shell_keys_path).and_return(:gitlab_shell_keys_path)
        expect(gitlab_shell).to receive(:gitlab_shell_fast_execute).with(
          [:gitlab_shell_keys_path, 'clear']
        )

        gitlab_shell.remove_all_keys
      end
    end
  end

  describe '#remove_keys_not_found_in_db' do
    context 'when keys are in the file that are not in the DB' do
      before do
        gitlab_shell.remove_all_keys
        gitlab_shell.add_key('key-1234', 'ssh-rsa ASDFASDF')
        gitlab_shell.add_key('key-9876', 'ssh-rsa ASDFASDF')
        @another_key = create(:key) # this one IS in the DB
      end

      it 'removes the keys' do
        expect(find_in_authorized_keys_file(1234)).to be_truthy
        expect(find_in_authorized_keys_file(9876)).to be_truthy
        expect(find_in_authorized_keys_file(@another_key.id)).to be_truthy
        gitlab_shell.remove_keys_not_found_in_db
        expect(find_in_authorized_keys_file(1234)).to be_falsey
        expect(find_in_authorized_keys_file(9876)).to be_falsey
        expect(find_in_authorized_keys_file(@another_key.id)).to be_truthy
      end
    end

    context 'when keys there are duplicate keys in the file that are not in the DB' do
      before do
        gitlab_shell.remove_all_keys
        gitlab_shell.add_key('key-1234', 'ssh-rsa ASDFASDF')
        gitlab_shell.add_key('key-1234', 'ssh-rsa ASDFASDF')
      end

      it 'removes the keys' do
        expect(find_in_authorized_keys_file(1234)).to be_truthy
        gitlab_shell.remove_keys_not_found_in_db
        expect(find_in_authorized_keys_file(1234)).to be_falsey
      end

      it 'does not run remove more than once per key (in a batch)' do
        expect(gitlab_shell).to receive(:remove_key).with('key-1234').once
        gitlab_shell.remove_keys_not_found_in_db
      end
    end

    context 'when keys there are duplicate keys in the file that ARE in the DB' do
      before do
        gitlab_shell.remove_all_keys
        @key = create(:key)
        gitlab_shell.add_key(@key.shell_id, @key.key)
      end

      it 'does not remove the key' do
        gitlab_shell.remove_keys_not_found_in_db
        expect(find_in_authorized_keys_file(@key.id)).to be_truthy
      end

      it 'does not need to run a SELECT query for that batch, on account of that key' do
        expect_any_instance_of(ActiveRecord::Relation).not_to receive(:pluck)
        gitlab_shell.remove_keys_not_found_in_db
      end
    end

    unless ENV['CI'] # Skip in CI, it takes 1 minute
      context 'when the first batch can be skipped, but the next batch has keys that are not in the DB' do
        before do
          gitlab_shell.remove_all_keys
          100.times { |i| create(:key) } # first batch is all in the DB
          gitlab_shell.add_key('key-1234', 'ssh-rsa ASDFASDF')
        end

        it 'removes the keys not in the DB' do
          expect(find_in_authorized_keys_file(1234)).to be_truthy
          gitlab_shell.remove_keys_not_found_in_db
          expect(find_in_authorized_keys_file(1234)).to be_falsey
        end
      end
    end
  end

  describe '#batch_read_key_ids' do
    context 'when there are keys in the authorized_keys file' do
      before do
        gitlab_shell.remove_all_keys
        (1..4).each do |i|
          gitlab_shell.add_key("key-#{i}", "ssh-rsa ASDFASDF#{i}")
        end
      end

      it 'iterates over the key IDs in the file, in batches' do
        loop_count = 0
        first_batch = [1, 2]
        second_batch = [3, 4]

        gitlab_shell.batch_read_key_ids(batch_size: 2) do |batch|
          expected = (loop_count == 0 ? first_batch : second_batch)
          expect(batch).to eq(expected)
          loop_count += 1
        end
      end
    end
  end

  describe '#list_key_ids' do
    context 'when there are keys in the authorized_keys file' do
      before do
        gitlab_shell.remove_all_keys
        (1..4).each do |i|
          gitlab_shell.add_key("key-#{i}", "ssh-rsa ASDFASDF#{i}")
        end
      end

      it 'outputs the key IDs in the file, separated by newlines' do
        ids = []
        gitlab_shell.list_key_ids do |io|
          io.each do |line|
            ids << line
          end
        end

        expect(ids).to eq(%W{1\n 2\n 3\n 4\n})
      end
    end

    context 'when there are no keys in the authorized_keys file' do
      before do
        gitlab_shell.remove_all_keys
      end

      it 'outputs nothing, not even an empty string' do
        ids = []
        gitlab_shell.list_key_ids do |io|
          io.each do |line|
            ids << line
          end
        end

        expect(ids).to eq([])
      end
    end
  end

  describe Gitlab::Shell::KeyAdder do
    describe '#add_key' do
      it 'removes trailing garbage' do
        io = spy(:io)
        adder = described_class.new(io)

        adder.add_key('key-42', "ssh-rsa foo bar\tbaz")

        expect(io).to have_received(:puts).with("key-42\tssh-rsa foo")
      end

      it 'handles multiple spaces in the key' do
        io = spy(:io)
        adder = described_class.new(io)

        adder.add_key('key-42', "ssh-rsa  foo")

        expect(io).to have_received(:puts).with("key-42\tssh-rsa foo")
      end

      it 'raises an exception if the key contains a tab' do
        expect do
          described_class.new(StringIO.new).add_key('key-42', "ssh-rsa\tfoobar")
        end.to raise_error(Gitlab::Shell::Error)
      end

      it 'raises an exception if the key contains a newline' do
        expect do
          described_class.new(StringIO.new).add_key('key-42', "ssh-rsa foobar\nssh-rsa pawned")
        end.to raise_error(Gitlab::Shell::Error)
      end
    end
  end

  describe 'projects commands' do
    let(:gitlab_shell_path) { File.expand_path('tmp/tests/gitlab-shell') }
    let(:projects_path) { File.join(gitlab_shell_path, 'bin/gitlab-projects') }
    let(:gitlab_shell_hooks_path) { File.join(gitlab_shell_path, 'hooks') }

    before do
      allow(Gitlab.config.gitlab_shell).to receive(:path).and_return(gitlab_shell_path)
      allow(Gitlab.config.gitlab_shell).to receive(:git_timeout).and_return(800)
    end

    describe '#create_repository' do
      let(:repository_storage) { 'default' }
      let(:repository_storage_path) do
        Gitlab::GitalyClient::StorageSettings.allow_disk_access do
          Gitlab.config.repositories.storages[repository_storage].legacy_disk_path
        end
      end
      let(:repo_name) { 'project/path' }
      let(:created_path) { File.join(repository_storage_path, repo_name + '.git') }

      after do
        FileUtils.rm_rf(created_path)
      end

      it 'creates a repository' do
        expect(gitlab_shell.create_repository(repository_storage, repo_name, repo_name)).to be_truthy

        expect(File.stat(created_path).mode & 0o777).to eq(0o770)

        hooks_path = File.join(created_path, 'hooks')
        expect(File.lstat(hooks_path)).to be_symlink
        expect(File.realpath(hooks_path)).to eq(gitlab_shell_hooks_path)
      end

      it 'returns false when the command fails' do
        FileUtils.mkdir_p(File.dirname(created_path))
        # This file will block the creation of the repo's .git directory. That
        # should cause #create_repository to fail.
        FileUtils.touch(created_path)

        expect(gitlab_shell.create_repository(repository_storage, repo_name, repo_name)).to be_falsy
      end
    end

    describe '#remove_repository' do
      let!(:project) { create(:project, :repository, :legacy_storage) }
      let(:disk_path) { "#{project.disk_path}.git" }

      it 'returns true when the command succeeds' do
        expect(gitlab_shell.exists?(project.repository_storage, disk_path)).to be(true)

        expect(gitlab_shell.remove_repository(project.repository_storage, project.disk_path)).to be(true)

        expect(gitlab_shell.exists?(project.repository_storage, disk_path)).to be(false)
      end

      it 'keeps the namespace directory' do
        gitlab_shell.remove_repository(project.repository_storage, project.disk_path)

        expect(gitlab_shell.exists?(project.repository_storage, disk_path)).to be(false)
        expect(gitlab_shell.exists?(project.repository_storage, project.disk_path.gsub(project.name, ''))).to be(true)
      end
    end

    describe '#mv_repository' do
      let!(:project2) { create(:project, :repository) }

      it 'returns true when the command succeeds' do
        old_path = project2.disk_path
        new_path = "project/new_path"

        expect(gitlab_shell.exists?(project2.repository_storage, "#{old_path}.git")).to be(true)
        expect(gitlab_shell.exists?(project2.repository_storage, "#{new_path}.git")).to be(false)

        expect(gitlab_shell.mv_repository(project2.repository_storage, old_path, new_path)).to be_truthy

        expect(gitlab_shell.exists?(project2.repository_storage, "#{old_path}.git")).to be(false)
        expect(gitlab_shell.exists?(project2.repository_storage, "#{new_path}.git")).to be(true)
      end

      it 'returns false when the command fails' do
        expect(gitlab_shell.mv_repository(project2.repository_storage, project2.disk_path, '')).to be_falsy
        expect(gitlab_shell.exists?(project2.repository_storage, "#{project2.disk_path}.git")).to be(true)
      end
    end

    describe '#fork_repository' do
      let(:target_project) { create(:project) }

      subject do
        gitlab_shell.fork_repository(project, target_project)
      end

      it 'returns true when the command succeeds' do
        expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:fork_repository)
          .with(repository.raw_repository) { :gitaly_response_object }

        is_expected.to be_truthy
      end

      it 'return false when the command fails' do
        expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:fork_repository)
          .with(repository.raw_repository) { raise GRPC::BadStatus, 'bla' }

        is_expected.to be_falsy
      end
    end

    describe '#import_repository' do
      let(:import_url) { 'https://gitlab.com/gitlab-org/gitlab-ce.git' }

      context 'with gitaly' do
        it 'returns true when the command succeeds' do
          expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:import_repository).with(import_url)

          result = gitlab_shell.import_repository(project.repository_storage, project.disk_path, import_url, project.full_path)

          expect(result).to be_truthy
        end

        it 'raises an exception when the command fails' do
          expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:import_repository)
            .with(import_url) { raise GRPC::BadStatus, 'bla' }
          expect_any_instance_of(Gitlab::Shell::GitalyGitlabProjects).to receive(:output) { 'error'}

          expect do
            gitlab_shell.import_repository(project.repository_storage, project.disk_path, import_url, project.full_path)
          end.to raise_error(Gitlab::Shell::Error, "error")
        end
      end
    end
  end

  describe 'namespace actions' do
    subject { described_class.new }
    let(:storage) { Gitlab.config.repositories.storages.keys.first }

    describe '#add_namespace' do
      it 'creates a namespace' do
        subject.add_namespace(storage, "mepmep")

        expect(subject.exists?(storage, "mepmep")).to be(true)
      end
    end

    describe '#exists?' do
      context 'when the namespace does not exist' do
        it 'returns false' do
          expect(subject.exists?(storage, "non-existing")).to be(false)
        end
      end

      context 'when the namespace exists' do
        it 'returns true' do
          subject.add_namespace(storage, "mepmep")

          expect(subject.exists?(storage, "mepmep")).to be(true)
        end
      end
    end

    describe '#remove' do
      it 'removes the namespace' do
        subject.add_namespace(storage, "mepmep")
        subject.rm_namespace(storage, "mepmep")

        expect(subject.exists?(storage, "mepmep")).to be(false)
      end
    end

    describe '#mv_namespace' do
      it 'renames the namespace' do
        subject.add_namespace(storage, "mepmep")
        subject.mv_namespace(storage, "mepmep", "2mep")

        expect(subject.exists?(storage, "mepmep")).to be(false)
        expect(subject.exists?(storage, "2mep")).to be(true)
      end
    end
  end

  def find_in_authorized_keys_file(key_id)
    gitlab_shell.batch_read_key_ids do |ids|
      return true if ids.include?(key_id) # rubocop:disable Cop/AvoidReturnFromBlocks
    end

    false
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'carrierwave/storage/fog'

class Implementation < GitlabUploader
  include ObjectStorage::Concern
  include ::RecordsUploads::Concern
  prepend ::ObjectStorage::Extension::RecordsUploads

  storage_options Gitlab.config.uploads

  private

  # user/:id
  def dynamic_segment
    File.join(model.class.underscore, model.id.to_s)
  end
end

describe ObjectStorage do
  let(:uploader_class) { Implementation }
  let(:object) { build_stubbed(:user) }
  let(:uploader) { uploader_class.new(object, :file) }

  describe '#object_store=' do
    before do
      allow(uploader_class).to receive(:object_store_enabled?).and_return(true)
    end

    it "reload the local storage" do
      uploader.object_store = described_class::Store::LOCAL
      expect(uploader.file_storage?).to be_truthy
    end

    it "reload the REMOTE storage" do
      uploader.object_store = described_class::Store::REMOTE
      expect(uploader.file_storage?).to be_falsey
    end

    context 'object_store is Store::LOCAL' do
      before do
        uploader.object_store = described_class::Store::LOCAL
      end

      describe '#store_dir' do
        it 'is the composition of (base_dir, dynamic_segment)' do
          expect(uploader.store_dir).to start_with("uploads/-/system/user/")
        end
      end
    end

    context 'object_store is Store::REMOTE' do
      before do
        uploader.object_store = described_class::Store::REMOTE
      end

      describe '#store_dir' do
        it 'is the composition of (dynamic_segment)' do
          expect(uploader.store_dir).to start_with("user/")
        end
      end
    end
  end

  describe '#object_store' do
    subject { uploader.object_store }

    it "delegates to <mount>_store on model" do
      expect(object).to receive(:file_store)

      subject
    end

    context 'when store is null' do
      before do
        expect(object).to receive(:file_store).and_return(nil)
      end

      it "uses Store::LOCAL" do
        is_expected.to eq(described_class::Store::LOCAL)
      end
    end

    context 'when value is set' do
      before do
        expect(object).to receive(:file_store).and_return(described_class::Store::REMOTE)
      end

      it "returns the given value" do
        is_expected.to eq(described_class::Store::REMOTE)
      end
    end
  end

  describe '#file_cache_storage?' do
    context 'when file storage is used' do
      before do
        expect(uploader_class).to receive(:cache_storage) { CarrierWave::Storage::File }
      end

      it { expect(uploader).to be_file_cache_storage }
    end

    context 'when is remote storage' do
      before do
        expect(uploader_class).to receive(:cache_storage) { CarrierWave::Storage::Fog }
      end

      it { expect(uploader).not_to be_file_cache_storage }
    end
  end

  # this means the model shall include
  #   include RecordsUpload::Concern
  #   prepend ObjectStorage::Extension::RecordsUploads
  # the object_store persistence is delegated to the `Upload` model.
  #
  context 'when persist_object_store? is false' do
    let(:object) { create(:project, :with_avatar) }
    let(:uploader) { object.avatar }

    it { expect(object).to be_a(Avatarable) }
    it { expect(uploader.persist_object_store?).to be_falsey }

    describe 'delegates the object_store logic to the `Upload` model' do
      it 'sets @upload to the found `upload`' do
        expect(uploader.upload).to eq(uploader.upload)
      end

      it 'sets @object_store to the `Upload` value' do
        expect(uploader.object_store).to eq(uploader.upload.store)
      end
    end

    describe '#migrate!' do
      let(:new_store) { ObjectStorage::Store::REMOTE }

      before do
        stub_uploads_object_storage(uploader: AvatarUploader)
      end

      subject { uploader.migrate!(new_store) }

      it 'persist @object_store to the recorded upload' do
        subject

        expect(uploader.upload.store).to eq(new_store)
      end

      describe 'fails' do
        it 'is handled gracefully' do
          store = uploader.object_store
          expect_any_instance_of(Upload).to receive(:save!).and_raise("An error")

          expect { subject }.to raise_error("An error")
          expect(uploader.exists?).to be_truthy
          expect(uploader.upload.store).to eq(store)
        end
      end
    end
  end

  # this means the model holds an <mounted_as>_store attribute directly
  # and do not delegate the object_store persistence to the `Upload` model.
  #
  context 'persist_object_store? is true' do
    context 'when using JobArtifactsUploader' do
      let(:store) { described_class::Store::LOCAL }
      let(:object) { create(:ci_job_artifact, :archive, file_store: store) }
      let(:uploader) { object.file }

      context 'checking described_class' do
        it "uploader include described_class::Concern" do
          expect(uploader).to be_a(described_class::Concern)
        end
      end

      describe '#use_file' do
        context 'when file is stored locally' do
          it "calls a regular path" do
            expect { |b| uploader.use_file(&b) }.not_to yield_with_args(%r[tmp/cache])
          end
        end

        context 'when file is stored remotely' do
          let(:store) { described_class::Store::REMOTE }

          before do
            stub_artifacts_object_storage
          end

          it "calls a cache path" do
            expect { |b| uploader.use_file(&b) }.to yield_with_args(%r[tmp/cache])
          end

          it "cleans up the cached file" do
            cached_path = ''

            uploader.use_file do |path|
              cached_path = path

              expect(File.exist?(cached_path)).to be_truthy
            end

            expect(File.exist?(cached_path)).to be_falsey
          end
        end
      end

      describe '#migrate!' do
        subject { uploader.migrate!(new_store) }

        shared_examples "updates the underlying <mounted>_store" do
          it do
            subject

            expect(object.file_store).to eq(new_store)
          end
        end

        context 'when using the same storage' do
          let(:new_store) { store }

          it "to not migrate the storage" do
            subject

            expect(uploader).not_to receive(:store!)
            expect(uploader.object_store).to eq(store)
          end
        end

        context 'when migrating to local storage' do
          let(:store) { described_class::Store::REMOTE }
          let(:new_store) { described_class::Store::LOCAL }

          before do
            stub_artifacts_object_storage
          end

          include_examples "updates the underlying <mounted>_store"

          it "local file does not exist" do
            expect(File.exist?(uploader.path)).to eq(false)
          end

          it "remote file exist" do
            expect(uploader.file.exists?).to be_truthy
          end

          it "does migrate the file" do
            subject

            expect(uploader.object_store).to eq(new_store)
            expect(File.exist?(uploader.path)).to eq(true)
          end
        end

        context 'when migrating to remote storage' do
          let(:new_store) { described_class::Store::REMOTE }
          let!(:current_path) { uploader.path }

          it "file does exist" do
            expect(File.exist?(current_path)).to eq(true)
          end

          context 'when storage is disabled' do
            before do
              stub_artifacts_object_storage(enabled: false)
            end

            it "to raise an error" do
              expect { subject }.to raise_error(/Object Storage is not enabled/)
            end
          end

          context 'when credentials are set' do
            before do
              stub_artifacts_object_storage
            end

            include_examples "updates the underlying <mounted>_store"

            it "does migrate the file" do
              subject

              expect(uploader.object_store).to eq(new_store)
            end

            it "does delete original file" do
              subject

              expect(File.exist?(current_path)).to eq(false)
            end

            context 'when subject save fails' do
              before do
                expect(uploader).to receive(:persist_object_store!).and_raise(RuntimeError, "exception")
              end

              it "original file is not removed" do
                expect { subject }.to raise_error(/exception/)

                expect(File.exist?(current_path)).to eq(true)
              end
            end
          end
        end
      end
    end
  end

  describe '#fog_directory' do
    let(:remote_directory) { 'directory' }

    before do
      allow(uploader_class).to receive(:options) do
        double(object_store: double(remote_directory: remote_directory))
      end
    end

    subject { uploader.fog_directory }

    it { is_expected.to eq(remote_directory) }
  end

  context 'when file is in use' do
    def when_file_is_in_use
      uploader.use_file do
        yield
      end
    end

    it 'cannot migrate' do
      when_file_is_in_use do
        expect(uploader).not_to receive(:unsafe_migrate!)

        expect { uploader.migrate!(described_class::Store::REMOTE) }.to raise_error(ObjectStorage::ExclusiveLeaseTaken)
      end
    end

    it 'cannot use_file' do
      when_file_is_in_use do
        expect(uploader).not_to receive(:unsafe_use_file)

        expect { uploader.use_file }.to raise_error(ObjectStorage::ExclusiveLeaseTaken)
      end
    end

    it 'can still migrate other files of the same model' do
      uploader2 = uploader_class.new(object, :file)
      uploader2.upload = create(:upload)
      uploader.upload = create(:upload)

      when_file_is_in_use do
        expect(uploader2).to receive(:unsafe_migrate!)

        uploader2.migrate!(described_class::Store::REMOTE)
      end
    end
  end

  describe '#fog_credentials' do
    let(:connection) { Settingslogic.new("provider" => "AWS") }

    before do
      allow(uploader_class).to receive(:options) do
        double(object_store: double(connection: connection))
      end
    end

    subject { uploader.fog_credentials }

    it { is_expected.to eq(provider: 'AWS') }
  end

  describe '#fog_public' do
    subject { uploader.fog_public }

    it { is_expected.to eq(nil) }
  end

  describe '.workhorse_authorize' do
    let(:has_length) { true }
    let(:maximum_size) { nil }

    subject { uploader_class.workhorse_authorize(has_length: has_length, maximum_size: maximum_size) }

    shared_examples 'uses local storage' do
      it "returns temporary path" do
        is_expected.to have_key(:TempPath)

        expect(subject[:TempPath]).to start_with(uploader_class.root)
        expect(subject[:TempPath]).to include(described_class::TMP_UPLOAD_PATH)
      end
    end

    shared_examples 'uses remote storage' do
      it "returns remote store" do
        is_expected.to have_key(:RemoteObject)

        expect(subject[:RemoteObject]).to have_key(:ID)
        expect(subject[:RemoteObject]).to include(Timeout: a_kind_of(Integer))
        expect(subject[:RemoteObject][:Timeout]).to be(ObjectStorage::DirectUpload::TIMEOUT)
        expect(subject[:RemoteObject]).to have_key(:GetURL)
        expect(subject[:RemoteObject]).to have_key(:DeleteURL)
        expect(subject[:RemoteObject]).to have_key(:StoreURL)
        expect(subject[:RemoteObject][:GetURL]).to include(described_class::TMP_UPLOAD_PATH)
        expect(subject[:RemoteObject][:DeleteURL]).to include(described_class::TMP_UPLOAD_PATH)
        expect(subject[:RemoteObject][:StoreURL]).to include(described_class::TMP_UPLOAD_PATH)
      end
    end

    shared_examples 'uses remote storage with multipart uploads' do
      it_behaves_like 'uses remote storage' do
        it "returns multipart upload" do
          is_expected.to have_key(:RemoteObject)

          expect(subject[:RemoteObject]).to have_key(:MultipartUpload)
          expect(subject[:RemoteObject][:MultipartUpload]).to have_key(:PartSize)
          expect(subject[:RemoteObject][:MultipartUpload]).to have_key(:PartURLs)
          expect(subject[:RemoteObject][:MultipartUpload]).to have_key(:CompleteURL)
          expect(subject[:RemoteObject][:MultipartUpload]).to have_key(:AbortURL)
          expect(subject[:RemoteObject][:MultipartUpload][:PartURLs]).to all(include(described_class::TMP_UPLOAD_PATH))
          expect(subject[:RemoteObject][:MultipartUpload][:CompleteURL]).to include(described_class::TMP_UPLOAD_PATH)
          expect(subject[:RemoteObject][:MultipartUpload][:AbortURL]).to include(described_class::TMP_UPLOAD_PATH)
        end
      end
    end

    shared_examples 'uses remote storage without multipart uploads' do
      it_behaves_like 'uses remote storage' do
        it "does not return multipart upload" do
          is_expected.to have_key(:RemoteObject)
          expect(subject[:RemoteObject]).not_to have_key(:MultipartUpload)
        end
      end
    end

    context 'when object storage is disabled' do
      before do
        allow(Gitlab.config.uploads.object_store).to receive(:enabled) { false }
      end

      it_behaves_like 'uses local storage'
    end

    context 'when object storage is enabled' do
      before do
        allow(Gitlab.config.uploads.object_store).to receive(:enabled) { true }
      end

      context 'when direct upload is enabled' do
        before do
          allow(Gitlab.config.uploads.object_store).to receive(:direct_upload) { true }
        end

        context 'uses AWS' do
          let(:storage_url) { "https://uploads.s3-eu-central-1.amazonaws.com/" }

          before do
            expect(uploader_class).to receive(:object_store_credentials) do
              { provider: "AWS",
                aws_access_key_id: "AWS_ACCESS_KEY_ID",
                aws_secret_access_key: "AWS_SECRET_ACCESS_KEY",
                region: "eu-central-1" }
            end
          end

          context 'for known length' do
            it_behaves_like 'uses remote storage without multipart uploads' do
              it 'returns links for S3' do
                expect(subject[:RemoteObject][:GetURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:DeleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:StoreURL]).to start_with(storage_url)
              end
            end
          end

          context 'for unknown length' do
            let(:has_length) { false }
            let(:maximum_size) { 1.gigabyte }

            before do
              stub_object_storage_multipart_init(storage_url)
            end

            it_behaves_like 'uses remote storage with multipart uploads' do
              it 'returns links for S3' do
                expect(subject[:RemoteObject][:GetURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:DeleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:StoreURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:MultipartUpload][:PartURLs]).to all(start_with(storage_url))
                expect(subject[:RemoteObject][:MultipartUpload][:CompleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:MultipartUpload][:AbortURL]).to start_with(storage_url)
              end
            end
          end
        end

        context 'uses Google' do
          let(:storage_url) { "https://storage.googleapis.com/uploads/" }

          before do
            expect(uploader_class).to receive(:object_store_credentials) do
              { provider: "Google",
                google_storage_access_key_id: 'ACCESS_KEY_ID',
                google_storage_secret_access_key: 'SECRET_ACCESS_KEY' }
            end
          end

          context 'for known length' do
            it_behaves_like 'uses remote storage without multipart uploads' do
              it 'returns links for Google Cloud' do
                expect(subject[:RemoteObject][:GetURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:DeleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:StoreURL]).to start_with(storage_url)
              end
            end
          end

          context 'for unknown length' do
            let(:has_length) { false }
            let(:maximum_size) { 1.gigabyte }

            it_behaves_like 'uses remote storage without multipart uploads' do
              it 'returns links for Google Cloud' do
                expect(subject[:RemoteObject][:GetURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:DeleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:StoreURL]).to start_with(storage_url)
              end
            end
          end
        end

        context 'uses GDK/minio' do
          let(:storage_url) { "http://minio:9000/uploads/" }

          before do
            expect(uploader_class).to receive(:object_store_credentials) do
              { provider: "AWS",
                aws_access_key_id: "AWS_ACCESS_KEY_ID",
                aws_secret_access_key: "AWS_SECRET_ACCESS_KEY",
                endpoint: 'http://minio:9000',
                path_style: true,
                region: "gdk" }
            end
          end

          context 'for known length' do
            it_behaves_like 'uses remote storage without multipart uploads' do
              it 'returns links for S3' do
                expect(subject[:RemoteObject][:GetURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:DeleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:StoreURL]).to start_with(storage_url)
              end
            end
          end

          context 'for unknown length' do
            let(:has_length) { false }
            let(:maximum_size) { 1.gigabyte }

            before do
              stub_object_storage_multipart_init(storage_url)
            end

            it_behaves_like 'uses remote storage with multipart uploads' do
              it 'returns links for S3' do
                expect(subject[:RemoteObject][:GetURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:DeleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:StoreURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:MultipartUpload][:PartURLs]).to all(start_with(storage_url))
                expect(subject[:RemoteObject][:MultipartUpload][:CompleteURL]).to start_with(storage_url)
                expect(subject[:RemoteObject][:MultipartUpload][:AbortURL]).to start_with(storage_url)
              end
            end
          end
        end
      end

      context 'when direct upload is disabled' do
        before do
          allow(Gitlab.config.uploads.object_store).to receive(:direct_upload) { false }
        end

        it_behaves_like 'uses local storage'
      end
    end
  end

  describe '#cache!' do
    subject do
      uploader.cache!(uploaded_file)
    end

    context 'when local file is used' do
      context 'when valid file is used' do
        let(:uploaded_file) do
          fixture_file_upload('spec/fixtures/rails_sample.jpg', 'image/jpg')
        end

        it "properly caches the file" do
          subject

          expect(uploader).to be_exists
          expect(uploader.path).to start_with(uploader_class.root)
          expect(uploader.filename).to eq('rails_sample.jpg')
        end
      end
    end

    context 'when local file is used' do
      let(:temp_file) { Tempfile.new("test") }

      before do
        FileUtils.touch(temp_file)
      end

      after do
        FileUtils.rm_f(temp_file)
      end

      context 'when valid file is used' do
        context 'when valid file is specified' do
          let(:uploaded_file) { temp_file }

          context 'when object storage and direct upload is specified' do
            before do
              stub_uploads_object_storage(uploader_class, enabled: true, direct_upload: true)
            end

            context 'when file is stored' do
              subject do
                uploader.store!(uploaded_file)
              end

              it 'file to be remotely stored in permament location' do
                subject

                expect(uploader).to be_exists
                expect(uploader).not_to be_cached
                expect(uploader).not_to be_file_storage
                expect(uploader.path).not_to be_nil
                expect(uploader.path).not_to include('tmp/upload')
                expect(uploader.path).not_to include('tmp/cache')
                expect(uploader.object_store).to eq(described_class::Store::REMOTE)
              end
            end
          end

          context 'when object storage and direct upload is not used' do
            before do
              stub_uploads_object_storage(uploader_class, enabled: true, direct_upload: false)
            end

            context 'when file is stored' do
              subject do
                uploader.store!(uploaded_file)
              end

              it 'file to be remotely stored in permament location' do
                subject

                expect(uploader).to be_exists
                expect(uploader).not_to be_cached
                expect(uploader).to be_file_storage
                expect(uploader.path).not_to be_nil
                expect(uploader.path).not_to include('tmp/upload')
                expect(uploader.path).not_to include('tmp/cache')
                expect(uploader.object_store).to eq(described_class::Store::LOCAL)
              end
            end
          end
        end
      end
    end

    context 'when remote file is used' do
      let(:temp_file) { Tempfile.new("test") }

      let!(:fog_connection) do
        stub_uploads_object_storage(uploader_class)
      end

      before do
        FileUtils.touch(temp_file)
      end

      after do
        FileUtils.rm_f(temp_file)
      end

      context 'when valid file is used' do
        context 'when invalid file is specified' do
          let(:uploaded_file) do
            UploadedFile.new(temp_file.path, remote_id: "../test/123123")
          end

          it 'raises an error' do
            expect { subject }.to raise_error(uploader_class::RemoteStoreError, /Bad file path/)
          end
        end

        context 'when non existing file is specified' do
          let(:uploaded_file) do
            UploadedFile.new(temp_file.path, remote_id: "test/123123")
          end

          it 'raises an error' do
            expect { subject }.to raise_error(uploader_class::RemoteStoreError, /Missing file/)
          end
        end

        context 'when valid file is specified' do
          let(:uploaded_file) do
            UploadedFile.new(temp_file.path, filename: "my_file.txt", remote_id: "test/123123")
          end

          let!(:fog_file) do
            fog_connection.directories.new(key: 'uploads').files.create(
              key: 'tmp/uploads/test/123123',
              body: 'content'
            )
          end

          it 'file to be cached and remote stored' do
            expect { subject }.not_to raise_error

            expect(uploader).to be_exists
            expect(uploader).to be_cached
            expect(uploader).not_to be_file_storage
            expect(uploader.path).not_to be_nil
            expect(uploader.path).not_to include('tmp/cache')
            expect(uploader.path).not_to include('tmp/cache')
            expect(uploader.object_store).to eq(described_class::Store::REMOTE)
          end

          context 'when file is stored' do
            subject do
              uploader.store!(uploaded_file)
            end

            it 'file to be remotely stored in permament location' do
              subject

              expect(uploader).to be_exists
              expect(uploader).not_to be_cached
              expect(uploader).not_to be_file_storage
              expect(uploader.path).not_to be_nil
              expect(uploader.path).not_to include('tmp/upload')
              expect(uploader.path).not_to include('tmp/cache')
              expect(uploader.url).to include('/my_file.txt')
              expect(uploader.object_store).to eq(described_class::Store::REMOTE)
            end
          end
        end
      end
    end
  end

  describe '#retrieve_from_store!' do
    [:group, :project, :user].each do |model|
      context "for #{model}s" do
        let(:models) { create_list(model, 3, :with_avatar).map(&:reload) }
        let(:avatars) { models.map(&:avatar) }

        it 'batches fetching uploads from the database' do
          # Ensure that these are all created and fully loaded before we start
          # running queries for avatars
          models

          expect { avatars }.not_to exceed_query_limit(1)
        end

        it 'does not attempt to replace methods' do
          models.each do |model|
            expect(model.avatar.upload).to receive(:method_missing).and_call_original

            model.avatar.upload.path
          end
        end

        it 'fetches a unique upload for each model' do
          expect(avatars.map(&:url).uniq).to eq(avatars.map(&:url))
          expect(avatars.map(&:upload).uniq).to eq(avatars.map(&:upload))
        end
      end
    end
  end
end

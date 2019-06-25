require 'spec_helper'

describe ObjectStorage::BackgroundMoveWorker do
  let(:local) { ObjectStorage::Store::LOCAL }
  let(:remote) { ObjectStorage::Store::REMOTE }

  def perform
    described_class.perform_async(uploader_class.name, subject_class, file_field, subject_id)
  end

  context 'for LFS' do
    let!(:lfs_object) { create(:lfs_object, :with_file, file_store: local) }
    let(:uploader_class) { LfsObjectUploader }
    let(:subject_class) { LfsObject }
    let(:file_field) { :file }
    let(:subject_id) { lfs_object.id }

    context 'when object storage is enabled' do
      before do
        stub_lfs_object_storage(background_upload: true)
      end

      it 'uploads object to storage' do
        expect { perform }.to change { lfs_object.reload.file_store }.from(local).to(remote)
      end

      context 'when background upload is disabled' do
        before do
          allow(Gitlab.config.lfs.object_store).to receive(:background_upload) { false }
        end

        it 'is skipped' do
          expect { perform }.not_to change { lfs_object.reload.file_store }
        end
      end
    end

    context 'when object storage is disabled' do
      before do
        stub_lfs_object_storage(enabled: false)
      end

      it "doesn't migrate files" do
        perform

        expect(lfs_object.reload.file_store).to eq(local)
      end
    end
  end

  context 'for job artifacts' do
    let(:artifact) { create(:ci_job_artifact, :archive) }
    let(:uploader_class) { JobArtifactUploader }
    let(:subject_class) { Ci::JobArtifact }
    let(:file_field) { :file }
    let(:subject_id) { artifact.id }

    context 'when local storage is used' do
      let(:store) { local }

      context 'and remote storage is defined' do
        before do
          stub_artifacts_object_storage(background_upload: true)
        end

        it "migrates file to remote storage" do
          perform

          expect(artifact.reload.file_store).to eq(remote)
        end
      end
    end
  end

  context 'for uploads' do
    let!(:project) { create(:project, :with_avatar) }
    let(:uploader_class) { AvatarUploader }
    let(:file_field) { :avatar }

    context 'when local storage is used' do
      let(:store) { local }

      context 'and remote storage is defined' do
        before do
          stub_uploads_object_storage(uploader_class, background_upload: true)
        end

        describe 'supports using the model' do
          let(:subject_class) { project.class }
          let(:subject_id) { project.id }

          it "migrates file to remote storage" do
            perform
            project.reload
            BatchLoader::Executor.clear_current

            expect(project.avatar).not_to be_file_storage
          end
        end

        describe 'supports using the Upload' do
          let(:subject_class) { Upload }
          let(:subject_id) { project.avatar.upload.id }

          it "migrates file to remote storage" do
            perform

            expect(project.reload.avatar).not_to be_file_storage
          end
        end
      end
    end
  end
end

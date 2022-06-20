# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobArtifacts::DestroyAllExpiredService, :clean_gitlab_redis_shared_state do
  include ExclusiveLeaseHelpers

  let(:service) { described_class.new }

  describe '.execute' do
    subject { service.execute }

    let_it_be(:locked_pipeline) { create(:ci_pipeline, :artifacts_locked) }
    let_it_be(:pipeline) { create(:ci_pipeline, :unlocked) }
    let_it_be(:locked_job) { create(:ci_build, :success, pipeline: locked_pipeline) }
    let_it_be(:job) { create(:ci_build, :success, pipeline: pipeline) }

    context 'when artifact is expired' do
      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }

      context 'with preloaded relationships' do
        let(:second_artifact) { create(:ci_job_artifact, :expired, :junit, job: job) }

        let(:more_artifacts) do
          [
            create(:ci_job_artifact, :expired, :sast, job: job),
            create(:ci_job_artifact, :expired, :metadata, job: job),
            create(:ci_job_artifact, :expired, :codequality, job: job),
            create(:ci_job_artifact, :expired, :accessibility, job: job)
          ]
        end

        before do
          stub_const("#{described_class}::LOOP_LIMIT", 1)

          # This artifact-with-file is created before the control execution to ensure
          # that the DeletedObject operations are accounted for in the query count.
          second_artifact
        end

        context 'with ci_destroy_unlocked_job_artifacts feature flag disabled' do
          before do
            stub_feature_flags(ci_destroy_unlocked_job_artifacts: false)
          end

          it 'performs a consistent number of queries' do
            control = ActiveRecord::QueryRecorder.new { service.execute }

            more_artifacts

            expect { subject }.not_to exceed_query_limit(control.count)
          end
        end

        context 'with ci_destroy_unlocked_job_artifacts feature flag enabled' do
          before do
            stub_feature_flags(ci_destroy_unlocked_job_artifacts: true)
          end

          it 'performs a consistent number of queries' do
            control = ActiveRecord::QueryRecorder.new { service.execute }

            more_artifacts

            expect { subject }.not_to exceed_query_limit(control.count)
          end
        end
      end

      context 'when artifact is not locked' do
        it 'deletes job artifact record' do
          expect { subject }.to change { Ci::JobArtifact.count }.by(-1)
        end

        context 'when the artifact does not have a file attached to it' do
          it 'does not create deleted objects' do
            expect(artifact.exists?).to be_falsy # sanity check

            expect { subject }.not_to change { Ci::DeletedObject.count }
          end
        end

        context 'when the artifact has a file attached to it' do
          let!(:artifact) { create(:ci_job_artifact, :expired, :zip, job: job, locked: job.pipeline.locked) }

          it 'creates a deleted object' do
            expect { subject }.to change { Ci::DeletedObject.count }.by(1)
          end

          it 'resets project statistics' do
            expect(ProjectStatistics).to receive(:increment_statistic).once
              .with(artifact.project, :build_artifacts_size, -artifact.file.size)
              .and_call_original

            subject
          end

          it 'does not remove the files' do
            expect { subject }.not_to change { artifact.file.exists? }
          end
        end
      end

      context 'when artifact is locked' do
        let!(:artifact) { create(:ci_job_artifact, :expired, job: locked_job, locked: locked_job.pipeline.locked) }

        it 'does not destroy job artifact' do
          expect { subject }.not_to change { Ci::JobArtifact.count }
        end
      end
    end

    context 'when artifact is not expired' do
      let!(:artifact) { create(:ci_job_artifact, job: job, locked: job.pipeline.locked) }

      it 'does not destroy expired job artifacts' do
        expect { subject }.not_to change { Ci::JobArtifact.count }
      end
    end

    context 'when artifact is permanent' do
      let!(:artifact) { create(:ci_job_artifact, expire_at: nil, job: job, locked: job.pipeline.locked) }

      it 'does not destroy expired job artifacts' do
        expect { subject }.not_to change { Ci::JobArtifact.count }
      end
    end

    context 'when failed to destroy artifact' do
      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }

      before do
        stub_const("#{described_class}::LOOP_LIMIT", 10)
      end

      context 'when the import fails' do
        before do
          expect(Ci::DeletedObject)
            .to receive(:bulk_import)
            .once
            .and_raise(ActiveRecord::RecordNotDestroyed)
        end

        it 'raises an exception and stop destroying' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed)
                            .and not_change { Ci::JobArtifact.count }.from(1)
        end
      end

      context 'when the delete fails' do
        before do
          expect(Ci::JobArtifact)
            .to receive(:id_in)
            .once
            .and_raise(ActiveRecord::RecordNotDestroyed)
        end

        it 'raises an exception rolls back the insert' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotDestroyed)
                            .and not_change { Ci::DeletedObject.count }.from(0)
        end
      end
    end

    context 'when exclusive lease has already been taken by the other instance' do
      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }

      before do
        stub_exclusive_lease_taken(described_class::EXCLUSIVE_LOCK_KEY, timeout: described_class::LOCK_TIMEOUT)
      end

      it 'raises an error and does not start destroying' do
        expect { subject }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
                          .and not_change { Ci::JobArtifact.count }.from(1)
      end
    end

    context 'with a second artifact and batch size of 1' do
      let(:second_job) { create(:ci_build, :success, pipeline: pipeline) }
      let!(:second_artifact) { create(:ci_job_artifact, :archive, expire_at: 1.day.ago, job: second_job, locked: job.pipeline.locked) }
      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      context 'when timeout happens' do
        before do
          stub_const("#{described_class}::LOOP_TIMEOUT", 0.seconds)
        end

        it 'destroys one artifact' do
          expect { subject }.to change { Ci::JobArtifact.count }.by(-1)
        end

        it 'reports the number of destroyed artifacts' do
          is_expected.to eq(1)
        end
      end

      context 'when loop reached loop limit' do
        before do
          stub_const("#{described_class}::LOOP_LIMIT", 1)
        end

        it 'destroys one artifact' do
          expect { subject }.to change { Ci::JobArtifact.count }.by(-1)
        end

        it 'reports the number of destroyed artifacts' do
          is_expected.to eq(1)
        end
      end

      context 'when the number of artifacts is greater than than batch size' do
        it 'destroys all expired artifacts' do
          expect { subject }.to change { Ci::JobArtifact.count }.by(-2)
        end

        it 'reports the number of destroyed artifacts' do
          is_expected.to eq(2)
        end
      end
    end

    context 'when there are no artifacts' do
      it 'does not raise error' do
        expect { subject }.not_to raise_error
      end

      it 'reports the number of destroyed artifacts' do
        is_expected.to eq(0)
      end
    end

    context 'when some artifacts are locked' do
      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }
      let!(:locked_artifact) { create(:ci_job_artifact, :expired, job: locked_job, locked: locked_job.pipeline.locked) }

      it 'destroys only unlocked artifacts' do
        expect { subject }.to change { Ci::JobArtifact.count }.by(-1)
        expect(locked_artifact).to be_persisted
      end
    end

    context 'when all artifacts are locked' do
      let!(:artifact) { create(:ci_job_artifact, :expired, job: locked_job, locked: locked_job.pipeline.locked) }

      it 'destroys no artifacts' do
        expect { subject }.to change { Ci::JobArtifact.count }.by(0)
      end
    end
  end
end

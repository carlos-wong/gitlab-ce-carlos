# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::RefreshBuildArtifactsSizeStatisticsService, :clean_gitlab_redis_shared_state do
  let(:service) { described_class.new }

  describe '#execute' do
    let_it_be(:project) { create(:project) }

    let_it_be(:artifact_1) { create(:ci_job_artifact, project: project, size: 1, created_at: 14.days.ago) }
    let_it_be(:artifact_2) { create(:ci_job_artifact, project: project, size: 2, created_at: 13.days.ago) }
    let_it_be(:artifact_3) { create(:ci_job_artifact, project: project, size: nil, created_at: 13.days.ago) }
    let_it_be(:artifact_4) { create(:ci_job_artifact, project: project, size: 5, created_at: 12.days.ago) }

    # This should not be included in the recalculation as it is created later than the refresh start time
    let_it_be(:future_artifact) { create(:ci_job_artifact, project: project, size: 8, created_at: 2.days.from_now) }

    let!(:refresh) do
      create(
        :project_build_artifacts_size_refresh,
        :created,
        project: project,
        updated_at: 2.days.ago,
        refresh_started_at: nil,
        last_job_artifact_id: nil
      )
    end

    let(:now) { Time.zone.now }

    around do |example|
      freeze_time { example.run }
    end

    before do
      stub_const("#{described_class}::BATCH_SIZE", 3)

      stats = create(:project_statistics, project: project, build_artifacts_size: 120)
      stats.increment_counter(:build_artifacts_size, 30)
    end

    it 'resets the build artifacts size stats' do
      expect { service.execute }.to change { project.statistics.reload.build_artifacts_size }.to(0)
    end

    it 'increments the counter attribute by the total size of the current batch of artifacts' do
      expect { service.execute }.to change { project.statistics.get_counter_value(:build_artifacts_size) }.to(3)
    end

    it 'updates the last_job_artifact_id to the ID of the last artifact from the batch' do
      expect { service.execute }.to change { refresh.reload.last_job_artifact_id.to_i }.to(artifact_3.id)
    end

    it 'requeues the refresh job' do
      service.execute
      expect(refresh.reload).to be_pending
    end

    context 'when an error happens after the recalculation has started' do
      let!(:refresh) do
        create(
          :project_build_artifacts_size_refresh,
          :pending,
          project: project,
          last_job_artifact_id: artifact_3.id
        )
      end

      before do
        allow(Gitlab::Redis::SharedState).to receive(:with).and_raise(StandardError, 'error')

        expect { service.execute }.to raise_error(StandardError)
      end

      it 'keeps the last_job_artifact_id unchanged' do
        expect(refresh.reload.last_job_artifact_id).to eq(artifact_3.id)
      end

      it 'keeps the state of the refresh record at running' do
        expect(refresh.reload).to be_running
      end
    end

    context 'when there are no more artifacts to recalculate for the next refresh job' do
      let!(:refresh) do
        create(
          :project_build_artifacts_size_refresh,
          :pending,
          project: project,
          updated_at: 2.days.ago,
          refresh_started_at: now,
          last_job_artifact_id: artifact_4.id
        )
      end

      it 'deletes the refresh record' do
        service.execute
        expect(Projects::BuildArtifactsSizeRefresh.where(id: refresh.id)).not_to exist
      end
    end
  end
end

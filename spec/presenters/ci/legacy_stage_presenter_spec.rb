# frozen_string_literal: true

require 'spec_helper'

describe Ci::LegacyStagePresenter do
  let(:legacy_stage) { create(:ci_stage) }
  let(:presenter) { described_class.new(legacy_stage) }

  let!(:build) { create(:ci_build, :tags, :artifacts, pipeline: legacy_stage.pipeline, stage: legacy_stage.name) }
  let!(:retried_build) { create(:ci_build, :tags, :artifacts, :retried, pipeline: legacy_stage.pipeline, stage: legacy_stage.name) }

  before do
    create(:generic_commit_status, pipeline: legacy_stage.pipeline, stage: legacy_stage.name)
  end

  describe '#latest_ordered_statuses' do
    subject(:latest_ordered_statuses) { presenter.latest_ordered_statuses }

    it 'preloads build tags' do
      expect(latest_ordered_statuses.second.association(:tags)).to be_loaded
    end

    it 'preloads build artifacts archive' do
      expect(latest_ordered_statuses.second.association(:job_artifacts_archive)).to be_loaded
    end

    it 'preloads build artifacts metadata' do
      expect(latest_ordered_statuses.second.association(:metadata)).to be_loaded
    end
  end

  describe '#retried_ordered_statuses' do
    subject(:retried_ordered_statuses) { presenter.retried_ordered_statuses }

    it 'preloads build tags' do
      expect(retried_ordered_statuses.first.association(:tags)).to be_loaded
    end

    it 'preloads build artifacts archive' do
      expect(retried_ordered_statuses.first.association(:job_artifacts_archive)).to be_loaded
    end

    it 'preloads build artifacts metadata' do
      expect(retried_ordered_statuses.first.association(:metadata)).to be_loaded
    end
  end
end

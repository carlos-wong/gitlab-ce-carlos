# frozen_string_literal: true

require 'spec_helper'

describe PipelineUpdateCiRefStatusWorker do
  let(:worker) { described_class.new }
  let(:pipeline) { create(:ci_pipeline) }

  describe '#perform' do
    it 'updates the ci_ref status' do
      expect(Ci::UpdateCiRefStatusService).to receive(:new)
        .with(pipeline)
        .and_return(double(call: true))

      worker.perform(pipeline.id)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe PipelineProcessWorker do
  describe '#perform' do
    context 'when pipeline exists' do
      let(:pipeline) { create(:ci_pipeline) }

      it 'processes pipeline' do
        expect_any_instance_of(Ci::Pipeline).to receive(:process!)

        described_class.new.perform(pipeline.id)
      end
    end

    context 'when pipeline does not exist' do
      it 'does not raise exception' do
        expect { described_class.new.perform(123) }
          .not_to raise_error
      end
    end
  end
end

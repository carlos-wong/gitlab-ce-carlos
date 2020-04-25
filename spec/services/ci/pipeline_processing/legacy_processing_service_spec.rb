# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_processing_service.rb'

describe Ci::PipelineProcessing::LegacyProcessingService do
  before do
    stub_feature_flags(ci_atomic_processing: false)
  end

  it_behaves_like 'Pipeline Processing Service'

  private

  def process_pipeline(initial_process: false)
    described_class.new(pipeline).execute(initial_process: initial_process)
  end
end

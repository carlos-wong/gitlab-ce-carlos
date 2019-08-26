# frozen_string_literal: true

require 'spec_helper'

shared_examples 'default query config' do
  let(:project) { create(:project) }
  let(:event) { described_class.new(stage: stage_name, options: { from: 1.day.ago, project: project }) }

  it 'has the stage attribute' do
    expect(event.stage).not_to be_nil
  end

  it 'has the projection attributes' do
    expect(event.projections).not_to be_nil
  end
end

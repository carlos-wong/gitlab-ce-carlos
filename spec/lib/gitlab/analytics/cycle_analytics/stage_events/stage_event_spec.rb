# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Analytics::CycleAnalytics::StageEvents::StageEvent do
  let(:instance) { described_class.new({}) }

  it { expect(described_class).to respond_to(:name) }
  it { expect(described_class).to respond_to(:identifier) }
  it { expect(instance).to respond_to(:object_type) }
  it { expect(instance).to respond_to(:timestamp_projection) }
  it { expect(instance).to respond_to(:apply_query_customization) }
end

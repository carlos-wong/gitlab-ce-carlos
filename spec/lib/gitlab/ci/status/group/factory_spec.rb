# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Status::Group::Factory do
  it 'inherits from the core factory' do
    expect(described_class)
      .to be < Gitlab::Ci::Status::Factory
  end

  it 'exposes group helpers' do
    expect(described_class.common_helpers)
      .to eq Gitlab::Ci::Status::Group::Common
  end
end

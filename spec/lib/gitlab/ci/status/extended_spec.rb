# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Status::Extended do
  it 'requires subclass to implement matcher' do
    expect { described_class.matches?(double, double) }
      .to raise_error(NotImplementedError)
  end
end

# frozen_string_literal: true

require 'fast_spec_helper'
require 'rubocop'
require_relative '../../../support/helpers/expect_offense'
require_relative '../../../../rubocop/cop/scalability/idempotent_worker'

describe RuboCop::Cop::Scalability::IdempotentWorker do
  include CopHelper
  include ExpectOffense

  subject(:cop) { described_class.new }

  before do
    allow(cop)
      .to receive(:in_worker?)
      .and_return(true)
  end

  it 'adds an offense when not defining idempotent method' do
    inspect_source(<<~CODE.strip_indent)
      class SomeWorker
      end
    CODE

    expect(cop.offenses.size).to eq(1)
  end

  it 'adds an offense when not defining idempotent method' do
    inspect_source(<<~CODE.strip_indent)
      class SomeWorker
        idempotent!
      end
    CODE

    expect(cop.offenses.size).to be_zero
  end
end

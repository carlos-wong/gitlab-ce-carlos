# frozen_string_literal: true

require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../rubocop/cop/gitlab/union'

describe RuboCop::Cop::Gitlab::Union do
  include CopHelper

  subject(:cop) { described_class.new }

  it 'flags the use of Gitlab::SQL::Union.new' do
    expect_offense(<<~SOURCE)
    Gitlab::SQL::Union.new([foo])
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use the `FromUnion` concern, instead of using `Gitlab::SQL::Union` directly
    SOURCE
  end
end

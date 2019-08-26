# frozen_string_literal: true

require 'spec_helper'

describe Bitbucket::Representation::Issue do
  describe '#iid' do
    it { expect(described_class.new('id' => 1).iid).to eq(1) }
  end

  describe '#kind' do
    it { expect(described_class.new('kind' => 'bug').kind).to eq('bug') }
  end

  describe '#milestone' do
    it { expect(described_class.new({ 'milestone' => { 'name' => '1.0' } }).milestone).to eq('1.0') }
    it { expect(described_class.new({}).milestone).to be_nil }
  end

  describe '#author' do
    it { expect(described_class.new({ 'reporter' => { 'nickname' => 'Ben' } }).author).to eq('Ben') }
    it { expect(described_class.new({}).author).to be_nil }
  end

  describe '#description' do
    it { expect(described_class.new({ 'content' => { 'raw' => 'Text' } }).description).to eq('Text') }
    it { expect(described_class.new({}).description).to be_nil }
  end

  describe '#state' do
    it { expect(described_class.new({ 'state' => 'invalid' }).state).to eq('closed') }
    it { expect(described_class.new({ 'state' => 'wontfix' }).state).to eq('closed') }
    it { expect(described_class.new({ 'state' => 'resolved' }).state).to eq('closed') }
    it { expect(described_class.new({ 'state' => 'duplicate' }).state).to eq('closed') }
    it { expect(described_class.new({ 'state' => 'closed' }).state).to eq('closed') }
    it { expect(described_class.new({ 'state' => 'opened' }).state).to eq('opened') }
  end

  describe '#title' do
    it { expect(described_class.new('title' => 'Issue').title).to eq('Issue') }
  end

  describe '#created_at' do
    it { expect(described_class.new('created_on' => Date.today).created_at).to eq(Date.today) }
  end

  describe '#updated_at' do
    it { expect(described_class.new('edited_on' => Date.today).updated_at).to eq(Date.today) }
  end
end

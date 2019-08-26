# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Status::Skipped do
  subject do
    described_class.new(double('subject'), double('user'))
  end

  describe '#text' do
    it { expect(subject.text).to eq 'skipped' }
  end

  describe '#label' do
    it { expect(subject.label).to eq 'skipped' }
  end

  describe '#icon' do
    it { expect(subject.icon).to eq 'status_skipped' }
  end

  describe '#favicon' do
    it { expect(subject.favicon).to eq 'favicon_status_skipped' }
  end

  describe '#group' do
    it { expect(subject.group).to eq 'skipped' }
  end
end

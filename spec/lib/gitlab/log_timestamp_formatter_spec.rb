# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::LogTimestampFormatter do
  subject { described_class.new }

  let(:formatted_timestamp) { Time.now.utc.iso8601(3) }

  it 'logs the timestamp in UTC and ISO8601.3 format' do
    Timecop.freeze(Time.now) do
      expect(subject.call('', Time.now, '', '')).to include formatted_timestamp
    end
  end
end

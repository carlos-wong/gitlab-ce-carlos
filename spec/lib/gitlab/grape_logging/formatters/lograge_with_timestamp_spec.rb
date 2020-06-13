# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::GrapeLogging::Formatters::LogrageWithTimestamp do
  let(:log_entry) do
    {
      status: 200,
      time:  {
        total: 758.58,
        db: 77.06,
        view: 681.52
      },
      method: 'PUT',
      path: '/api/v4/projects/1',
      params: {
        'description': '[FILTERED]',
        'name': 'gitlab test'
      },
      host: 'localhost',
      remote_ip: '127.0.0.1',
      ua: 'curl/7.66.0',
      route: '/api/:version/projects/:id',
      user_id: 1,
      username: 'root',
      queue_duration: 1764.06,
      gitaly_calls: 6,
      gitaly_duration: 20.0,
      correlation_id: 'WMefXn60429'
    }
  end
  let(:time) { Time.now }
  let(:result) { JSON.parse(subject) }

  subject { described_class.new.call(:info, time, nil, log_entry) }

  it 'turns the log entry to valid JSON' do
    expect(result['status']).to eq(200)
  end

  it 're-formats the params hash' do
    params = result['params']

    expect(params).to eq([
      { 'key' => 'description', 'value' => '[FILTERED]' },
      { 'key' => 'name', 'value' => 'gitlab test' }
    ])
  end
end

# frozen_string_literal: true

require 'fast_spec_helper'

describe Gitlab::Alerting::NotificationPayloadParser do
  describe '.call' do
    let(:starts_at) { Time.current.change(usec: 0) }
    let(:payload) do
      {
        'title' => 'alert title',
        'start_time' => starts_at.rfc3339,
        'description' => 'Description',
        'monitoring_tool' => 'Monitoring tool name',
        'service' => 'Service',
        'hosts' => ['gitlab.com']
      }
    end

    subject { described_class.call(payload) }

    it 'returns Prometheus-like payload' do
      is_expected.to eq(
        {
          'annotations' => {
            'title' => 'alert title',
            'description' => 'Description',
            'monitoring_tool' => 'Monitoring tool name',
            'service' => 'Service',
            'hosts' => ['gitlab.com']
          },
          'startsAt' => starts_at.rfc3339
        }
      )
    end

    context 'when title is blank' do
      before do
        payload[:title] = ''
      end

      it 'sets a predefined title' do
        expect(subject.dig('annotations', 'title')).to eq('New: Incident')
      end
    end

    context 'when hosts attribute is a string' do
      before do
        payload[:hosts] = 'gitlab.com'
      end

      it 'returns hosts as an array of one element' do
        expect(subject.dig('annotations', 'hosts')).to eq(['gitlab.com'])
      end
    end

    context 'when the time is in unsupported format' do
      before do
        payload[:start_time] = 'invalid/date/format'
      end

      it 'sets startsAt to a current time in RFC3339 format' do
        expect(subject['startsAt']).to eq(starts_at.rfc3339)
      end
    end

    context 'when payload is blank' do
      let(:payload) { {} }

      it 'returns default parameters' do
        is_expected.to eq(
          'annotations' => { 'title' => 'New: Incident' },
          'startsAt' => starts_at.rfc3339
        )
      end
    end

    context 'when payload attributes have blank lines' do
      let(:payload) do
        {
          'title' => '',
          'start_time' => '',
          'description' => '',
          'monitoring_tool' => '',
          'service' => '',
          'hosts' => ['']
        }
      end

      it 'returns default parameters' do
        is_expected.to eq(
          'annotations' => { 'title' => 'New: Incident' },
          'startsAt' => starts_at.rfc3339
        )
      end
    end

    context 'when payload has secondary params' do
      let(:payload) do
        {
          'description' => 'Description',
          'additional' => {
            'params' => {
              '1' => 'Some value 1',
              '2' => 'Some value 2',
              'blank' => ''
            }
          }
        }
      end

      it 'adds secondary params to annotations' do
        is_expected.to eq(
          'annotations' => {
            'title' => 'New: Incident',
            'description' => 'Description',
            'additional.params.1' => 'Some value 1',
            'additional.params.2' => 'Some value 2'
          },
          'startsAt' => starts_at.rfc3339
        )
      end
    end

    context 'when secondary params hash is too big' do
      before do
        allow(Gitlab::Utils::SafeInlineHash).to receive(:merge_keys!).and_raise(ArgumentError)
      end

      it 'catches and re-raises an error' do
        expect { subject }.to raise_error Gitlab::Alerting::NotificationPayloadParser::BadPayloadError, 'The payload is too big'
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Metrics do
  include StubENV

  describe '.settings' do
    it 'returns a Hash' do
      expect(described_class.settings).to be_an_instance_of(Hash)
    end
  end

  describe '.enabled?' do
    it 'returns a boolean' do
      expect(described_class.enabled?).to be_in([true, false])
    end
  end

  describe '.prometheus_metrics_enabled_unmemoized' do
    subject { described_class.send(:prometheus_metrics_enabled_unmemoized) }

    context 'prometheus metrics enabled in config' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:prometheus_metrics_enabled).and_return(true)
      end

      context 'when metrics folder is present' do
        before do
          allow(described_class).to receive(:metrics_folder_present?).and_return(true)
        end

        it 'metrics are enabled' do
          expect(subject).to eq(true)
        end
      end

      context 'when metrics folder is missing' do
        before do
          allow(described_class).to receive(:metrics_folder_present?).and_return(false)
        end

        it 'metrics are disabled' do
          expect(subject).to eq(false)
        end
      end
    end
  end

  describe '.prometheus_metrics_enabled?' do
    it 'returns a boolean' do
      expect(described_class.prometheus_metrics_enabled?).to be_in([true, false])
    end
  end

  describe '.influx_metrics_enabled?' do
    it 'returns a boolean' do
      expect(described_class.influx_metrics_enabled?).to be_in([true, false])
    end
  end

  describe '.submit_metrics' do
    it 'prepares and writes the metrics to InfluxDB' do
      connection = double(:connection)
      pool       = double(:pool)

      expect(pool).to receive(:with).and_yield(connection)
      expect(connection).to receive(:write_points).with(an_instance_of(Array))
      expect(described_class).to receive(:pool).and_return(pool)

      described_class.submit_metrics([{ 'series' => 'kittens', 'tags' => {} }])
    end
  end

  describe '.prepare_metrics' do
    it 'returns a Hash with the keys as Symbols' do
      metrics = described_class
        .prepare_metrics([{ 'values' => {}, 'tags' => {} }])

      expect(metrics).to eq([{ values: {}, tags: {} }])
    end

    it 'escapes tag values' do
      metrics = described_class.prepare_metrics([
        { 'values' => {}, 'tags' => { 'foo' => 'bar=' } }
      ])

      expect(metrics).to eq([{ values: {}, tags: { 'foo' => 'bar\\=' } }])
    end

    it 'drops empty tags' do
      metrics = described_class.prepare_metrics([
        { 'values' => {}, 'tags' => { 'cats' => '', 'dogs' => nil } }
      ])

      expect(metrics).to eq([{ values: {}, tags: {} }])
    end
  end

  describe '.escape_value' do
    it 'escapes an equals sign' do
      expect(described_class.escape_value('foo=')).to eq('foo\\=')
    end

    it 'casts values to Strings' do
      expect(described_class.escape_value(10)).to eq('10')
    end
  end

  describe '.measure' do
    context 'without a transaction' do
      it 'returns the return value of the block' do
        val = described_class.measure(:foo) { 10 }

        expect(val).to eq(10)
      end
    end

    context 'with a transaction' do
      let(:transaction) { Gitlab::Metrics::WebTransaction.new({}) }

      before do
        allow(described_class).to receive(:current_transaction)
          .and_return(transaction)
      end

      it 'adds a metric to the current transaction' do
        expect(transaction).to receive(:increment)
                                 .with('foo_real_time', a_kind_of(Numeric), false)

        expect(transaction).to receive(:increment)
                                 .with('foo_cpu_time', a_kind_of(Numeric), false)

        expect(transaction).to receive(:increment)
                                 .with('foo_call_count', 1, false)

        described_class.measure(:foo) { 10 }
      end

      it 'returns the return value of the block' do
        val = described_class.measure(:foo) { 10 }

        expect(val).to eq(10)
      end
    end
  end

  describe '.action=' do
    context 'without a transaction' do
      it 'does nothing' do
        expect_any_instance_of(Gitlab::Metrics::Transaction)
          .not_to receive(:action=)

        described_class.action = 'foo'
      end
    end

    context 'with a transaction' do
      it 'sets the action of a transaction' do
        trans = Gitlab::Metrics::WebTransaction.new({})

        expect(described_class).to receive(:current_transaction)
          .and_return(trans)

        expect(trans).to receive(:action=).with('foo')

        described_class.action = 'foo'
      end
    end
  end

  describe '#series_prefix' do
    it 'returns a String' do
      expect(described_class.series_prefix).to be_an_instance_of(String)
    end
  end

  describe '.add_event' do
    context 'without a transaction' do
      it 'does nothing' do
        expect_any_instance_of(Gitlab::Metrics::Transaction)
          .not_to receive(:add_event)

        described_class.add_event(:meow)
      end
    end

    context 'with a transaction' do
      it 'adds an event' do
        transaction = Gitlab::Metrics::WebTransaction.new({})

        expect(transaction).to receive(:add_event).with(:meow)

        expect(described_class).to receive(:current_transaction)
          .and_return(transaction)

        described_class.add_event(:meow)
      end
    end
  end

  shared_examples 'prometheus metrics API' do
    describe '#counter' do
      subject { described_class.counter(:counter, 'doc') }

      describe '#increment' do
        it 'successfully calls #increment without arguments' do
          expect { subject.increment }.not_to raise_exception
        end

        it 'successfully calls #increment with 1 argument' do
          expect { subject.increment({}) }.not_to raise_exception
        end

        it 'successfully calls #increment with 2 arguments' do
          expect { subject.increment({}, 1) }.not_to raise_exception
        end
      end
    end

    describe '#summary' do
      subject { described_class.summary(:summary, 'doc') }

      describe '#observe' do
        it 'successfully calls #observe with 2 arguments' do
          expect { subject.observe({}, 2) }.not_to raise_exception
        end
      end
    end

    describe '#gauge' do
      subject { described_class.gauge(:gauge, 'doc') }

      describe '#set' do
        it 'successfully calls #set with 2 arguments' do
          expect { subject.set({}, 1) }.not_to raise_exception
        end
      end
    end

    describe '#histogram' do
      subject { described_class.histogram(:histogram, 'doc') }

      describe '#observe' do
        it 'successfully calls #observe with 2 arguments' do
          expect { subject.observe({}, 2) }.not_to raise_exception
        end
      end
    end
  end

  context 'prometheus metrics disabled' do
    before do
      allow(described_class).to receive(:prometheus_metrics_enabled?).and_return(false)
    end

    it_behaves_like 'prometheus metrics API'

    describe '#null_metric' do
      subject { described_class.send(:provide_metric, :test) }

      it { is_expected.to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#counter' do
      subject { described_class.counter(:counter, 'doc') }

      it { is_expected.to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#summary' do
      subject { described_class.summary(:summary, 'doc') }

      it { is_expected.to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#gauge' do
      subject { described_class.gauge(:gauge, 'doc') }

      it { is_expected.to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#histogram' do
      subject { described_class.histogram(:histogram, 'doc') }

      it { is_expected.to be_a(Gitlab::Metrics::NullMetric) }
    end
  end

  context 'prometheus metrics enabled' do
    let(:metrics_multiproc_dir) { Dir.mktmpdir }

    before do
      stub_const('Prometheus::Client::Multiprocdir', metrics_multiproc_dir)
      allow(described_class).to receive(:prometheus_metrics_enabled?).and_return(true)
    end

    it_behaves_like 'prometheus metrics API'

    describe '#null_metric' do
      subject { described_class.send(:provide_metric, :test) }

      it { is_expected.to be_nil }
    end

    describe '#counter' do
      subject { described_class.counter(:name, 'doc') }

      it { is_expected.not_to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#summary' do
      subject { described_class.summary(:name, 'doc') }

      it { is_expected.not_to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#gauge' do
      subject { described_class.gauge(:name, 'doc') }

      it { is_expected.not_to be_a(Gitlab::Metrics::NullMetric) }
    end

    describe '#histogram' do
      subject { described_class.histogram(:name, 'doc') }

      it { is_expected.not_to be_a(Gitlab::Metrics::NullMetric) }
    end
  end
end

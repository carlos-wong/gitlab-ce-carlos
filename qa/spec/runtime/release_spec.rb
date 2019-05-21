# frozen_string_literal: true

describe QA::Runtime::Release do
  context 'when release version has extension strategy' do
    let(:strategy) { spy('strategy') }

    before do
      stub_const('QA::CE::Strategy', strategy)
      stub_const('QA::EE::Strategy', strategy)
    end

    describe '#version' do
      it 'return either CE or EE version' do
        expect(subject.version).to eq(:CE).or eq(:EE)
      end
    end

    describe '#strategy' do
      it 'return the strategy constant' do
        expect(subject.strategy).to eq strategy
      end
    end

    describe 'delegated class methods' do
      it 'delegates all calls to strategy class' do
        described_class.some_method(1, 2)

        expect(strategy).to have_received(:some_method)
          .with(1, 2)
      end
    end
  end

  context 'when release version does not have extension strategy' do
    before do
      allow_any_instance_of(described_class)
        .to receive(:version).and_return('something')
    end

    describe '#strategy' do
      it 'raises error' do
        expect { subject.strategy }.to raise_error(LoadError)
      end
    end

    describe 'delegated class methods' do
      it 'raises error' do
        expect { described_class.some_method(2, 3) }.to raise_error(LoadError)
      end
    end
  end
end

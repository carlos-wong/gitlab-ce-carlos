require 'spec_helper'

describe Gitlab::Ci::Pipeline::Expression::Lexeme::Equals do
  let(:left) { double('left') }
  let(:right) { double('right') }

  describe '.build' do
    context 'with non-evaluable operands' do
      it 'creates a new instance of the token' do
        expect { described_class.build('==', left, right) }
          .to raise_error Gitlab::Ci::Pipeline::Expression::Lexeme::Operator::OperatorError
      end
    end

    context 'with evaluable operands' do
      it 'creates a new instance of the token' do
        allow(left).to receive(:evaluate).and_return('my-string')
        allow(right).to receive(:evaluate).and_return('my-string')

        expect(described_class.build('==', left, right))
          .to be_a(described_class)
      end
    end
  end

  describe '.type' do
    it 'is an operator' do
      expect(described_class.type).to eq :operator
    end
  end

  describe '.precedence' do
    it 'has a precedence' do
      expect(described_class.precedence).to be_an Integer
    end
  end

  describe '#evaluate' do
    let(:operator) { described_class.new(left, right) }

    subject { operator.evaluate }

    before do
      allow(left).to receive(:evaluate).and_return(left_value)
      allow(right).to receive(:evaluate).and_return(right_value)
    end

    context 'when left and right are equal' do
      where(:left_value, :right_value) do
        [%w(string string)]
      end

      with_them do
        it { is_expected.to eq(true) }
      end
    end

    context 'when left and right are not equal' do
      where(:left_value, :right_value) do
        ['one string', 'two string'].permutation(2).to_a
      end

      with_them do
        it { is_expected.to eq(false) }
      end
    end
  end
end

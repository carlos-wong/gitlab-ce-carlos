# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Integrations::Field do
  subject(:field) { described_class.new(**attrs) }

  let(:attrs) { { name: nil, integration_class: test_integration } }
  let(:test_integration) do
    Class.new(Integration) do
      def self.default_placeholder
        'my placeholder'
      end
    end
  end

  describe '#initialize' do
    it 'sets type password for secret names' do
      attrs[:name] = 'token'
      attrs[:type] = 'text'

      expect(field[:type]).to eq('password')
    end

    it 'uses the given type for other names' do
      attrs[:name] = 'field'
      attrs[:type] = 'select'

      expect(field[:type]).to eq('select')
    end

    it 'raises an error if an invalid attribute is given' do
      attrs[:foo] = 'foo'
      attrs[:bar] = 'bar'
      attrs[:name] = 'name'
      attrs[:type] = 'text'

      expect { field }.to raise_error(ArgumentError, "Invalid attributes [:foo, :bar]")
    end

    it 'raises an error if an invalid type is given' do
      attrs[:type] = 'other'

      expect { field }.to raise_error(ArgumentError, 'Invalid type "other"')
    end
  end

  describe '#name' do
    before do
      attrs[:name] = :foo
    end

    it 'is stringified' do
      expect(field.name).to eq 'foo'
      expect(field[:name]).to eq 'foo'
    end

    context 'when not set' do
      before do
        attrs.delete(:name)
      end

      it 'complains' do
        expect { field }.to raise_error(ArgumentError)
      end
    end
  end

  described_class::ATTRIBUTES.each do |name|
    describe "##{name}" do
      it "responds to #{name}" do
        expect(field).to be_respond_to(name)
      end

      context 'when not set' do
        before do
          attrs.delete(name)
        end

        let(:have_correct_default) do
          case name
          when :api_only
            be false
          when :type
            eq 'text'
          else
            be_nil
          end
        end

        it 'has the correct default' do
          expect(field[name]).to have_correct_default
          expect(field.public_send(name)).to have_correct_default
        end
      end

      context 'when set to a static value' do
        before do
          attrs[name] = :known
        end

        it 'is known' do
          next if name == :type

          expect(field[name]).to eq(:known)
          expect(field.public_send(name)).to eq(:known)
        end
      end

      context 'when set to a dynamic value' do
        it 'is computed' do
          next if name == :type

          attrs[name] = -> { Time.current }
          start = Time.current

          travel_to(start + 1.minute) do
            expect(field[name]).to be_after(start)
            expect(field.public_send(name)).to be_after(start)
          end
        end

        it 'is executed in the class scope' do
          next if name == :type

          attrs[name] = -> { default_placeholder }

          expect(field[name]).to eq('my placeholder')
          expect(field.public_send(name)).to eq('my placeholder')
        end
      end
    end
  end

  described_class::BOOLEAN_ATTRIBUTES.each do |name|
    describe "##{name}?" do
      it 'returns true if the value is truthy' do
        attrs[name] = ''
        expect(field.public_send("#{name}?")).to be(true)
      end

      it 'returns false if the value is falsey' do
        attrs[name] = nil
        expect(field.public_send("#{name}?")).to be(false)
      end
    end
  end

  described_class::TYPES.each do |type|
    describe "##{type}?" do
      it 'returns true if the type matches' do
        attrs[:type] = type
        expect(field.public_send("#{type}?")).to be(true)
      end

      it 'returns false if the type does not match' do
        attrs[:type] = (described_class::TYPES - [type]).first
        expect(field.public_send("#{type}?")).to be(false)
      end
    end
  end

  describe '#secret?' do
    context 'when empty' do
      it { is_expected.not_to be_secret }
    end

    context 'when a secret field' do
      before do
        attrs[:type] = 'password'
      end

      it { is_expected.to be_secret }
    end

    %w[token api_token api_key secret_key secret_sauce password passphrase].each do |name|
      context "when named #{name}" do
        before do
          attrs[:name] = name
        end

        it { is_expected.to be_secret }
      end
    end

    context "when named url" do
      before do
        attrs[:name] = :url
      end

      it { is_expected.not_to be_secret }
    end
  end
end

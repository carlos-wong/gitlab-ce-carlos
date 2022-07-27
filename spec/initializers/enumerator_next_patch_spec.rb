# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Enumerator#next patch fix' do
  describe 'Enumerator' do
    RSpec::Matchers.define :contain_unique_method_calls_in_order do |expected|
      attr_reader :actual

      match do |actual|
        @actual_err = actual
        regexps = expected.map { |method_name| { name: method_name, regexp: make_regexp(method_name) } }
        @actual = actual.backtrace.filter_map do |line|
          regexp = regexps.find { |r| r[:regexp].match? line }

          regexp[:name] if regexp
        end

        expected == @actual
      end

      diffable

      failure_message do
        "#{super()}\n\nFull error backtrace:\n  #{@actual_err.backtrace.join("\n  ")}"
      end

      private

      def make_regexp(method_name)
        Regexp.new("/spec/initializers/enumerator_next_patch_spec\\.rb:[0-9]+:in `#{method_name}'$")
      end
    end

    def have_been_raised_by_next_and_not_fixed_up
      contain_unique_method_calls_in_order %w(call_enum_method)
    end

    def have_been_raised_by_enum_object_and_fixed_up
      contain_unique_method_calls_in_order %w(make_error call_enum_method)
    end

    def have_been_raised_by_nested_next_and_fixed_up
      contain_unique_method_calls_in_order %w(call_nested_next call_enum_method)
    end

    methods = [
      {
        name: 'next',
        expected_value: 'Test value'
      },
      {
        name: 'next_values',
        expected_value: ['Test value']
      },
      {
        name: 'peek',
        expected_value: 'Test value'
      },
      {
        name: 'peek_values',
        expected_value: ['Test value']
      }
    ]

    methods.each do |method|
      describe "##{method[:name]}" do
        def call_enum_method
          enumerator.send(method_name)
        end

        let(:method_name) { method[:name] }

        subject { call_enum_method }

        describe 'normal yield' do
          let(:enumerator) { Enumerator.new { |yielder| yielder << 'Test value' } }

          it 'returns yielded value' do
            is_expected.to eq(method[:expected_value])
          end
        end

        describe 'end of iteration' do
          let(:enumerator) { Enumerator.new { |_| } }

          it 'does not fix up StopIteration' do
            expect { subject }.to raise_error do |err|
              expect(err).to be_a(StopIteration)
              expect(err).to have_been_raised_by_next_and_not_fixed_up
            end
          end

          context 'nested enum object' do
            def call_nested_next
              nested_enumerator.next
            end

            let(:nested_enumerator) { Enumerator.new { |_| } }
            let(:enumerator) { Enumerator.new { |yielder| yielder << call_nested_next } }

            it 'fixes up StopIteration thrown by another instance of #next' do
              expect { subject }.to raise_error do |err|
                expect(err).to be_a(StopIteration)
                expect(err).to have_been_raised_by_nested_next_and_fixed_up
              end
            end
          end
        end

        describe 'arguments error' do
          def call_enum_method
            enumerator.send(method_name, 'extra argument')
          end

          let(:enumerator) { Enumerator.new { |_| } }

          it 'does not fix up ArgumentError' do
            expect { subject }.to raise_error do |err|
              expect(err).to be_a(ArgumentError)
              expect(err).to have_been_raised_by_next_and_not_fixed_up
            end
          end
        end

        describe 'error' do
          let(:enumerator) { Enumerator.new { |_| raise error } }
          let(:error) { make_error }

          it 'fixes up StopIteration' do
            def make_error
              StopIteration.new.tap { |err| err.set_backtrace(caller) }
            end

            expect { subject }.to raise_error do |err|
              expect(err).to be(error)
              expect(err).to have_been_raised_by_enum_object_and_fixed_up
            end
          end

          it 'fixes up ArgumentError' do
            def make_error
              ArgumentError.new.tap { |err| err.set_backtrace(caller) }
            end

            expect { subject }.to raise_error do |err|
              expect(err).to be(error)
              expect(err).to have_been_raised_by_enum_object_and_fixed_up
            end
          end

          it 'adds backtrace from other errors' do
            def make_error
              StandardError.new('This is a test').tap { |err| err.set_backtrace(caller) }
            end

            expect { subject }.to raise_error do |err|
              expect(err).to be(error)
              expect(err).to have_been_raised_by_enum_object_and_fixed_up
              expect(err.message).to eq('This is a test')
            end
          end
        end
      end
    end
  end
end

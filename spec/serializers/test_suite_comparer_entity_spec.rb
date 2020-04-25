# frozen_string_literal: true

require 'spec_helper'

describe TestSuiteComparerEntity do
  include TestReportsHelper

  let(:entity) { described_class.new(comparer) }
  let(:comparer) { Gitlab::Ci::Reports::TestSuiteComparer.new(name, base_suite, head_suite) }
  let(:name) { 'rpsec' }
  let(:base_suite) { Gitlab::Ci::Reports::TestSuite.new(name) }
  let(:head_suite) { Gitlab::Ci::Reports::TestSuite.new(name) }
  let(:test_case_success) { create_test_case_rspec_success }
  let(:test_case_failed) { create_test_case_rspec_failed }
  let(:test_case_error) { create_test_case_rspec_error }

  describe '#as_json' do
    subject { entity.as_json }

    context 'when head suite has a newly failed test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_failed)
      end

      it 'contains correct compared test suite details' do
        expect(subject[:name]).to eq(name)
        expect(subject[:status]).to eq('failed')
        expect(subject[:summary]).to include(total: 1, resolved: 0, failed: 1, errored: 0)
        subject[:new_failures].first.tap do |new_failure|
          expect(new_failure[:status]).to eq(test_case_failed.status)
          expect(new_failure[:name]).to eq(test_case_failed.name)
          expect(new_failure[:execution_time]).to eq(test_case_failed.execution_time)
          expect(new_failure[:system_output]).to eq(test_case_failed.system_output)
        end
        expect(subject[:resolved_failures]).to be_empty
        expect(subject[:existing_failures]).to be_empty
      end
    end

    context 'when head suite has a new error test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_error)
      end

      it 'contains correct compared test suite details' do
        expect(subject[:name]).to eq(name)
        expect(subject[:status]).to eq('failed')
        expect(subject[:summary]).to include(total: 1, resolved: 0, failed: 0, errored: 1)
        subject[:new_errors].first.tap do |new_error|
          expect(new_error[:status]).to eq(test_case_error.status)
          expect(new_error[:name]).to eq(test_case_error.name)
          expect(new_error[:execution_time]).to eq(test_case_error.execution_time)
          expect(new_error[:system_output]).to eq(test_case_error.system_output)
        end
        expect(subject[:resolved_failures]).to be_empty
        expect(subject[:existing_failures]).to be_empty
      end
    end

    context 'when head suite still has a failed test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_failed)
      end

      it 'contains correct compared test suite details' do
        expect(subject[:name]).to eq(name)
        expect(subject[:status]).to eq('failed')
        expect(subject[:summary]).to include(total: 1, resolved: 0, failed: 1, errored: 0)
        expect(subject[:new_failures]).to be_empty
        expect(subject[:resolved_failures]).to be_empty
        subject[:existing_failures].first.tap do |existing_failure|
          expect(existing_failure[:status]).to eq(test_case_failed.status)
          expect(existing_failure[:name]).to eq(test_case_failed.name)
          expect(existing_failure[:execution_time]).to eq(test_case_failed.execution_time)
          expect(existing_failure[:system_output]).to eq(test_case_failed.system_output)
        end
      end
    end

    context 'when head suite has a success test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_success)
      end

      it 'contains correct compared test suite details' do
        expect(subject[:name]).to eq(name)
        expect(subject[:status]).to eq('success')
        expect(subject[:summary]).to include(total: 1, resolved: 1, failed: 0, errored: 0)
        expect(subject[:new_failures]).to be_empty
        subject[:resolved_failures].first.tap do |resolved_failure|
          expect(resolved_failure[:status]).to eq(test_case_success.status)
          expect(resolved_failure[:name]).to eq(test_case_success.name)
          expect(resolved_failure[:execution_time]).to eq(test_case_success.execution_time)
          expect(resolved_failure[:system_output]).to eq(test_case_success.system_output)
        end
        expect(subject[:existing_failures]).to be_empty
      end
    end

    context 'limits amount of tests returned' do
      before do
        stub_const('TestSuiteComparerEntity::DEFAULT_MAX_TESTS', 2)
        stub_const('TestSuiteComparerEntity::DEFAULT_MIN_TESTS', 1)
      end

      context 'prefers new over existing and resolved' do
        before do
          3.times { add_new_failure }
          3.times { add_new_error }
          3.times { add_existing_failure }
          3.times { add_existing_error }
          3.times { add_resolved_failure }
          3.times { add_resolved_error }
        end

        it 'returns 2 of each new category, and 1 of each resolved and existing' do
          expect(subject[:summary]).to include(total: 18, resolved: 6, failed: 6, errored: 6)
          expect(subject[:new_failures].count).to eq(2)
          expect(subject[:new_errors].count).to eq(2)
          expect(subject[:existing_failures].count).to eq(1)
          expect(subject[:existing_errors].count).to eq(1)
          expect(subject[:resolved_failures].count).to eq(1)
          expect(subject[:resolved_errors].count).to eq(1)
        end
      end

      context 'prefers existing over resolved' do
        before do
          3.times { add_existing_failure }
          3.times { add_existing_error }
          3.times { add_resolved_failure }
          3.times { add_resolved_error }
        end

        it 'returns 2 of each existing category, and 1 of each resolved' do
          expect(subject[:summary]).to include(total: 12, resolved: 6, failed: 3, errored: 3)
          expect(subject[:new_failures].count).to eq(0)
          expect(subject[:new_errors].count).to eq(0)
          expect(subject[:existing_failures].count).to eq(2)
          expect(subject[:existing_errors].count).to eq(2)
          expect(subject[:resolved_failures].count).to eq(1)
          expect(subject[:resolved_errors].count).to eq(1)
        end
      end

      context 'limits amount of resolved' do
        before do
          3.times { add_resolved_failure }
          3.times { add_resolved_error }
        end

        it 'returns 2 of each resolved category' do
          expect(subject[:summary]).to include(total: 6, resolved: 6, failed: 0, errored: 0)
          expect(subject[:new_failures].count).to eq(0)
          expect(subject[:new_errors].count).to eq(0)
          expect(subject[:existing_failures].count).to eq(0)
          expect(subject[:existing_errors].count).to eq(0)
          expect(subject[:resolved_failures].count).to eq(2)
          expect(subject[:resolved_errors].count).to eq(2)
        end
      end

      private

      def add_new_failure
        failed_case = create_test_case_rspec_failed(SecureRandom.hex)
        head_suite.add_test_case(failed_case)
      end

      def add_new_error
        error_case = create_test_case_rspec_error(SecureRandom.hex)
        head_suite.add_test_case(error_case)
      end

      def add_existing_failure
        failed_case = create_test_case_rspec_failed(SecureRandom.hex)
        base_suite.add_test_case(failed_case)
        head_suite.add_test_case(failed_case)
      end

      def add_existing_error
        error_case = create_test_case_rspec_error(SecureRandom.hex)
        base_suite.add_test_case(error_case)
        head_suite.add_test_case(error_case)
      end

      def add_resolved_failure
        case_name = SecureRandom.hex
        failed_case = create_test_case_java_failed(case_name)
        success_case = create_test_case_java_success(case_name)
        base_suite.add_test_case(failed_case)
        head_suite.add_test_case(success_case)
      end

      def add_resolved_error
        case_name = SecureRandom.hex
        error_case = create_test_case_java_error(case_name)
        success_case = create_test_case_java_success(case_name)
        base_suite.add_test_case(error_case)
        head_suite.add_test_case(success_case)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Reports::TestSuiteComparer do
  include TestReportsHelper

  let(:comparer) { described_class.new(name, base_suite, head_suite) }
  let(:name) { 'rpsec' }
  let(:base_suite) { Gitlab::Ci::Reports::TestSuite.new(name) }
  let(:head_suite) { Gitlab::Ci::Reports::TestSuite.new(name) }
  let(:test_case_success) { create_test_case_java_success }
  let(:test_case_failed) { create_test_case_java_failed }
  let(:test_case_error) { create_test_case_java_error }

  describe '#new_failures' do
    subject { comparer.new_failures }

    context 'when head sutie has a newly failed test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_failed)
      end

      it 'returns the failed test case' do
        is_expected.to eq([test_case_failed])
      end
    end

    context 'when head sutie still has a failed test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_failed)
      end

      it 'does not return the failed test case' do
        is_expected.to be_empty
      end
    end

    context 'when head sutie has a success test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_success)
      end

      it 'does not return the failed test case' do
        is_expected.to be_empty
      end
    end
  end

  describe '#existing_failures' do
    subject { comparer.existing_failures }

    context 'when head sutie has a newly failed test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_failed)
      end

      it 'returns the failed test case' do
        is_expected.to be_empty
      end
    end

    context 'when head sutie still has a failed test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_failed)
      end

      it 'does not return the failed test case' do
        is_expected.to eq([test_case_failed])
      end
    end

    context 'when head sutie has a success test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_success)
      end

      it 'does not return the failed test case' do
        is_expected.to be_empty
      end
    end
  end

  describe '#resolved_failures' do
    subject { comparer.resolved_failures }

    context 'when head sutie has a newly failed test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_failed)
      end

      it 'returns the failed test case' do
        is_expected.to be_empty
      end

      it 'returns the correct resolved count' do
        expect(comparer.resolved_count).to eq(0)
      end
    end

    context 'when head sutie still has a failed test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_failed)
      end

      it 'does not return the failed test case' do
        is_expected.to be_empty
      end

      it 'returns the correct resolved count' do
        expect(comparer.resolved_count).to eq(0)
      end
    end

    context 'when head sutie has a success test case which failed in base' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_success)
      end

      it 'does not return the resolved test case' do
        is_expected.to eq([test_case_success])
      end

      it 'returns the correct resolved count' do
        expect(comparer.resolved_count).to eq(1)
      end
    end
  end

  describe '#new_errors' do
    subject { comparer.new_errors }

    context 'when head suite has a new error test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_error)
      end

      it 'returns the error test case' do
        is_expected.to eq([test_case_error])
      end
    end

    context 'when head suite still has an error test case which errored in base' do
      before do
        base_suite.add_test_case(test_case_error)
        head_suite.add_test_case(test_case_error)
      end

      it 'does not return the error test case' do
        is_expected.to be_empty
      end
    end

    context 'when head suite has a success test case which errored in base' do
      before do
        base_suite.add_test_case(test_case_error)
        head_suite.add_test_case(test_case_success)
      end

      it 'does not return the error test case' do
        is_expected.to be_empty
      end
    end
  end

  describe '#existing_errors' do
    subject { comparer.existing_errors }

    context 'when head suite has a new error test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_error)
      end

      it 'does not return the error test case' do
        is_expected.to be_empty
      end
    end

    context 'when head suite still has an error test case which errored in base' do
      before do
        base_suite.add_test_case(test_case_error)
        head_suite.add_test_case(test_case_error)
      end

      it 'returns the error test case' do
        is_expected.to eq([test_case_error])
      end
    end

    context 'when head suite has a success test case which errored in base' do
      before do
        base_suite.add_test_case(test_case_error)
        head_suite.add_test_case(test_case_success)
      end

      it 'does not return the error test case' do
        is_expected.to be_empty
      end
    end
  end

  describe '#resolved_errors' do
    subject { comparer.resolved_errors }

    context 'when head suite has a new error test case which does not exist in base' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_error)
      end

      it 'does not return the error test case' do
        is_expected.to be_empty
      end

      it 'returns the correct resolved count' do
        expect(comparer.resolved_count).to eq(0)
      end
    end

    context 'when head suite still has an error test case which errored in base' do
      before do
        base_suite.add_test_case(test_case_error)
        head_suite.add_test_case(test_case_error)
      end

      it 'does not return the error test case' do
        is_expected.to be_empty
      end

      it 'returns the correct resolved count' do
        expect(comparer.resolved_count).to eq(0)
      end
    end

    context 'when head suite has a success test case which errored in base' do
      before do
        base_suite.add_test_case(test_case_error)
        head_suite.add_test_case(test_case_success)
      end

      it 'returns the resolved test case' do
        is_expected.to eq([test_case_success])
      end

      it 'returns the correct resolved count' do
        expect(comparer.resolved_count).to eq(1)
      end
    end
  end

  describe '#total_count' do
    subject { comparer.total_count }

    before do
      head_suite.add_test_case(test_case_success)
    end

    it 'returns the total test counts in head suite' do
      is_expected.to eq(1)
    end
  end

  describe '#failed_count' do
    subject { comparer.failed_count }

    context 'when there are a new failure and an existing failure' do
      let(:test_case_1_success) { create_test_case_rspec_success }
      let(:test_case_1_failed) { create_test_case_rspec_failed }
      let(:test_case_2_failed) { create_test_case_rspec_failed('case2') }

      before do
        base_suite.add_test_case(test_case_1_success)
        base_suite.add_test_case(test_case_2_failed)
        head_suite.add_test_case(test_case_1_failed)
        head_suite.add_test_case(test_case_2_failed)
      end

      it 'returns the correct count' do
        is_expected.to eq(2)
      end
    end

    context 'when there is a new failure' do
      before do
        base_suite.add_test_case(test_case_success)
        head_suite.add_test_case(test_case_failed)
      end

      it 'returns the correct count' do
        is_expected.to eq(1)
      end
    end

    context 'when there is an existing failure' do
      before do
        base_suite.add_test_case(test_case_failed)
        head_suite.add_test_case(test_case_failed)
      end

      it 'returns the correct count' do
        is_expected.to eq(1)
      end
    end
  end

  describe '#total_status' do
    subject { comparer.total_status }

    context 'when all test cases in head suite are success' do
      before do
        head_suite.add_test_case(test_case_success)
      end

      it 'returns the total status in head suite' do
        is_expected.to eq(Gitlab::Ci::Reports::TestCase::STATUS_SUCCESS)
      end
    end

    context 'when there is a failed test case in head suite' do
      before do
        head_suite.add_test_case(test_case_failed)
      end

      it 'returns the total status in head suite as failed' do
        is_expected.to eq(Gitlab::Ci::Reports::TestCase::STATUS_FAILED)
      end
    end

    context 'when there is an error test case in head suite' do
      before do
        head_suite.add_test_case(test_case_error)
      end

      it 'returns the total status in head suite as failed' do
        is_expected.to eq(Gitlab::Ci::Reports::TestCase::STATUS_FAILED)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe IncidentManagement::ProjectIncidentManagementSetting do
  let_it_be(:project) { create(:project, :repository, create_templates: :issue) }

  describe 'Associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'Validations' do
    describe 'validate issue_template_exists' do
      subject { build(:project_incident_management_setting, project: project) }

      context 'with create_issue enabled' do
        before do
          subject.create_issue = true
        end

        context 'with valid issue_template_key' do
          before do
            subject.issue_template_key = 'bug'
          end

          it { is_expected.to be_valid }
        end

        context 'with empty issue_template_key' do
          before do
            subject.issue_template_key = ''
          end

          it { is_expected.to be_valid }
        end

        context 'with nil issue_template_key' do
          before do
            subject.issue_template_key = nil
          end

          it { is_expected.to be_valid }
        end

        context 'with invalid issue_template_key' do
          before do
            subject.issue_template_key = 'unknown'
          end

          it { is_expected.to be_invalid }

          it 'returns error' do
            subject.valid?

            expect(subject.errors[:issue_template_key]).to eq(['not found'])
          end
        end
      end

      context 'with create_issue disabled' do
        before do
          subject.create_issue = false
        end

        context 'with unknown issue_template_key' do
          before do
            subject.issue_template_key = 'unknown'
          end

          it { is_expected.to be_valid }
        end
      end
    end
  end

  describe '#issue_template_content' do
    subject { build(:project_incident_management_setting, project: project) }

    shared_examples 'no content' do
      it 'returns no content' do
        expect(subject.issue_template_content).to be_nil
      end
    end

    context 'with valid issue_template_key' do
      before do
        subject.issue_template_key = 'bug'
      end

      it 'returns issue content' do
        expect(subject.issue_template_content).to eq('something valid')
      end
    end

    context 'with unknown issue_template_key' do
      before do
        subject.issue_template_key = 'unknown'
      end

      it_behaves_like 'no content'
    end

    context 'without issue_template_key' do
      before do
        subject.issue_template_key = nil
      end

      it_behaves_like 'no content'
    end
  end
end

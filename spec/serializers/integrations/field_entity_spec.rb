# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::FieldEntity do
  let(:request) { EntityRequest.new(integration: integration) }

  subject { described_class.new(field, request: request, integration: integration).as_json }

  before do
    allow(request).to receive(:integration).and_return(integration)
  end

  describe '#as_json' do
    context 'with Jira integration' do
      let(:integration) { create(:jira_integration) }

      context 'with field with type text' do
        let(:field) { integration_field('username') }

        it 'exposes correct attributes' do
          expected_hash = {
            section: 'connection',
            type: 'text',
            name: 'username',
            title: 'Username or Email',
            placeholder: nil,
            help: 'Use a username for server version and an email for cloud version.',
            required: true,
            choices: nil,
            value: 'jira_username',
            checkbox_label: nil
          }

          is_expected.to eq(expected_hash)
        end
      end

      context 'with field with type password' do
        let(:field) { integration_field('password') }

        it 'exposes correct attributes but hides password' do
          expected_hash = {
            section: 'connection',
            type: 'password',
            name: 'password',
            title: 'Enter new password or API token',
            placeholder: nil,
            help: 'Leave blank to use your current password or API token.',
            required: true,
            choices: nil,
            value: 'true',
            checkbox_label: nil
          }

          is_expected.to eq(expected_hash)
        end
      end
    end

    context 'with EmailsOnPush integration' do
      let(:integration) { create(:emails_on_push_integration, send_from_committer_email: '1') }

      context 'with field with type checkbox' do
        let(:field) { integration_field('send_from_committer_email') }

        it 'exposes correct attributes and casts value to Boolean' do
          expected_hash = {
            section: nil,
            type: 'checkbox',
            name: 'send_from_committer_email',
            title: 'Send from committer',
            placeholder: nil,
            required: nil,
            choices: nil,
            value: 'true',
            checkbox_label: nil
          }

          is_expected.to include(expected_hash)
          expect(subject[:help]).to include(
            "Send notifications from the committer's email address if the domain " \
            "matches the domain used by your GitLab instance"
          )
        end
      end

      context 'with field with type select' do
        let(:field) { integration_field('branches_to_be_notified') }

        it 'exposes correct attributes' do
          expected_hash = {
            section: nil,
            type: 'select',
            name: 'branches_to_be_notified',
            title: 'Branches for which notifications are to be sent',
            placeholder: nil,
            required: nil,
            choices: [
              ['All branches', 'all'],
              ['Default branch', 'default'],
              ['Protected branches', 'protected'],
              ['Default branch and protected branches', 'default_and_protected']
            ],
            help: nil,
            value: nil,
            checkbox_label: nil
          }

          is_expected.to eq(expected_hash)
        end
      end
    end
  end

  def integration_field(name)
    integration.form_fields.find { |f| f[:name] == name }
  end
end

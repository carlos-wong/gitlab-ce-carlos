# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Email::Handler::CreateIssueHandler do
  include_context :email_shared_context
  it_behaves_like :reply_processing_shared_examples

  before do
    stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.adventuretime.ooo")
    stub_config_setting(host: 'localhost')
  end

  let(:email_raw) { email_fixture('emails/valid_new_issue.eml') }
  let(:namespace) { create(:namespace, path: 'gitlabhq') }

  let!(:project)  { create(:project, :public, namespace: namespace, path: 'gitlabhq') }
  let!(:user) do
    create(
      :user,
      email: 'jake@adventuretime.ooo',
      incoming_email_token: 'auth_token'
    )
  end

  context "when email key" do
    let(:mail) { Mail::Message.new(email_raw) }

    it "matches the new format" do
      handler = described_class.new(mail, "gitlabhq-gitlabhq-#{project.project_id}-#{user.incoming_email_token}-issue")

      expect(handler.instance_variable_get(:@project_id)).to eq project.project_id
      expect(handler.instance_variable_get(:@project_slug)).to eq project.full_path_slug
      expect(handler.instance_variable_get(:@incoming_email_token)).to eq user.incoming_email_token
      expect(handler.can_handle?).to be_truthy
    end

    it "matches the legacy format" do
      handler = described_class.new(mail, "h5bp/html5-boilerplate+#{user.incoming_email_token}")

      expect(handler.instance_variable_get(:@project_path)).to eq 'h5bp/html5-boilerplate'
      expect(handler.instance_variable_get(:@incoming_email_token)).to eq user.incoming_email_token
      expect(handler.can_handle?).to be_truthy
    end

    it "doesn't match either format" do
      handler = described_class.new(mail, "h5bp-html5-boilerplate+something+invalid")

      expect(handler.can_handle?).to be_falsey
    end
  end

  context "when everything is fine" do
    shared_examples "a new issue" do
      it "creates a new issue" do
        setup_attachment

        expect { receiver.execute }.to change { project.issues.count }.by(1)
        issue = project.issues.last

        expect(issue.author).to eq(user)
        expect(issue.title).to eq('New Issue by email')
        expect(issue.description).to include('reply by email')
        expect(issue.description).to include(markdown)
      end
    end

    it_behaves_like "a new issue"

    context "creates a new issue with legacy email address" do
      let(:email_raw) { fixture_file('emails/valid_new_issue_legacy.eml') }

      it_behaves_like "a new issue"
    end

    context "when the reply is blank" do
      let(:email_raw) { email_fixture("emails/valid_new_issue_empty.eml") }

      it "creates a new issue" do
        expect { receiver.execute }.to change { project.issues.count }.by(1)
        issue = project.issues.last

        expect(issue.author).to eq(user)
        expect(issue.title).to eq('New Issue by email')
        expect(issue.description).to eq('')
      end
    end

    context "when there are quotes in email" do
      let(:email_raw) { email_fixture("emails/valid_new_issue_with_quote.eml") }

      it "creates a new issue" do
        expect { receiver.execute }.to change { project.issues.count }.by(1)
        issue = project.issues.last

        expect(issue.author).to eq(user)
        expect(issue.title).to eq('New Issue by email')
        expect(issue.description).to include('reply by email')
        expect(issue.description).to include('> this is a quote')
      end
    end
  end

  context "something is wrong" do
    context "when the issue could not be saved" do
      before do
        allow_any_instance_of(Issue).to receive(:persisted?).and_return(false)
      end

      it "raises an InvalidIssueError" do
        expect { receiver.execute }.to raise_error(Gitlab::Email::InvalidIssueError)
      end
    end

    context "when we can't find the incoming_email_token" do
      let(:email_raw) { email_fixture("emails/wrong_issue_incoming_email_token.eml") }

      it "raises an UserNotFoundError" do
        expect { receiver.execute }.to raise_error(Gitlab::Email::UserNotFoundError)
      end
    end

    context "when project is private" do
      let(:project) { create(:project, :private, namespace: namespace) }

      it "raises a ProjectNotFound if the user is not a member" do
        expect { receiver.execute }.to raise_error(Gitlab::Email::ProjectNotFound)
      end
    end
  end

  def email_fixture(path)
    fixture_file(path).gsub('project_id', project.project_id.to_s)
  end
end

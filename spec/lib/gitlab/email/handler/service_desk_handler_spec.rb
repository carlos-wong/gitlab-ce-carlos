# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Email::Handler::ServiceDeskHandler do
  include_context :email_shared_context

  before do
    stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.adventuretime.ooo")
    stub_config_setting(host: 'localhost')
  end

  let(:email_raw) { email_fixture('emails/service_desk.eml') }
  let(:author_email) { 'jake@adventuretime.ooo' }
  let(:message_id) { 'CADkmRc+rNGAGGbV2iE5p918UVy4UyJqVcXRO2=otppgzduJSg@mail.gmail.com' }

  let_it_be(:group) { create(:group, :private, name: "email") }

  let(:expected_description) do
    "Service desk stuff!\n\n```\na = b\n```\n\n`/label ~label1`\n`/assign @user1`\n`/close`\n![image](uploads/image.png)"
  end

  context 'service desk is enabled for the project' do
    let_it_be(:project) { create(:project, :repository, :private, group: group, path: 'test', service_desk_enabled: true) }

    before do
      allow(Gitlab::ServiceDesk).to receive(:supported?).and_return(true)
    end

    shared_examples 'a new issue request' do
      before do
        setup_attachment
      end

      it 'creates a new issue' do
        expect { receiver.execute }.to change { Issue.count }.by(1)

        new_issue = Issue.last

        expect(new_issue.author).to eql(User.support_bot)
        expect(new_issue.confidential?).to be true
        expect(new_issue.all_references.all).to be_empty
        expect(new_issue.title).to eq("The message subject! @all")
        expect(new_issue.description).to eq(expected_description.strip)
        expect(new_issue.email&.email_message_id).to eq(message_id)
      end

      it 'creates an issue_email_participant' do
        receiver.execute
        new_issue = Issue.last

        expect(new_issue.issue_email_participants.first.email).to eq(author_email)
      end

      it 'sends thank you email' do
        expect { receiver.execute }.to have_enqueued_job.on_queue('mailers')
      end

      it 'adds metric events for incoming and reply emails' do
        metric_transaction = double('Gitlab::Metrics::WebTransaction', increment: true, observe: true)
        allow(::Gitlab::Metrics::BackgroundTransaction).to receive(:current).and_return(metric_transaction)
        expect(metric_transaction).to receive(:add_event).with(:receive_email_service_desk, { handler: 'Gitlab::Email::Handler::ServiceDeskHandler' })
        expect(metric_transaction).to receive(:add_event).with(:service_desk_thank_you_email)

        receiver.execute
      end
    end

    context 'when everything is fine' do
      it_behaves_like 'a new issue request'

      context 'with legacy incoming email address' do
        let(:email_raw) { fixture_file('emails/service_desk_legacy.eml') }

        it_behaves_like 'a new issue request'
      end

      context 'when replying to issue creation email' do
        def receive_reply
          reply_email_raw = email_fixture('emails/service_desk_reply.eml')

          second_receiver = Gitlab::Email::Receiver.new(reply_email_raw)
          second_receiver.execute
        end

        context 'when an issue with message_id has been found' do
          before do
            receiver.execute
          end

          subject do
            receive_reply
          end

          it 'does not create an additional issue' do
            expect { subject }.not_to change { Issue.count }
          end

          it 'adds a comment to the created issue' do
            subject

            notes = Issue.last.notes
            new_note = notes.first

            expect(notes.count).to eq(1)
            expect(new_note.note).to eq("Service desk reply!\n\n`/label ~label2`")
            expect(new_note.author).to eql(User.support_bot)
          end

          it 'does not send thank you email' do
            expect(Notify).not_to receive(:service_desk_thank_you_email)

            subject
          end

          context 'when issue_email_participants FF is enabled' do
            it 'creates 2 issue_email_participants' do
              subject

              expect(Issue.last.issue_email_participants.map(&:email))
                .to match_array(%w(alan@adventuretime.ooo jake@adventuretime.ooo))
            end
          end

          context 'when issue_email_participants FF is disabled' do
            before do
              stub_feature_flags(issue_email_participants: false)
            end

            it 'creates only 1 issue_email_participant' do
              subject

              expect(Issue.last.issue_email_participants.map(&:email))
                .to match_array(%w(jake@adventuretime.ooo))
            end
          end
        end

        context 'when an issue with message_id has not been found' do
          subject do
            receive_reply
          end

          it 'creates a new issue correctly' do
            expect { subject }.to change { Issue.count }.by(1)

            issue = Issue.last

            expect(issue.description).to eq("Service desk reply!\n\n`/label ~label2`")
          end

          it 'sends thank you email once' do
            expect(Notify).to receive(:service_desk_thank_you_email).once.and_return(double(deliver_later: true))

            subject
          end

          it 'creates 1 issue_email_participant' do
            subject

            expect(Issue.last.issue_email_participants.map(&:email))
              .to match_array(%w(alan@adventuretime.ooo))
          end
        end
      end

      context 'when using issue templates' do
        let_it_be(:user) { create(:user) }

        before do
          setup_attachment
        end

        context 'and template is present' do
          let_it_be(:settings) { create(:service_desk_setting, project: project) }

          def set_template_file(file_name, content)
            file_path = ".gitlab/issue_templates/#{file_name}.md"
            project.repository.create_file(user, file_path, content, message: 'message', branch_name: 'master')
            settings.update!(issue_template_key: file_name)
          end

          it 'appends template text to issue description' do
            set_template_file('service_desk', 'text from template')

            receiver.execute

            issue_description = Issue.last.description
            expect(issue_description).to include(expected_description)
            expect(issue_description.lines.last).to eq('text from template')
          end

          context 'when quick actions are present' do
            let(:label) { create(:label, project: project, title: 'label1') }
            let(:milestone) { create(:milestone, project: project) }

            it 'applies quick action commands present on templates' do
              file_content = %(Text from template \n/label ~#{label.title} \n/milestone %"#{milestone.name}"")
              set_template_file('with_slash_commands', file_content)

              receiver.execute

              issue = Issue.last
              expect(issue.description).to include('Text from template')
              expect(issue.label_ids).to include(label.id)
              expect(issue.milestone).to eq(milestone)
            end

            it 'applies group labels using quick actions' do
              group_label = create(:group_label, group: project.group, title: 'label2')
              file_content = %(Text from template \n/label ~#{group_label.title}"")
              set_template_file('with_group_labels', file_content)

              receiver.execute

              issue = Issue.last
              expect(issue.description).to include('Text from template')
              expect(issue.label_ids).to include(group_label.id)
            end

            it 'redacts quick actions present on user email body' do
              set_template_file('service_desk1', 'text from template')

              receiver.execute

              issue = Issue.last
              expect(issue).to be_opened
              expect(issue.description).to include('`/label ~label1`')
              expect(issue.description).to include('`/assign @user1`')
              expect(issue.description).to include('`/close`')
              expect(issue.assignees).to be_empty
              expect(issue.milestone).to be_nil
            end

            context 'when issues are set to private' do
              before do
                project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
              end

              it 'applies quick action commands present on templates' do
                file_content = %(Text from service_desk2 template \n/label ~#{label.title} \n/milestone %"#{milestone.name}")
                set_template_file('service_desk2', file_content)

                receiver.execute

                issue = Issue.last
                expect(issue.description).to include('Text from service_desk2 template')
                expect(issue.label_ids).to include(label.id)
                expect(issue.author_id).to eq(User.support_bot.id)
                expect(issue.milestone).to eq(milestone)
              end
            end
          end
        end

        context 'and template cannot be found' do
          before do
            service = ServiceDeskSetting.new(project_id: project.id, issue_template_key: 'unknown')
            service.save!(validate: false)
          end

          it 'does not append template text to issue description' do
            receiver.execute

            new_issue = Issue.last

            expect(new_issue.description).to eq(expected_description.strip)
          end

          it 'creates support bot note on issue' do
            receiver.execute

            note = Note.last

            expect(note.note).to include("WARNING: The template file unknown.md used for service desk issues is empty or could not be found.")
            expect(note.author).to eq(User.support_bot)
          end

          it 'does not send warning note email' do
            ActionMailer::Base.deliveries = []

            perform_enqueued_jobs do
              expect { receiver.execute }.to change { ActionMailer::Base.deliveries.size }.by(1)
            end

            # Only sends created issue email
            expect(ActionMailer::Base.deliveries.last.text_part.body).to include("Thank you for your support request!")
          end
        end
      end

      context 'when all lines of email are quoted' do
        let(:email_raw) { email_fixture('emails/service_desk_all_quoted.eml') }

        it 'creates email with correct body' do
          receiver.execute

          issue = Issue.last
          expect(issue.description).to include('> This is an empty quote')
        end
      end

      context 'when using custom service desk address' do
        let(:receiver) { Gitlab::Email::ServiceDeskReceiver.new(email_raw) }

        before do
          stub_service_desk_email_setting(enabled: true, address: 'support+%{key}@example.com')
        end

        context 'when using project key' do
          let_it_be(:service_desk_key) { 'mykey' }

          let(:email_raw) { service_desk_fixture('emails/service_desk_custom_address.eml') }

          before_all do
            create(:service_desk_setting, project: project, project_key: service_desk_key)
          end

          it_behaves_like 'a new issue request'

          context 'when there is no project with the key' do
            let(:email_raw) { service_desk_fixture('emails/service_desk_custom_address.eml', key: 'some_key') }

            it 'bounces the email' do
              expect { receiver.execute }.to raise_error(Gitlab::Email::ProjectNotFound)
            end
          end

          context 'when the project slug does not match' do
            let(:email_raw) { service_desk_fixture('emails/service_desk_custom_address.eml', slug: 'some-slug') }

            it 'bounces the email' do
              expect { receiver.execute }.to raise_error(Gitlab::Email::ProjectNotFound)
            end
          end

          context 'when there are multiple projects with same key' do
            let_it_be(:project_with_same_key) { create(:project, group: group, service_desk_enabled: true) }

            let(:email_raw) { service_desk_fixture('emails/service_desk_custom_address.eml', slug: project_with_same_key.full_path_slug.to_s) }

            before do
              create(:service_desk_setting, project: project_with_same_key, project_key: service_desk_key)
            end

            it 'process email for project with matching slug' do
              expect { receiver.execute }.to change { Issue.count }.by(1)
              expect(Issue.last.project).to eq(project_with_same_key)
            end
          end
        end

        context 'when project key is not set' do
          let(:email_raw) { email_fixture('emails/service_desk_custom_address_no_key.eml') }

          before do
            stub_service_desk_email_setting(enabled: true, address: 'support+%{key}@example.com')
          end

          it_behaves_like 'a new issue request'
        end
      end
    end

    context 'when issue email creation fails' do
      before do
        allow(::Issue::Email).to receive(:create!).and_raise(StandardError)
      end

      it 'still creates a new issue' do
        expect { receiver.execute }.to change { Issue.count }.by(1)
      end

      it 'does not create issue email record' do
        expect { receiver.execute }.not_to change { Issue::Email.count }
      end
    end

    context 'when rate limiting is in effect', :freeze_time, :clean_gitlab_redis_rate_limiting do
      let(:receiver) { Gitlab::Email::Receiver.new(email_raw) }

      subject { 2.times { receiver.execute } }

      before do
        stub_application_setting(issues_create_limit: 1)
      end

      context 'when too many requests are sent by one user' do
        it 'raises an error' do
          expect { subject }.to raise_error(RateLimitedService::RateLimitedError)
        end

        it 'creates 1 issue' do
          expect do
            subject
          rescue RateLimitedService::RateLimitedError
          end.to change { Issue.count }.by(1)
        end
      end

      context 'when requests are sent by different users' do
        let(:email_raw_2) { email_fixture('emails/service_desk_forwarded.eml') }
        let(:receiver2) { Gitlab::Email::Receiver.new(email_raw_2) }

        subject do
          receiver.execute
          receiver2.execute
        end

        it 'creates 2 issues' do
          expect { subject }.to change { Issue.count }.by(2)
        end
      end

      context 'when limit is higher than sent emails' do
        before do
          stub_application_setting(issues_create_limit: 2)
        end

        it 'creates 2 issues' do
          expect { subject }.to change { Issue.count }.by(2)
        end
      end
    end

    describe '#can_handle?' do
      let(:mail) { Mail::Message.new(email_raw) }

      it 'handles the new email key format' do
        handler = described_class.new(mail, "h5bp-html5-boilerplate-#{project.project_id}-issue-")

        expect(handler.instance_variable_get(:@project_id).to_i).to eq project.project_id
        expect(handler.can_handle?).to be_truthy
      end

      it 'handles the legacy email key format' do
        handler = described_class.new(mail, "h5bp/html5-boilerplate")

        expect(handler.instance_variable_get(:@project_path)).to eq 'h5bp/html5-boilerplate'
        expect(handler.can_handle?).to be_truthy
      end

      it "doesn't handle invalid email key" do
        handler = described_class.new(mail, "h5bp-html5-boilerplate-invalid")

        expect(handler.can_handle?).to be_falsey
      end
    end

    context 'when there is no from address' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:from_address).and_return(nil)
        end
      end

      it "creates a new issue" do
        expect { receiver.execute }.to change { Issue.count }.by(1)
      end

      it 'does not send thank you email' do
        expect { receiver.execute }.not_to have_enqueued_job.on_queue('mailers')
      end
    end

    context 'when there is a sender address and a from address' do
      let(:email_raw) { email_fixture('emails/service_desk_sender_and_from.eml') }

      it 'prefers the from address' do
        setup_attachment

        expect { receiver.execute }.to change { Issue.count }.by(1)

        new_issue = Issue.last

        expect(new_issue.external_author).to eq('finn@adventuretime.ooo')
      end
    end

    context 'when service desk is not enabled for project' do
      before do
        allow(Gitlab::ServiceDesk).to receive(:enabled?).and_return(false)
      end

      it 'does not create an issue' do
        expect { receiver.execute rescue nil }.not_to change { Issue.count }
      end

      it 'does not send thank you email' do
        expect { receiver.execute rescue nil }.not_to have_enqueued_job.on_queue('mailers')
      end
    end

    context 'when the email is forwarded through an alias' do
      let(:author_email) { 'jake.g@adventuretime.ooo' }
      let(:email_raw) { email_fixture('emails/service_desk_forwarded.eml') }
      let(:message_id) { 'CADkmRc+rNGAGGbV2iE5p918UVy4UyJqVcXRO2=fdskbsf@mail.gmail.com' }

      it_behaves_like 'a new issue request'
    end

    context 'when the email is forwarded' do
      let(:email_raw) { email_fixture('emails/service_desk_forwarded_new_issue.eml') }

      it_behaves_like 'a new issue request' do
        let(:expected_description) do
          <<~EOF
            Service desk stuff!

            ---------- Forwarded message ---------
            From: Jake the Dog <jake@adventuretime.ooo>
            To: <jake@adventuretime.ooo>


            forwarded content

            ![image](uploads/image.png)
          EOF
        end
      end
    end
  end

  context 'service desk is disabled for the project' do
    let(:group) { create(:group)}
    let(:project) { create(:project, :public, group: group, path: 'test', service_desk_enabled: false) }

    it 'bounces the email' do
      expect { receiver.execute }.to raise_error(Gitlab::Email::ProcessingError)
    end

    it "doesn't create an issue" do
      expect { receiver.execute rescue nil }.not_to change { Issue.count }
    end
  end
end

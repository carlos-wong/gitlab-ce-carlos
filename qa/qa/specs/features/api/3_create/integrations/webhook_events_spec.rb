# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'WebHooks integration', :requires_admin, :integrations, :orchestrated do
      before(:context) do
        toggle_local_requests(true)
      end

      after(:context) do
        Vendor::Smocker::SmockerApi.teardown!
      end

      let(:session) { SecureRandom.hex(5) }

      it 'sends a push event', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348945' do
        setup_webhook(push: true) do |webhook, smocker|
          Resource::Repository::ProjectPush.fabricate! do |project_push|
            project_push.project = webhook.project
          end

          wait_until do
            !smocker.history(session).empty?
          end

          events = smocker.history(session).map(&:as_hook_event)
          aggregate_failures do
            expect(events.size).to be(1), "Should have 1 event: \n#{events.map(&:raw).join("\n")}"
            expect(events[0].project_name).to eql(webhook.project.name)
            expect(events[0].push?).to be(true), "Not push event: \n#{events[0].raw}"
          end
        end
      end

      it 'sends a merge request event', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/349720' do
        setup_webhook(merge_requests: true) do |webhook, smocker|
          Resource::MergeRequest.fabricate_via_api! do |merge_request|
            merge_request.project = webhook.project
          end

          wait_until do
            !smocker.history(session).empty?
          end

          events = smocker.history(session).map(&:as_hook_event)
          aggregate_failures do
            expect(events.size).to be(1), "Should have 1 event: \n#{events.map(&:raw).join("\n")}"
            expect(events[0].project_name).to eql(webhook.project.name)
            expect(events[0].mr?).to be(true), "Not MR event: \n#{events[0].raw}"
          end
        end
      end

      it 'sends a wiki page event', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/349722' do
        setup_webhook(wiki_page: true) do |webhook, smocker|
          Resource::Wiki::ProjectPage.fabricate_via_api! do |page|
            page.project = webhook.project
          end

          wait_until do
            !smocker.history(session).empty?
          end

          events = smocker.history(session).map(&:as_hook_event)
          aggregate_failures do
            expect(events.size).to be(1), "Should have 1 event: \n#{events.map(&:raw).join("\n")}"
            expect(events[0].project_name).to eql(webhook.project.name)
            expect(events[0].wiki?).to be(true), "Not wiki event: \n#{events[0].raw}"
          end
        end
      end

      it 'sends an issues and note event', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/349723' do
        setup_webhook(issues: true, note: true) do |webhook, smocker|
          issue = Resource::Issue.fabricate_via_api! do |issue_init|
            issue_init.project = webhook.project
          end

          Resource::ProjectIssueNote.fabricate_via_api! do |note|
            note.project = issue.project
            note.issue = issue
          end

          wait_until do
            smocker.history(session).size > 1
          end

          events = smocker.history(session).map(&:as_hook_event)
          aggregate_failures do
            issue_event = events.find(&:issue?)
            note_event = events.find(&:note?)

            expect(events.size).to be(2), "Should have 2 events: \n#{events.map(&:raw).join("\n")}"
            expect(issue_event).not_to be(nil), "Not issue event: \n#{events[0].raw}"
            expect(note_event).not_to be(nil), "Not note event: \n#{events[1].raw}"
          end
        end
      end

      private

      def setup_webhook(**event_args)
        Vendor::Smocker::SmockerApi.init(wait: 10) do |smocker|
          smocker.register(session: session)

          webhook = Resource::ProjectWebHook.fabricate_via_api! do |hook|
            hook.url = smocker.url

            event_args.each do |event, bool|
              hook.send("#{event}_events=", bool)
            end
          end

          yield(webhook, smocker)

          smocker.reset
        end
      end

      def toggle_local_requests(on)
        Runtime::ApplicationSettings.set_application_settings(allow_local_requests_from_web_hooks_and_services: on)
      end

      def wait_until(timeout = 120, &block)
        Support::Waiter.wait_until(max_duration: timeout, reload_page: false, raise_on_failure: false, &block)
      end
    end
  end
end

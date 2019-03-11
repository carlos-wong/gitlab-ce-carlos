require 'spec_helper'

describe NotificationService, :mailer do
  include EmailSpec::Matchers
  include NotificationHelpers

  let(:notification) { described_class.new }
  let(:assignee) { create(:user) }

  around do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  shared_examples 'altered milestone notification on issue' do
    it 'sends the email to the correct people' do
      should_email(subscriber_to_new_milestone)
      issue.assignees.each do |a|
        should_email(a)
      end
      should_email(@u_watcher)
      should_email(@u_guest_watcher)
      should_email(@u_participant_mentioned)
      should_email(@subscriber)
      should_email(@subscribed_participant)
      should_email(@watcher_and_subscriber)
      should_not_email(@u_guest_custom)
      should_not_email(@u_committer)
      should_not_email(@unsubscriber)
      should_not_email(@u_participating)
      should_not_email(@u_lazy_participant)
      should_not_email(issue.author)
      should_not_email(@u_disabled)
      should_not_email(@u_custom_global)
      should_not_email(@u_mentioned)
    end
  end

  shared_examples 'altered milestone notification on merge request' do
    it 'sends the email to the correct people' do
      should_email(subscriber_to_new_milestone)
      merge_request.assignees.each do |a|
        should_email(a)
      end
      should_email(@u_watcher)
      should_email(@u_guest_watcher)
      should_email(@u_participant_mentioned)
      should_email(@subscriber)
      should_email(@subscribed_participant)
      should_email(@watcher_and_subscriber)
      should_not_email(@u_guest_custom)
      should_not_email(@u_committer)
      should_not_email(@unsubscriber)
      should_not_email(@u_participating)
      should_not_email(@u_lazy_participant)
      should_not_email(merge_request.author)
      should_not_email(@u_disabled)
      should_not_email(@u_custom_global)
      should_not_email(@u_mentioned)
    end
  end

  shared_examples 'notifications for new mentions' do
    it 'sends no emails when no new mentions are present' do
      send_notifications
      should_not_email_anyone
    end

    it 'emails new mentions with a watch level higher than mention' do
      send_notifications(@u_watcher, @u_participant_mentioned, @u_custom_global, @u_mentioned)
      should_only_email(@u_watcher, @u_participant_mentioned, @u_custom_global, @u_mentioned)
    end

    it 'does not email new mentions with a watch level equal to or less than mention' do
      send_notifications(@u_disabled)
      should_not_email_anyone
    end

    it 'emails new mentions despite being unsubscribed' do
      send_notifications(@unsubscribed_mentioned)

      should_only_email(@unsubscribed_mentioned)
    end

    it 'sends the proper notification reason header' do
      send_notifications(@u_watcher)
      should_only_email(@u_watcher)
      email = find_email_for(@u_watcher)

      expect(email).to have_header('X-GitLab-NotificationReason', NotificationReason::MENTIONED)
    end
  end

  # Next shared examples are intended to test notifications of "participants"
  #
  # they take the following parameters:
  # * issuable
  # * notification trigger
  # * participant
  #
  shared_examples 'participating by note notification' do
    it 'emails the participant' do
      create(:note_on_issue, noteable: issuable, project_id: project.id, note: 'anything', author: participant)

      notification_trigger

      should_email(participant)
    end

    context 'for subgroups', :nested_groups do
      before do
        build_group(project)
      end

      it 'emails the participant' do
        create(:note_on_issue, noteable: issuable, project_id: project.id, note: 'anything', author: @pg_participant)

        notification_trigger

        should_email_nested_group_user(@pg_participant)
      end
    end
  end

  shared_examples 'participating by assignee notification' do
    it 'emails the participant' do
      if issuable.is_a?(Issue)
        issuable.assignees << participant
      else
        issuable.update_attribute(:assignee, participant)
      end

      notification_trigger

      should_email(participant)
    end
  end

  shared_examples 'participating by author notification' do
    it 'emails the participant' do
      issuable.author = participant

      notification_trigger

      should_email(participant)
    end
  end

  shared_examples_for 'participating notifications' do
    it_should_behave_like 'participating by note notification'
    it_should_behave_like 'participating by author notification'
    it_should_behave_like 'participating by assignee notification'
  end

  describe '#async' do
    let(:async) { notification.async }
    set(:key) { create(:personal_key) }

    it 'returns an Async object with the correct parent' do
      expect(async).to be_a(described_class::Async)
      expect(async.parent).to eq(notification)
    end

    context 'when receiving a public method' do
      it 'schedules a MailScheduler::NotificationServiceWorker' do
        expect(MailScheduler::NotificationServiceWorker)
          .to receive(:perform_async).with('new_key', key)

        async.new_key(key)
      end
    end

    context 'when receiving a private method' do
      it 'raises NoMethodError' do
        expect { async.notifiable?(key) }.to raise_error(NoMethodError)
      end
    end

    context 'when receiving a non-existent method' do
      it 'raises NoMethodError' do
        expect { async.foo(key) }.to raise_error(NoMethodError)
      end
    end
  end

  describe 'Keys' do
    describe '#new_key' do
      let(:key_options) { {} }
      let!(:key) { create(:personal_key, key_options) }

      it { expect(notification.new_key(key)).to be_truthy }

      describe 'never emails the ghost user' do
        let(:key_options) { { user: User.ghost } }

        it { should_not_email_anyone }
      end
    end
  end

  describe 'GpgKeys' do
    describe '#new_gpg_key' do
      let!(:key) { create(:gpg_key) }

      it { expect(notification.new_gpg_key(key)).to be_truthy }

      it 'sends email to key owner' do
        expect { notification.new_gpg_key(key) }.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end
  end

  describe 'Notes' do
    context 'issue note' do
      let(:project) { create(:project, :private) }
      let(:issue) { create(:issue, project: project, assignees: [assignee]) }
      let(:mentioned_issue) { create(:issue, assignees: issue.assignees) }
      let(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: '@mention referenced, @unsubscribed_mentioned and @outsider also') }

      before do
        build_team(note.project)
        project.add_maintainer(issue.author)
        project.add_maintainer(assignee)
        project.add_maintainer(note.author)

        @u_custom_off = create_user_with_notification(:custom, 'custom_off')
        project.add_guest(@u_custom_off)

        create(
          :note_on_issue,
          author: @u_custom_off,
          noteable: issue,
          project_id: issue.project_id,
          note: 'i think @subscribed_participant should see this'
        )

        update_custom_notification(:new_note, @u_guest_custom, resource: project)
        update_custom_notification(:new_note, @u_custom_global)
      end

      describe '#new_note' do
        it do
          add_users_with_subscription(note.project, issue)
          reset_delivered_emails!

          expect(SentNotification).to receive(:record).with(issue, any_args).exactly(10).times

          notification.new_note(note)

          should_email(@u_watcher)
          should_email(note.noteable.author)
          should_email(note.noteable.assignees.first)
          should_email(@u_custom_global)
          should_email(@u_mentioned)
          should_email(@subscriber)
          should_email(@watcher_and_subscriber)
          should_email(@subscribed_participant)
          should_email(@u_custom_off)
          should_email(@unsubscribed_mentioned)
          should_not_email(@u_guest_custom)
          should_not_email(@u_guest_watcher)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@unsubscriber)
          should_not_email(@u_outsider_mentioned)
          should_not_email(@u_lazy_participant)
        end

        it "emails the note author if they've opted into notifications about their activity" do
          add_users_with_subscription(note.project, issue)
          reset_delivered_emails!

          note.author.notified_of_own_activity = true

          notification.new_note(note)

          should_email(note.author)
        end

        it 'filters out "mentioned in" notes' do
          mentioned_note = SystemNoteService.cross_reference(mentioned_issue, issue, issue.author)

          expect(Notify).not_to receive(:note_issue_email)
          notification.new_note(mentioned_note)
        end

        context 'participating' do
          context 'by note' do
            before do
              reset_delivered_emails!
              note.author = @u_lazy_participant
              note.save
              notification.new_note(note)
            end

            it { should_not_email(@u_lazy_participant) }
          end
        end
      end

      describe 'new note on issue in project that belongs to a group' do
        before do
          note.project.namespace_id = group.id
          group.add_user(@u_watcher, GroupMember::MAINTAINER)
          group.add_user(@u_custom_global, GroupMember::MAINTAINER)
          note.project.save

          @u_watcher.notification_settings_for(note.project).participating!
          @u_watcher.notification_settings_for(group).global!
          update_custom_notification(:new_note, @u_custom_global)
          reset_delivered_emails!
        end

        shared_examples 'new note notifications' do
          it do
            notification.new_note(note)

            should_email(note.noteable.author)
            should_email(note.noteable.assignees.first)
            should_email(@u_mentioned)
            should_email(@u_custom_global)
            should_not_email(@u_guest_custom)
            should_not_email(@u_guest_watcher)
            should_not_email(@u_watcher)
            should_not_email(note.author)
            should_not_email(@u_participating)
            should_not_email(@u_disabled)
            should_not_email(@u_lazy_participant)
          end
        end

        let(:group) { create(:group) }

        it_behaves_like 'new note notifications'

        context 'which is a subgroup', :nested_groups do
          let!(:parent) { create(:group) }
          let!(:group) { create(:group, parent: parent) }

          it_behaves_like 'new note notifications'

          it 'overrides child objects with global level' do
            user = create(:user)
            parent.add_developer(user)
            user.notification_settings_for(parent).watch!
            reset_delivered_emails!

            notification.new_note(note)

            should_email(user)
          end
        end
      end
    end

    context 'confidential issue note' do
      let(:project) { create(:project, :public) }
      let(:author) { create(:user) }
      let(:assignee) { create(:user) }
      let(:non_member) { create(:user) }
      let(:member) { create(:user) }
      let(:guest) { create(:user) }
      let(:admin) { create(:admin) }
      let(:confidential_issue) { create(:issue, :confidential, project: project, author: author, assignees: [assignee]) }
      let(:note) { create(:note_on_issue, noteable: confidential_issue, project: project, note: "#{author.to_reference} #{assignee.to_reference} #{non_member.to_reference} #{member.to_reference} #{admin.to_reference}") }
      let(:guest_watcher) { create_user_with_notification(:watch, "guest-watcher-confidential") }

      it 'filters out users that can not read the issue' do
        project.add_developer(member)
        project.add_guest(guest)

        expect(SentNotification).to receive(:record).with(confidential_issue, any_args).exactly(4).times

        reset_delivered_emails!

        notification.new_note(note)

        should_not_email(non_member)
        should_not_email(guest)
        should_not_email(guest_watcher)
        should_email(author)
        should_email(assignee)
        should_email(member)
        should_email(admin)
      end

      context 'on project that belongs to subgroup', :nested_groups do
        let(:group_reporter) { create(:user) }
        let(:group_guest) { create(:user) }
        let(:parent_group) { create(:group) }
        let(:child_group) { create(:group, parent: parent_group) }
        let(:project) { create(:project, namespace: child_group) }

        context 'when user is group guest member' do
          before do
            parent_group.add_reporter(group_reporter)
            parent_group.add_guest(group_guest)
            group_guest.notification_settings_for(parent_group).watch!
            group_reporter.notification_settings_for(parent_group).watch!
            reset_delivered_emails!
          end

          it 'does not email guest user' do
            notification.new_note(note)

            should_email(group_reporter)
            should_not_email(group_guest)
          end
        end
      end
    end

    context 'issue note mention' do
      let(:project) { create(:project, :public) }
      let(:issue) { create(:issue, project: project, assignees: [assignee]) }
      let(:mentioned_issue) { create(:issue, assignees: issue.assignees) }
      let(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: '@all mentioned') }

      before do
        build_team(note.project)
        build_group(note.project)
        note.project.add_maintainer(note.author)
        add_users_with_subscription(note.project, issue)
        reset_delivered_emails!
      end

      describe '#new_note' do
        it 'notifies the team members' do
          notification.new_note(note)

          # Make sure @unsubscribed_mentioned is part of the team
          expect(note.project.team.members).to include(@unsubscribed_mentioned)

          # Notify all team members
          note.project.team.members.each do |member|
            # User with disabled notification should not be notified
            next if member.id == @u_disabled.id
            # Author should not be notified
            next if member.id == note.author.id

            should_email(member)
          end

          should_email(@u_guest_watcher)
          should_email(note.noteable.author)
          should_email(note.noteable.assignees.first)
          should_email_nested_group_user(@pg_watcher)
          should_email(@u_mentioned)
          should_email(@u_not_mentioned)
          should_not_email(note.author)
          should_not_email(@u_disabled)
          should_not_email_nested_group_user(@pg_disabled)
        end

        it 'notifies parent group members with mention level', :nested_groups do
          note = create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: "@#{@pg_mention.username}")

          notification.new_note(note)

          should_email_nested_group_user(@pg_mention)
        end

        it 'filters out "mentioned in" notes' do
          mentioned_note = SystemNoteService.cross_reference(mentioned_issue, issue, issue.author)

          expect(Notify).not_to receive(:note_issue_email)
          notification.new_note(mentioned_note)
        end
      end
    end

    context 'project snippet note' do
      let!(:project) { create(:project, :public) }
      let(:snippet) { create(:project_snippet, project: project, author: create(:user)) }
      let(:note) { create(:note_on_project_snippet, noteable: snippet, project_id: project.id, note: '@all mentioned') }

      before do
        build_team(project)
        build_group(project)

        # make sure these users can read the project snippet!
        project.add_guest(@u_guest_watcher)
        project.add_guest(@u_guest_custom)
        add_member_for_parent_group(@pg_watcher, project)
        note.project.add_maintainer(note.author)
        reset_delivered_emails!
      end

      describe '#new_note' do
        it 'notifies the team members' do
          notification.new_note(note)
          # Notify all team members
          note.project.team.members.each do |member|
            # User with disabled notification should not be notified
            next if member.id == @u_disabled.id
            # Author should not be notified
            next if member.id == note.author.id

            should_email(member)
          end

          # it emails custom global users on mention
          should_email(@u_custom_global)

          should_email(@u_guest_watcher)
          should_email(note.noteable.author)
          should_not_email(note.author)
          should_email(@u_mentioned)
          should_not_email(@u_disabled)
          should_email(@u_not_mentioned)
        end
      end
    end

    context 'personal snippet note' do
      let(:snippet) { create(:personal_snippet, :public, author: @u_snippet_author) }
      let(:note)    { create(:note_on_personal_snippet, noteable: snippet, note: '@mentioned note', author: @u_note_author) }

      before do
        @u_watcher               = create_global_setting_for(create(:user), :watch)
        @u_participant           = create_global_setting_for(create(:user), :participating)
        @u_disabled              = create_global_setting_for(create(:user), :disabled)
        @u_mentioned             = create_global_setting_for(create(:user, username: 'mentioned'), :mention)
        @u_mentioned_level       = create_global_setting_for(create(:user, username: 'participator'), :mention)
        @u_note_author           = create(:user, username: 'note_author')
        @u_snippet_author        = create(:user, username: 'snippet_author')
        @u_not_mentioned         = create_global_setting_for(create(:user, username: 'regular'), :participating)

        reset_delivered_emails!
      end

      let!(:notes) do
        [
          create(:note_on_personal_snippet, noteable: snippet, note: 'note', author: @u_watcher),
          create(:note_on_personal_snippet, noteable: snippet, note: 'note', author: @u_participant),
          create(:note_on_personal_snippet, noteable: snippet, note: 'note', author: @u_mentioned),
          create(:note_on_personal_snippet, noteable: snippet, note: 'note', author: @u_disabled),
          create(:note_on_personal_snippet, noteable: snippet, note: 'note', author: @u_note_author)
        ]
      end

      describe '#new_note' do
        it 'notifies the participants' do
          notification.new_note(note)

          # it emails participants
          should_email(@u_watcher)
          should_email(@u_participant)
          should_email(@u_watcher)
          should_email(@u_snippet_author)

          # it emails mentioned users
          should_email(@u_mentioned)

          # it does not email participants with mention notification level
          should_not_email(@u_mentioned_level)

          # it does not email note author
          should_not_email(@u_note_author)
        end
      end
    end

    context 'commit note' do
      let(:project) { create(:project, :public, :repository) }
      let(:note) { create(:note_on_commit, project: project) }

      before do
        build_team(note.project)
        build_group(project)
        reset_delivered_emails!
        allow(note.noteable).to receive(:author).and_return(@u_committer)
        update_custom_notification(:new_note, @u_guest_custom, resource: project)
        update_custom_notification(:new_note, @u_custom_global)
      end

      describe '#new_note, #perform_enqueued_jobs' do
        it do
          notification.new_note(note)
          should_email(@u_guest_watcher)
          should_email(@u_custom_global)
          should_email(@u_guest_custom)
          should_email(@u_committer)
          should_email(@u_watcher)
          should_email_nested_group_user(@pg_watcher)
          should_not_email(@u_mentioned)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@u_lazy_participant)
          should_not_email_nested_group_user(@pg_disabled)
        end

        it do
          note.update_attribute(:note, '@mention referenced')
          notification.new_note(note)

          should_email(@u_guest_watcher)
          should_email(@u_committer)
          should_email(@u_watcher)
          should_email(@u_mentioned)
          should_email_nested_group_user(@pg_watcher)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@u_lazy_participant)
          should_not_email_nested_group_user(@pg_disabled)
        end

        it do
          @u_committer = create_global_setting_for(@u_committer, :mention)
          notification.new_note(note)
          should_not_email(@u_committer)
        end
      end
    end

    context "merge request diff note" do
      let(:project) { create(:project, :repository) }
      let(:user) { create(:user) }
      let(:merge_request) { create(:merge_request, source_project: project, assignee: user, author: create(:user)) }
      let(:note) { create(:diff_note_on_merge_request, project: project, noteable: merge_request) }

      before do
        build_team(note.project)
        project.add_maintainer(merge_request.author)
        project.add_maintainer(merge_request.assignee)
      end

      describe '#new_note' do
        it "records sent notifications" do
          # 3 SentNotification are sent: the MR assignee and author, and the @u_watcher
          expect(SentNotification).to receive(:record_note).with(note, any_args).exactly(3).times.and_call_original

          notification.new_note(note)

          expect(SentNotification.last(3).map(&:recipient).map(&:id))
            .to contain_exactly(merge_request.assignee.id, merge_request.author.id, @u_watcher.id)
          expect(SentNotification.last.in_reply_to_discussion_id).to eq(note.discussion_id)
        end
      end
    end
  end

  describe 'Issues' do
    let(:group) { create(:group) }
    let(:project) { create(:project, :public, namespace: group) }
    let(:another_project) { create(:project, :public, namespace: group) }
    let(:issue) { create :issue, project: project, assignees: [assignee], description: 'cc @participant @unsubscribed_mentioned' }

    before do
      build_team(issue.project)
      build_group(issue.project)

      add_users_with_subscription(issue.project, issue)
      reset_delivered_emails!
      update_custom_notification(:new_issue, @u_guest_custom, resource: project)
      update_custom_notification(:new_issue, @u_custom_global)
    end

    describe '#new_issue' do
      it do
        notification.new_issue(issue, @u_disabled)

        should_email(assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@g_global_watcher)
        should_email(@g_watcher)
        should_email(@unsubscribed_mentioned)
        should_email_nested_group_user(@pg_watcher)
        should_not_email(@u_mentioned)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
        should_not_email_nested_group_user(@pg_disabled)
        should_not_email_nested_group_user(@pg_mention)
      end

      it do
        create_global_setting_for(issue.assignees.first, :mention)
        notification.new_issue(issue, @u_disabled)

        should_not_email(issue.assignees.first)
      end

      it 'properly prioritizes notification reason' do
        # have assignee be both assigned and mentioned
        issue.update_attribute(:description, "/cc #{assignee.to_reference} #{@u_mentioned.to_reference}")

        notification.new_issue(issue, @u_disabled)

        email = find_email_for(assignee)
        expect(email).to have_header('X-GitLab-NotificationReason', 'assigned')

        email = find_email_for(@u_mentioned)
        expect(email).to have_header('X-GitLab-NotificationReason', 'mentioned')
      end

      it 'adds "assigned" reason for assignees if any' do
        notification.new_issue(issue, @u_disabled)

        email = find_email_for(assignee)

        expect(email).to have_header('X-GitLab-NotificationReason', 'assigned')
      end

      it "emails any mentioned users with the mention level" do
        issue.description = @u_mentioned.to_reference

        notification.new_issue(issue, @u_disabled)

        email = find_email_for(@u_mentioned)
        expect(email).not_to be_nil
        expect(email).to have_header('X-GitLab-NotificationReason', 'mentioned')
      end

      it "emails the author if they've opted into notifications about their activity" do
        issue.author.notified_of_own_activity = true

        notification.new_issue(issue, issue.author)

        should_email(issue.author)
      end

      it "doesn't email the author if they haven't opted into notifications about their activity" do
        notification.new_issue(issue, issue.author)

        should_not_email(issue.author)
      end

      it "emails subscribers of the issue's labels" do
        user_1 = create(:user)
        user_2 = create(:user)
        user_3 = create(:user)
        user_4 = create(:user)
        label = create(:label, project: project, issues: [issue])
        group_label = create(:group_label, group: group, issues: [issue])
        issue.reload
        label.toggle_subscription(user_1, project)
        group_label.toggle_subscription(user_2, project)
        group_label.toggle_subscription(user_3, another_project)
        group_label.toggle_subscription(user_4)

        notification.new_issue(issue, @u_disabled)

        should_email(user_1)
        should_email(user_2)
        should_not_email(user_3)
        should_email(user_4)
      end

      context 'confidential issues' do
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }
        let(:non_member) { create(:user) }
        let(:member) { create(:user) }
        let(:guest) { create(:user) }
        let(:admin) { create(:admin) }
        let(:confidential_issue) { create(:issue, :confidential, project: project, title: 'Confidential issue', author: author, assignees: [assignee]) }

        it "emails subscribers of the issue's labels that can read the issue" do
          project.add_developer(member)
          project.add_guest(guest)

          label = create(:label, project: project, issues: [confidential_issue])
          confidential_issue.reload
          label.toggle_subscription(non_member, project)
          label.toggle_subscription(author, project)
          label.toggle_subscription(assignee, project)
          label.toggle_subscription(member, project)
          label.toggle_subscription(guest, project)
          label.toggle_subscription(admin, project)

          reset_delivered_emails!

          notification.new_issue(confidential_issue, @u_disabled)

          should_not_email(@u_guest_watcher)
          should_not_email(non_member)
          should_not_email(author)
          should_not_email(guest)
          should_email(assignee)
          should_email(member)
          should_email(admin)
        end
      end
    end

    describe '#new_mentions_in_issue' do
      let(:notification_method) { :new_mentions_in_issue }
      let(:mentionable) { issue }

      include_examples 'notifications for new mentions'
    end

    describe '#reassigned_issue' do
      before do
        update_custom_notification(:reassign_issue, @u_guest_custom, resource: project)
        update_custom_notification(:reassign_issue, @u_custom_global)
      end

      it 'emails new assignee' do
        notification.reassigned_issue(issue, @u_disabled, [assignee])

        should_email(issue.assignees.first)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'adds "assigned" reason for new assignee' do
        notification.reassigned_issue(issue, @u_disabled, [assignee])

        email = find_email_for(assignee)

        expect(email).to have_header('X-GitLab-NotificationReason', NotificationReason::ASSIGNED)
      end

      it 'emails previous assignee even if he has the "on mention" notif level' do
        issue.assignees = [@u_mentioned]
        notification.reassigned_issue(issue, @u_disabled, [@u_watcher])

        should_email(@u_mentioned)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'emails new assignee even if he has the "on mention" notif level' do
        issue.assignees = [@u_mentioned]
        notification.reassigned_issue(issue, @u_disabled, [@u_mentioned])

        expect(issue.assignees.first).to be @u_mentioned
        should_email(issue.assignees.first)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'emails new assignee' do
        issue.assignees = [@u_mentioned]
        notification.reassigned_issue(issue, @u_disabled, [@u_mentioned])

        expect(issue.assignees.first).to be @u_mentioned
        should_email(issue.assignees.first)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'does not email new assignee if they are the current user' do
        issue.assignees = [@u_mentioned]
        notification.reassigned_issue(issue, @u_mentioned, [@u_mentioned])

        expect(issue.assignees.first).to be @u_mentioned
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(issue.assignees.first)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { issue }
        let(:notification_trigger) { notification.reassigned_issue(issue, @u_disabled, [assignee]) }
      end
    end

    describe '#relabeled_issue' do
      let(:group_label_1) { create(:group_label, group: group, title: 'Group Label 1', issues: [issue]) }
      let(:group_label_2) { create(:group_label, group: group, title: 'Group Label 2') }
      let(:label_1) { create(:label, project: project, title: 'Label 1', issues: [issue]) }
      let(:label_2) { create(:label, project: project, title: 'Label 2') }
      let!(:subscriber_to_group_label_1) { create(:user) { |u| group_label_1.toggle_subscription(u, project) } }
      let!(:subscriber_1_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u, project) } }
      let!(:subscriber_2_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u) } }
      let!(:subscriber_to_group_label_2_on_another_project) { create(:user) { |u| group_label_2.toggle_subscription(u, another_project) } }
      let!(:subscriber_to_label_1) { create(:user) { |u| label_1.toggle_subscription(u, project) } }
      let!(:subscriber_to_label_2) { create(:user) { |u| label_2.toggle_subscription(u, project) } }

      it "emails the current user if they've opted into notifications about their activity" do
        subscriber_to_label_2.notified_of_own_activity = true
        notification.relabeled_issue(issue, [group_label_2, label_2], subscriber_to_label_2)

        should_email(subscriber_to_label_2)
      end

      it "doesn't email the current user if they haven't opted into notifications about their activity" do
        notification.relabeled_issue(issue, [group_label_2, label_2], subscriber_to_label_2)

        should_not_email(subscriber_to_label_2)
      end

      it "doesn't send email to anyone but subscribers of the given labels" do
        notification.relabeled_issue(issue, [group_label_2, label_2], @u_disabled)

        should_not_email(subscriber_to_label_1)
        should_not_email(subscriber_to_group_label_1)
        should_not_email(subscriber_to_group_label_2_on_another_project)
        should_email(subscriber_1_to_group_label_2)
        should_email(subscriber_2_to_group_label_2)
        should_email(subscriber_to_label_2)
        should_not_email(issue.assignees.first)
        should_not_email(issue.author)
        should_not_email(@u_watcher)
        should_not_email(@u_guest_watcher)
        should_not_email(@u_participant_mentioned)
        should_not_email(@subscriber)
        should_not_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
      end

      it "doesn't send multiple email when a user is subscribed to multiple given labels" do
        subscriber_to_both = create(:user) do |user|
          [label_1, label_2].each { |label| label.toggle_subscription(user, project) }
        end

        notification.relabeled_issue(issue, [label_1, label_2], @u_disabled)

        should_email(subscriber_to_label_1)
        should_email(subscriber_to_label_2)
        should_email(subscriber_to_both)
      end

      context 'confidential issues' do
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }
        let(:non_member) { create(:user) }
        let(:member) { create(:user) }
        let(:guest) { create(:user) }
        let(:admin) { create(:admin) }
        let(:confidential_issue) { create(:issue, :confidential, project: project, title: 'Confidential issue', author: author, assignees: [assignee]) }
        let!(:label_1) { create(:label, project: project, issues: [confidential_issue]) }
        let!(:label_2) { create(:label, project: project) }

        it "emails subscribers of the issue's labels that can read the issue" do
          project.add_developer(member)
          project.add_guest(guest)

          label_2.toggle_subscription(non_member, project)
          label_2.toggle_subscription(author, project)
          label_2.toggle_subscription(assignee, project)
          label_2.toggle_subscription(member, project)
          label_2.toggle_subscription(guest, project)
          label_2.toggle_subscription(admin, project)

          reset_delivered_emails!

          notification.relabeled_issue(confidential_issue, [label_2], @u_disabled)

          should_not_email(non_member)
          should_not_email(guest)
          should_email(author)
          should_email(assignee)
          should_email(member)
          should_email(admin)
        end
      end
    end

    describe '#removed_milestone_issue' do
      it_behaves_like 'altered milestone notification on issue' do
        let(:milestone) { create(:milestone, project: project, issues: [issue]) }
        let!(:subscriber_to_new_milestone) { create(:user) { |u| issue.toggle_subscription(u, project) } }

        before do
          notification.removed_milestone_issue(issue, issue.author)
        end
      end

      context 'confidential issues' do
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }
        let(:non_member) { create(:user) }
        let(:member) { create(:user) }
        let(:guest) { create(:user) }
        let(:admin) { create(:admin) }
        let(:confidential_issue) { create(:issue, :confidential, project: project, title: 'Confidential issue', author: author, assignees: [assignee]) }
        let(:milestone) { create(:milestone, project: project, issues: [confidential_issue]) }

        it "emails subscribers of the issue's milestone that can read the issue" do
          project.add_developer(member)
          project.add_guest(guest)

          confidential_issue.subscribe(non_member, project)
          confidential_issue.subscribe(author, project)
          confidential_issue.subscribe(assignee, project)
          confidential_issue.subscribe(member, project)
          confidential_issue.subscribe(guest, project)
          confidential_issue.subscribe(admin, project)

          reset_delivered_emails!

          notification.removed_milestone_issue(confidential_issue, @u_disabled)

          should_not_email(non_member)
          should_not_email(guest)
          should_email(author)
          should_email(assignee)
          should_email(member)
          should_email(admin)
        end
      end
    end

    describe '#changed_milestone_issue' do
      it_behaves_like 'altered milestone notification on issue' do
        let(:new_milestone) { create(:milestone, project: project, issues: [issue]) }
        let!(:subscriber_to_new_milestone) { create(:user) { |u| issue.toggle_subscription(u, project) } }

        before do
          notification.changed_milestone_issue(issue, new_milestone, issue.author)
        end
      end

      context 'confidential issues' do
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }
        let(:non_member) { create(:user) }
        let(:member) { create(:user) }
        let(:guest) { create(:user) }
        let(:admin) { create(:admin) }
        let(:confidential_issue) { create(:issue, :confidential, project: project, title: 'Confidential issue', author: author, assignees: [assignee]) }
        let(:new_milestone) { create(:milestone, project: project, issues: [confidential_issue]) }

        it "emails subscribers of the issue's milestone that can read the issue" do
          project.add_developer(member)
          project.add_guest(guest)

          confidential_issue.subscribe(non_member, project)
          confidential_issue.subscribe(author, project)
          confidential_issue.subscribe(assignee, project)
          confidential_issue.subscribe(member, project)
          confidential_issue.subscribe(guest, project)
          confidential_issue.subscribe(admin, project)

          reset_delivered_emails!

          notification.changed_milestone_issue(confidential_issue, new_milestone, @u_disabled)

          should_not_email(non_member)
          should_not_email(guest)
          should_email(author)
          should_email(assignee)
          should_email(member)
          should_email(admin)
        end
      end
    end

    describe '#close_issue' do
      before do
        update_custom_notification(:close_issue, @u_guest_custom, resource: project)
        update_custom_notification(:close_issue, @u_custom_global)
      end

      it 'sends email to issue assignee and issue author' do
        notification.close_issue(issue, @u_disabled)

        should_email(issue.assignees.first)
        should_email(issue.author)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { issue }
        let(:notification_trigger) { notification.close_issue(issue, @u_disabled) }
      end
    end

    describe '#reopen_issue' do
      before do
        update_custom_notification(:reopen_issue, @u_guest_custom, resource: project)
        update_custom_notification(:reopen_issue, @u_custom_global)
      end

      it 'sends email to issue notification recipients' do
        notification.reopen_issue(issue, @u_disabled)

        should_email(issue.assignees.first)
        should_email(issue.author)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { issue }
        let(:notification_trigger) { notification.reopen_issue(issue, @u_disabled) }
      end
    end

    describe '#issue_moved' do
      let(:new_issue) { create(:issue) }

      it 'sends email to issue notification recipients' do
        notification.issue_moved(issue, new_issue, @u_disabled)

        should_email(issue.assignees.first)
        should_email(issue.author)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { issue }
        let(:notification_trigger) { notification.issue_moved(issue, new_issue, @u_disabled) }
      end
    end

    describe '#issue_due' do
      before do
        issue.update!(due_date: Date.today)

        update_custom_notification(:issue_due, @u_guest_custom, resource: project)
        update_custom_notification(:issue_due, @u_custom_global)
      end

      it 'sends email to issue notification recipients, excluding watchers' do
        notification.issue_due(issue)

        should_email(issue.assignees.first)
        should_email(issue.author)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@u_watcher)
        should_not_email(@u_guest_watcher)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'sends the email from the author' do
        notification.issue_due(issue)
        email = find_email_for(@subscriber)

        expect(email.header[:from].display_names).to eq([issue.author.name])
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { issue }
        let(:notification_trigger) { notification.issue_due(issue) }
      end
    end
  end

  describe 'Merge Requests' do
    let(:group) { create(:group) }
    let(:project) { create(:project, :public, :repository, namespace: group) }
    let(:another_project) { create(:project, :public, namespace: group) }
    let(:merge_request) { create :merge_request, source_project: project, assignee: create(:user), description: 'cc @participant' }

    before do
      project.add_maintainer(merge_request.author)
      project.add_maintainer(merge_request.assignee)
      build_team(merge_request.target_project)
      add_users_with_subscription(merge_request.target_project, merge_request)
      update_custom_notification(:new_merge_request, @u_guest_custom, resource: project)
      update_custom_notification(:new_merge_request, @u_custom_global)
      reset_delivered_emails!
    end

    describe '#new_merge_request' do
      it do
        notification.new_merge_request(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@watcher_and_subscriber)
        should_email(@u_participant_mentioned)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'adds "assigned" reason for assignee, if any' do
        notification.new_merge_request(merge_request, @u_disabled)

        email = find_email_for(merge_request.assignee)

        expect(email).to have_header('X-GitLab-NotificationReason', NotificationReason::ASSIGNED)
      end

      it "emails any mentioned users with the mention level" do
        merge_request.description = @u_mentioned.to_reference

        notification.new_merge_request(merge_request, @u_disabled)

        should_email(@u_mentioned)
      end

      it "emails the author if they've opted into notifications about their activity" do
        merge_request.author.notified_of_own_activity = true

        notification.new_merge_request(merge_request, merge_request.author)

        should_email(merge_request.author)

        email = find_email_for(merge_request.author)
        expect(email).to have_header('X-GitLab-NotificationReason', NotificationReason::OWN_ACTIVITY)
      end

      it "doesn't email the author if they haven't opted into notifications about their activity" do
        notification.new_merge_request(merge_request, merge_request.author)

        should_not_email(merge_request.author)
      end

      it "emails subscribers of the merge request's labels" do
        user_1 = create(:user)
        user_2 = create(:user)
        user_3 = create(:user)
        user_4 = create(:user)
        label = create(:label, project: project, merge_requests: [merge_request])
        group_label = create(:group_label, group: group, merge_requests: [merge_request])
        label.toggle_subscription(user_1, project)
        group_label.toggle_subscription(user_2, project)
        group_label.toggle_subscription(user_3, another_project)
        group_label.toggle_subscription(user_4)

        notification.new_merge_request(merge_request, @u_disabled)

        should_email(user_1)
        should_email(user_2)
        should_not_email(user_3)
        should_email(user_4)
      end

      context 'participating' do
        it_should_behave_like 'participating by assignee notification' do
          let(:participant) { create(:user, username: 'user-participant')}
          let(:issuable) { merge_request }
          let(:notification_trigger) { notification.new_merge_request(merge_request, @u_disabled) }
        end

        it_should_behave_like 'participating by note notification' do
          let(:participant) { create(:user, username: 'user-participant')}
          let(:issuable) { merge_request }
          let(:notification_trigger) { notification.new_merge_request(merge_request, @u_disabled) }
        end

        context 'by author' do
          let(:participant) { create(:user, username: 'user-participant')}

          before do
            merge_request.author = participant
            merge_request.save
            notification.new_merge_request(merge_request, @u_disabled)
          end

          it { should_not_email(participant) }
        end
      end
    end

    describe '#new_mentions_in_merge_request' do
      let(:notification_method) { :new_mentions_in_merge_request }
      let(:mentionable) { merge_request }

      include_examples 'notifications for new mentions'
    end

    describe '#reassigned_merge_request' do
      let(:current_user) { create(:user) }

      before do
        update_custom_notification(:reassign_merge_request, @u_guest_custom, resource: project)
        update_custom_notification(:reassign_merge_request, @u_custom_global)
      end

      it do
        notification.reassigned_merge_request(merge_request, current_user, merge_request.author)

        should_email(merge_request.assignee)
        should_email(merge_request.author)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'adds "assigned" reason for new assignee' do
        notification.reassigned_merge_request(merge_request, current_user, merge_request.author)

        email = find_email_for(merge_request.assignee)

        expect(email).to have_header('X-GitLab-NotificationReason', NotificationReason::ASSIGNED)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { merge_request }
        let(:notification_trigger) { notification.reassigned_merge_request(merge_request, current_user, merge_request.author) }
      end
    end

    describe '#push_to_merge_request' do
      before do
        update_custom_notification(:push_to_merge_request, @u_guest_custom, resource: project)
        update_custom_notification(:push_to_merge_request, @u_custom_global)
      end

      it do
        notification.push_to_merge_request(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@u_watcher)
        should_not_email(@u_guest_watcher)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { merge_request }
        let(:notification_trigger) { notification.push_to_merge_request(merge_request, @u_disabled) }
      end
    end

    describe '#relabel_merge_request' do
      let(:group_label_1) { create(:group_label, group: group, title: 'Group Label 1', merge_requests: [merge_request]) }
      let(:group_label_2) { create(:group_label, group: group, title: 'Group Label 2') }
      let(:label_1) { create(:label, project: project, title: 'Label 1', merge_requests: [merge_request]) }
      let(:label_2) { create(:label, project: project, title: 'Label 2') }
      let!(:subscriber_to_group_label_1) { create(:user) { |u| group_label_1.toggle_subscription(u, project) } }
      let!(:subscriber_1_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u, project) } }
      let!(:subscriber_2_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u) } }
      let!(:subscriber_to_group_label_2_on_another_project) { create(:user) { |u| group_label_2.toggle_subscription(u, another_project) } }
      let!(:subscriber_to_label_1) { create(:user) { |u| label_1.toggle_subscription(u, project) } }
      let!(:subscriber_to_label_2) { create(:user) { |u| label_2.toggle_subscription(u, project) } }

      it "doesn't send email to anyone but subscribers of the given labels" do
        notification.relabeled_merge_request(merge_request, [group_label_2, label_2], @u_disabled)

        should_not_email(subscriber_to_label_1)
        should_not_email(subscriber_to_group_label_1)
        should_not_email(subscriber_to_group_label_2_on_another_project)
        should_email(subscriber_1_to_group_label_2)
        should_email(subscriber_2_to_group_label_2)
        should_email(subscriber_to_label_2)
        should_not_email(merge_request.assignee)
        should_not_email(merge_request.author)
        should_not_email(@u_watcher)
        should_not_email(@u_participant_mentioned)
        should_not_email(@subscriber)
        should_not_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_lazy_participant)
      end
    end

    describe '#removed_milestone_merge_request' do
      it_behaves_like 'altered milestone notification on merge request' do
        let(:milestone) { create(:milestone, project: project, merge_requests: [merge_request]) }
        let!(:subscriber_to_new_milestone) { create(:user) { |u| merge_request.toggle_subscription(u, project) } }

        before do
          notification.removed_milestone_merge_request(merge_request, merge_request.author)
        end
      end
    end

    describe '#changed_milestone_merge_request' do
      it_behaves_like 'altered milestone notification on merge request' do
        let(:new_milestone) { create(:milestone, project: project, merge_requests: [merge_request]) }
        let!(:subscriber_to_new_milestone) { create(:user) { |u| merge_request.toggle_subscription(u, project) } }

        before do
          notification.changed_milestone_merge_request(merge_request, new_milestone, merge_request.author)
        end
      end
    end

    describe '#merge_request_unmergeable' do
      it "sends email to merge request author" do
        notification.merge_request_unmergeable(merge_request)

        should_email(merge_request.author)
        expect(email_recipients.size).to eq(1)
      end

      describe 'when merge_when_pipeline_succeeds is true' do
        before do
          merge_request.update(
            merge_when_pipeline_succeeds: true,
            merge_user: create(:user)
          )
        end

        it "sends email to merge request author and merge_user" do
          notification.merge_request_unmergeable(merge_request)

          should_email(merge_request.author)
          should_email(merge_request.merge_user)
          expect(email_recipients.size).to eq(2)
        end
      end
    end

    describe '#closed_merge_request' do
      before do
        update_custom_notification(:close_merge_request, @u_guest_custom, resource: project)
        update_custom_notification(:close_merge_request, @u_custom_global)
      end

      it do
        notification.close_mr(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { merge_request }
        let(:notification_trigger) { notification.close_mr(merge_request, @u_disabled) }
      end
    end

    describe '#merged_merge_request' do
      before do
        update_custom_notification(:merge_merge_request, @u_guest_custom, resource: project)
        update_custom_notification(:merge_merge_request, @u_custom_global)
      end

      it do
        notification.merge_mr(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it "notifies the merger when the pipeline succeeds is true" do
        merge_request.merge_when_pipeline_succeeds = true
        notification.merge_mr(merge_request, @u_watcher)

        should_email(@u_watcher)
      end

      it "does not notify the merger when the pipeline succeeds is false" do
        merge_request.merge_when_pipeline_succeeds = false
        notification.merge_mr(merge_request, @u_watcher)

        should_not_email(@u_watcher)
      end

      it "notifies the merger when the pipeline succeeds is false but they've opted into notifications about their activity" do
        merge_request.merge_when_pipeline_succeeds = false
        @u_watcher.notified_of_own_activity = true
        notification.merge_mr(merge_request, @u_watcher)

        should_email(@u_watcher)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { merge_request }
        let(:notification_trigger) { notification.merge_mr(merge_request, @u_disabled) }
      end
    end

    describe '#reopen_merge_request' do
      before do
        update_custom_notification(:reopen_merge_request, @u_guest_custom, resource: project)
        update_custom_notification(:reopen_merge_request, @u_custom_global)
      end

      it do
        notification.reopen_mr(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { merge_request }
        let(:notification_trigger) { notification.reopen_mr(merge_request, @u_disabled) }
      end
    end

    describe "#resolve_all_discussions" do
      it do
        notification.resolve_all_discussions(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it_behaves_like 'participating notifications' do
        let(:participant) { create(:user, username: 'user-participant') }
        let(:issuable) { merge_request }
        let(:notification_trigger) { notification.resolve_all_discussions(merge_request, @u_disabled) }
      end
    end
  end

  describe 'Projects' do
    let(:project) { create(:project) }

    before do
      build_team(project)
      reset_delivered_emails!
    end

    describe '#project_was_moved' do
      it do
        notification.project_was_moved(project, "gitlab/gitlab")

        should_email(@u_watcher)
        should_email(@u_participating)
        should_email(@u_lazy_participant)
        should_email(@u_custom_global)
        should_not_email(@u_guest_watcher)
        should_not_email(@u_guest_custom)
        should_not_email(@u_disabled)
      end

      context 'users not having access to the new location' do
        it 'does not send email' do
          old_user = create(:user)
          ProjectAuthorization.create!(project: project, user: old_user, access_level: Gitlab::Access::GUEST)

          build_group(project)
          reset_delivered_emails!

          notification.project_was_moved(project, "gitlab/gitlab")

          should_email(@g_watcher)
          should_email(@g_global_watcher)
          should_email(project.creator)
          should_not_email(old_user)
        end
      end
    end

    context 'user with notifications disabled' do
      describe '#project_exported' do
        it do
          notification.project_exported(project, @u_disabled)

          should_not_email_anyone
        end
      end

      describe '#project_not_exported' do
        it do
          notification.project_not_exported(project, @u_disabled, ['error'])

          should_not_email_anyone
        end
      end
    end

    context 'user with notifications enabled' do
      describe '#project_exported' do
        it do
          notification.project_exported(project, @u_participating)

          should_only_email(@u_participating)
        end
      end

      describe '#project_not_exported' do
        it do
          notification.project_not_exported(project, @u_participating, ['error'])

          should_only_email(@u_participating)
        end
      end
    end
  end

  describe 'GroupMember' do
    let(:added_user) { create(:user) }

    describe '#new_access_request' do
      let(:maintainer) { create(:user) }
      let(:owner) { create(:user) }
      let(:developer) { create(:user) }
      let!(:group) do
        create(:group, :public, :access_requestable) do |group|
          group.add_owner(owner)
          group.add_maintainer(maintainer)
          group.add_developer(developer)
        end
      end

      before do
        reset_delivered_emails!
      end

      it 'sends notification to group owners_and_maintainers' do
        group.request_access(added_user)

        should_email(owner)
        should_email(maintainer)
        should_not_email(developer)
      end
    end

    describe '#decline_group_invite' do
      let(:creator) { create(:user) }
      let(:group) { create(:group) }
      let(:member) { create(:user) }

      before do
        group.add_owner(creator)
        group.add_developer(member, creator)
      end

      it do
        group_member = group.members.last

        expect do
          notification.decline_group_invite(group_member)
        end.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end

    describe '#new_group_member' do
      let(:group) { create(:group) }

      it 'sends a notification' do
        group.add_guest(added_user)
        should_only_email(added_user)
      end

      describe 'when notifications are disabled' do
        before do
          create_global_setting_for(added_user, :disabled)
        end

        it 'does not send a notification' do
          group.add_guest(added_user)
          should_not_email_anyone
        end
      end
    end
  end

  describe 'ProjectMember' do
    let(:project) { create(:project) }
    set(:added_user) { create(:user) }

    describe '#new_access_request' do
      context 'for a project in a user namespace' do
        let(:project) do
          create(:project, :public, :access_requestable) do |project|
            project.add_maintainer(project.owner)
          end
        end

        it 'sends notification to project owners_and_maintainers' do
          project.request_access(added_user)

          should_only_email(project.owner)
        end
      end

      context 'for a project in a group' do
        let(:group_owner) { create(:user) }
        let(:group) { create(:group).tap { |g| g.add_owner(group_owner) } }
        let!(:project) { create(:project, :public, :access_requestable, namespace: group) }

        before do
          reset_delivered_emails!
        end

        it 'sends notification to group owners_and_maintainers' do
          project.request_access(added_user)

          should_only_email(group_owner)
        end
      end
    end

    describe '#decline_group_invite' do
      let(:member) { create(:user) }

      before do
        project.add_developer(member, current_user: project.owner)
      end

      it do
        project_member = project.members.last

        expect do
          notification.decline_project_invite(project_member)
        end.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end

    describe '#new_project_member' do
      it do
        create_member!
        should_only_email(added_user)
      end

      context 'when notifications are disabled' do
        before do
          create_global_setting_for(added_user, :disabled)
        end

        it do
          create_member!
          should_not_email_anyone
        end
      end
    end

    def create_member!
      create(:project_member, user: added_user, project: project)
    end
  end

  context 'guest user in private project' do
    let(:private_project) { create(:project, :private) }
    let(:guest) { create(:user) }
    let(:developer) { create(:user) }
    let(:assignee) { create(:user) }
    let(:merge_request) { create(:merge_request, source_project: private_project, assignee: assignee) }
    let(:merge_request1) { create(:merge_request, source_project: private_project, assignee: assignee, description: "cc @#{guest.username}") }
    let(:note) { create(:note, noteable: merge_request, project: private_project) }

    before do
      private_project.add_developer(assignee)
      private_project.add_developer(developer)
      private_project.add_guest(guest)

      ActionMailer::Base.deliveries.clear
    end

    it 'filters out guests when new note is created' do
      expect(SentNotification).to receive(:record).with(merge_request, any_args).exactly(1).times

      notification.new_note(note)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when new merge request is created' do
      notification.new_merge_request(merge_request1, @u_disabled)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when merge request is closed' do
      notification.close_mr(merge_request, developer)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when merge request is reopened' do
      notification.reopen_mr(merge_request, developer)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when merge request is merged' do
      notification.merge_mr(merge_request, developer)

      should_not_email(guest)
      should_email(assignee)
    end
  end

  describe 'Pipelines' do
    describe '#pipeline_finished' do
      let(:project) { create(:project, :public, :repository) }
      let(:u_member) { create(:user) }
      let(:u_watcher) { create_user_with_notification(:watch, 'watcher') }

      let(:u_custom_notification_unset) do
        create_user_with_notification(:custom, 'custom_unset')
      end

      let(:u_custom_notification_enabled) do
        user = create_user_with_notification(:custom, 'custom_enabled')
        update_custom_notification(:success_pipeline, user, resource: project)
        update_custom_notification(:failed_pipeline, user, resource: project)
        user
      end

      let(:u_custom_notification_disabled) do
        user = create_user_with_notification(:custom, 'custom_disabled')
        update_custom_notification(:success_pipeline, user, resource: project, value: false)
        update_custom_notification(:failed_pipeline, user, resource: project, value: false)
        user
      end

      let(:commit) { project.commit }

      def create_pipeline(user, status)
        create(:ci_pipeline, status,
               project: project,
               user: user,
               ref: 'refs/heads/master',
               sha: commit.id,
               before_sha: '00000000')
      end

      before do
        project.add_maintainer(u_member)
        project.add_maintainer(u_watcher)
        project.add_maintainer(u_custom_notification_unset)
        project.add_maintainer(u_custom_notification_enabled)
        project.add_maintainer(u_custom_notification_disabled)

        reset_delivered_emails!
      end

      context 'with a successful pipeline' do
        context 'when the creator has default settings' do
          before do
            pipeline = create_pipeline(u_member, :success)
            notification.pipeline_finished(pipeline)
          end

          it 'notifies nobody' do
            should_not_email_anyone
          end
        end

        context 'when the creator has watch set' do
          before do
            pipeline = create_pipeline(u_watcher, :success)
            notification.pipeline_finished(pipeline)
          end

          it 'notifies nobody' do
            should_not_email_anyone
          end
        end

        context 'when the creator has custom notifications, but without any set' do
          before do
            pipeline = create_pipeline(u_custom_notification_unset, :success)
            notification.pipeline_finished(pipeline)
          end

          it 'notifies nobody' do
            should_not_email_anyone
          end
        end

        context 'when the creator has custom notifications disabled' do
          before do
            pipeline = create_pipeline(u_custom_notification_disabled, :success)
            notification.pipeline_finished(pipeline)
          end

          it 'notifies nobody' do
            should_not_email_anyone
          end
        end

        context 'when the creator has custom notifications enabled' do
          before do
            pipeline = create_pipeline(u_custom_notification_enabled, :success)
            notification.pipeline_finished(pipeline)
          end

          it 'emails only the creator' do
            should_only_email(u_custom_notification_enabled, kind: :bcc)
          end
        end
      end

      context 'with a failed pipeline' do
        context 'when the creator has no custom notification set' do
          before do
            pipeline = create_pipeline(u_member, :failed)
            notification.pipeline_finished(pipeline)
          end

          it 'emails only the creator' do
            should_only_email(u_member, kind: :bcc)
          end
        end

        context 'when the creator has watch set' do
          before do
            pipeline = create_pipeline(u_watcher, :failed)
            notification.pipeline_finished(pipeline)
          end

          it 'emails only the creator' do
            should_only_email(u_watcher, kind: :bcc)
          end
        end

        context 'when the creator has custom notifications, but without any set' do
          before do
            pipeline = create_pipeline(u_custom_notification_unset, :failed)
            notification.pipeline_finished(pipeline)
          end

          it 'emails only the creator' do
            should_only_email(u_custom_notification_unset, kind: :bcc)
          end
        end

        context 'when the creator has custom notifications disabled' do
          before do
            pipeline = create_pipeline(u_custom_notification_disabled, :failed)
            notification.pipeline_finished(pipeline)
          end

          it 'notifies nobody' do
            should_not_email_anyone
          end
        end

        context 'when the creator has custom notifications set' do
          before do
            pipeline = create_pipeline(u_custom_notification_enabled, :failed)
            notification.pipeline_finished(pipeline)
          end

          it 'emails only the creator' do
            should_only_email(u_custom_notification_enabled, kind: :bcc)
          end
        end

        context 'when the creator has no read_build access' do
          before do
            pipeline = create_pipeline(u_member, :failed)
            project.update(public_builds: false)
            project.team.truncate
            notification.pipeline_finished(pipeline)
          end

          it 'does not send emails' do
            should_not_email_anyone
          end
        end
      end
    end
  end

  describe 'Pages domains' do
    set(:project) { create(:project) }
    set(:domain) { create(:pages_domain, project: project) }
    set(:u_blocked) { create(:user, :blocked) }
    set(:u_silence) { create_user_with_notification(:disabled, 'silent', project) }
    set(:u_owner)   { project.owner }
    set(:u_maintainer1) { create(:user) }
    set(:u_maintainer2) { create(:user) }
    set(:u_developer) { create(:user) }

    before do
      project.add_maintainer(u_blocked)
      project.add_maintainer(u_silence)
      project.add_maintainer(u_maintainer1)
      project.add_maintainer(u_maintainer2)
      project.add_developer(u_developer)

      reset_delivered_emails!
    end

    %i[
      pages_domain_enabled
      pages_domain_disabled
      pages_domain_verification_succeeded
      pages_domain_verification_failed
    ].each do |sym|
      describe "##{sym}" do
        subject(:notify!) { notification.send(sym, domain) }

        it 'emails current watching maintainers' do
          expect(Notify).to receive(:"#{sym}_email").at_least(:once).and_call_original

          notify!

          should_only_email(u_maintainer1, u_maintainer2, u_owner)
        end

        it 'emails nobody if the project is missing' do
          domain.project = nil

          notify!

          should_not_email_anyone
        end
      end
    end

    describe '#pages_domain_verification_failed' do
      it 'emails current watching maintainers' do
        notification.pages_domain_verification_failed(domain)

        should_only_email(u_maintainer1, u_maintainer2, u_owner)
      end
    end

    describe '#pages_domain_enabled' do
      it 'emails current watching maintainers' do
        notification.pages_domain_enabled(domain)

        should_only_email(u_maintainer1, u_maintainer2, u_owner)
      end
    end

    describe '#pages_domain_disabled' do
      it 'emails current watching maintainers' do
        notification.pages_domain_disabled(domain)

        should_only_email(u_maintainer1, u_maintainer2, u_owner)
      end
    end
  end

  context 'Auto DevOps notifications' do
    describe '#autodevops_disabled' do
      let(:owner) { create(:user) }
      let(:namespace) { create(:namespace, owner: owner) }
      let(:project) { create(:project, :repository, :auto_devops, namespace: namespace) }
      let(:pipeline_user) { create(:user) }
      let(:pipeline) { create(:ci_pipeline, :failed, project: project, user: pipeline_user) }

      it 'emails project owner and user that triggered the pipeline' do
        notification.autodevops_disabled(pipeline, [owner.email, pipeline_user.email])

        should_email(owner)
        should_email(pipeline_user)
      end
    end
  end

  describe 'Repository cleanup' do
    let(:user) { create(:user) }
    let(:project) { create(:project) }

    describe '#repository_cleanup_success' do
      it 'emails the specified user only' do
        notification.repository_cleanup_success(project, user)

        should_email(user)
      end
    end

    describe '#repository_cleanup_failure' do
      it 'emails the specified user only' do
        notification.repository_cleanup_failure(project, user, 'Some error')

        should_email(user)
      end
    end
  end

  context 'Remote mirror notifications' do
    describe '#remote_mirror_update_failed' do
      let(:project) { create(:project) }
      let(:remote_mirror) { create(:remote_mirror, project: project) }
      let(:u_blocked) { create(:user, :blocked) }
      let(:u_silence) { create_user_with_notification(:disabled, 'silent-maintainer', project) }
      let(:u_owner)   { project.owner }
      let(:u_maintainer1) { create(:user) }
      let(:u_maintainer2) { create(:user) }
      let(:u_developer) { create(:user) }

      before do
        project.add_maintainer(u_blocked)
        project.add_maintainer(u_silence)
        project.add_maintainer(u_maintainer1)
        project.add_maintainer(u_maintainer2)
        project.add_developer(u_developer)

        # Mock remote update
        allow(project.repository).to receive(:async_remove_remote)
        allow(project.repository).to receive(:add_remote)

        reset_delivered_emails!
      end

      it 'emails current watching maintainers' do
        notification.remote_mirror_update_failed(remote_mirror)

        should_only_email(u_maintainer1, u_maintainer2, u_owner)
      end
    end
  end

  def build_team(project)
    @u_watcher               = create_global_setting_for(create(:user), :watch)
    @u_participating         = create_global_setting_for(create(:user), :participating)
    @u_participant_mentioned = create_global_setting_for(create(:user, username: 'participant'), :participating)
    @u_disabled              = create_global_setting_for(create(:user), :disabled)
    @u_mentioned             = create_global_setting_for(create(:user, username: 'mention'), :mention)
    @u_committer             = create(:user, username: 'committer')
    @u_not_mentioned         = create_global_setting_for(create(:user, username: 'regular'), :participating)
    @u_outsider_mentioned    = create(:user, username: 'outsider')
    @u_custom_global         = create_global_setting_for(create(:user, username: 'custom_global'), :custom)

    # User to be participant by default
    # This user does not contain any record in notification settings table
    # It should be treated with a :participating notification_level
    @u_lazy_participant      = create(:user, username: 'lazy-participant')

    @u_guest_watcher = create_user_with_notification(:watch, 'guest_watching')
    @u_guest_custom = create_user_with_notification(:custom, 'guest_custom')

    project.add_maintainer(@u_watcher)
    project.add_maintainer(@u_participating)
    project.add_maintainer(@u_participant_mentioned)
    project.add_maintainer(@u_disabled)
    project.add_maintainer(@u_mentioned)
    project.add_maintainer(@u_committer)
    project.add_maintainer(@u_not_mentioned)
    project.add_maintainer(@u_lazy_participant)
    project.add_maintainer(@u_custom_global)
  end

  # Users in the project's group but not part of project's team
  # with different notification settings
  def build_group(project, visibility: :public)
    group = create_nested_group(visibility)
    project.update(namespace_id: group.id)

    # Group member: global=disabled, group=watch
    @g_watcher ||= create_user_with_notification(:watch, 'group_watcher', project.group)
    @g_watcher.notification_settings_for(nil).disabled!

    # Group member: global=watch, group=global
    @g_global_watcher ||= create_global_setting_for(create(:user), :watch)
    group.add_users([@g_watcher, @g_global_watcher], :maintainer)

    group
  end

  # Creates a nested group only if supported
  # to avoid errors on MySQL
  def create_nested_group(visibility)
    if Group.supports_nested_objects?
      parent_group = create(:group, visibility)
      child_group = create(:group, visibility, parent: parent_group)

      # Parent group member: global=disabled, parent_group=watch, child_group=global
      @pg_watcher ||= create_user_with_notification(:watch, 'parent_group_watcher', parent_group)
      @pg_watcher.notification_settings_for(nil).disabled!

      # Parent group member: global=global, parent_group=disabled, child_group=global
      @pg_disabled ||= create_user_with_notification(:disabled, 'parent_group_disabled', parent_group)
      @pg_disabled.notification_settings_for(nil).global!

      # Parent group member: global=global, parent_group=mention, child_group=global
      @pg_mention ||= create_user_with_notification(:mention, 'parent_group_mention', parent_group)
      @pg_mention.notification_settings_for(nil).global!

      # Parent group member: global=global, parent_group=participating, child_group=global
      @pg_participant ||= create_user_with_notification(:participating, 'parent_group_participant', parent_group)
      @pg_mention.notification_settings_for(nil).global!

      child_group
    else
      create(:group, visibility)
    end
  end

  def add_member_for_parent_group(user, project)
    return unless Group.supports_nested_objects?

    project.reload

    project.group.parent.add_maintainer(user)
  end

  def should_email_nested_group_user(user, times: 1, recipients: email_recipients)
    return unless Group.supports_nested_objects?

    should_email(user, times: 1, recipients: email_recipients)
  end

  def should_not_email_nested_group_user(user, recipients: email_recipients)
    return unless Group.supports_nested_objects?

    should_not_email(user, recipients: email_recipients)
  end

  def add_users_with_subscription(project, issuable)
    @subscriber = create :user
    @unsubscriber = create :user
    @unsubscribed_mentioned = create :user, username: 'unsubscribed_mentioned'
    @subscribed_participant = create_global_setting_for(create(:user, username: 'subscribed_participant'), :participating)
    @watcher_and_subscriber = create_global_setting_for(create(:user), :watch)

    project.add_maintainer(@subscribed_participant)
    project.add_maintainer(@subscriber)
    project.add_maintainer(@unsubscriber)
    project.add_maintainer(@watcher_and_subscriber)
    project.add_maintainer(@unsubscribed_mentioned)

    issuable.subscriptions.create(user: @unsubscribed_mentioned, project: project, subscribed: false)
    issuable.subscriptions.create(user: @subscriber, project: project, subscribed: true)
    issuable.subscriptions.create(user: @subscribed_participant, project: project, subscribed: true)
    issuable.subscriptions.create(user: @unsubscriber, project: project, subscribed: false)
    # Make the watcher a subscriber to detect dupes
    issuable.subscriptions.create(user: @watcher_and_subscriber, project: project, subscribed: true)
  end
end

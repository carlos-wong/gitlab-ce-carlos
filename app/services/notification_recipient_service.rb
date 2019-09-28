# frozen_string_literal: true

#
# Used by NotificationService to determine who should receive notification
#
module NotificationRecipientService
  def self.notifiable_users(users, *args)
    users.compact.map { |u| NotificationRecipient.new(u, *args) }.select(&:notifiable?).map(&:user)
  end

  def self.notifiable?(user, *args)
    NotificationRecipient.new(user, *args).notifiable?
  end

  def self.build_recipients(*args)
    Builder::Default.new(*args).notification_recipients
  end

  def self.build_new_note_recipients(*args)
    Builder::NewNote.new(*args).notification_recipients
  end

  def self.build_merge_request_unmergeable_recipients(*args)
    Builder::MergeRequestUnmergeable.new(*args).notification_recipients
  end

  def self.build_project_maintainers_recipients(*args)
    Builder::ProjectMaintainers.new(*args).notification_recipients
  end

  module Builder
    class Base
      def initialize(*)
        raise 'abstract'
      end

      def build!
        raise 'abstract'
      end

      def filter!
        recipients.select!(&:notifiable?)
      end

      def acting_user
        current_user
      end

      def target
        raise 'abstract'
      end

      def project
        target.project
      end

      def group
        project&.group || target.try(:group)
      end

      def recipients
        @recipients ||= []
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def add_recipients(users, type, reason)
        if users.is_a?(ActiveRecord::Relation)
          users = users.includes(:notification_settings)
        end

        users = Array(users).compact
        recipients.concat(users.map { |u| make_recipient(u, type, reason) })
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def user_scope
        User.includes(:notification_settings)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def make_recipient(user, type, reason)
        NotificationRecipient.new(
          user, type,
          reason: reason,
          project: project,
          group: group,
          custom_action: custom_action,
          target: target,
          acting_user: acting_user
        )
      end

      def notification_recipients
        @notification_recipients ||=
          begin
            build!
            filter!
            recipients = self.recipients.sort_by { |r| NotificationReason.priority(r.reason) }.uniq(&:user)
            recipients.freeze
          end
      end

      def custom_action
        nil
      end

      protected

      def add_participants(user)
        return unless target.respond_to?(:participants)

        add_recipients(target.participants(user), :participating, nil)
      end

      def add_mentions(user, target:)
        return unless target.respond_to?(:mentioned_users)

        add_recipients(target.mentioned_users(user), :mention, NotificationReason::MENTIONED)
      end

      # Get project/group users with CUSTOM notification level
      # rubocop: disable CodeReuse/ActiveRecord
      def add_custom_notifications
        user_ids = []

        # Users with a notification setting on group or project
        user_ids += user_ids_notifiable_on(project, :custom)
        user_ids += user_ids_notifiable_on(group, :custom)

        # Users with global level custom
        user_ids_with_project_level_global = user_ids_notifiable_on(project, :global)
        user_ids_with_group_level_global   = user_ids_notifiable_on(group, :global)

        global_users_ids = user_ids_with_project_level_global.concat(user_ids_with_group_level_global)
        user_ids += user_ids_with_global_level_custom(global_users_ids, custom_action)

        add_recipients(user_scope.where(id: user_ids), :custom, nil)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def add_project_watchers
        add_recipients(project_watchers, :watch, nil) if project
      end

      def add_group_watchers
        add_recipients(group_watchers, :watch, nil)
      end

      # Get project users with WATCH notification level
      # rubocop: disable CodeReuse/ActiveRecord
      def project_watchers
        project_members_ids = user_ids_notifiable_on(project)

        user_ids_with_project_global = user_ids_notifiable_on(project, :global)
        user_ids_with_group_global   = user_ids_notifiable_on(project.group, :global)

        user_ids = user_ids_with_global_level_watch((user_ids_with_project_global + user_ids_with_group_global).uniq)

        user_ids_with_project_setting = select_project_members_ids(user_ids_with_project_global, user_ids)
        user_ids_with_group_setting = select_group_members_ids(project.group, project_members_ids, user_ids_with_group_global, user_ids)

        user_scope.where(id: user_ids_with_project_setting.concat(user_ids_with_group_setting).uniq)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def group_watchers
        user_ids_with_group_global = user_ids_notifiable_on(group, :global)
        user_ids = user_ids_with_global_level_watch(user_ids_with_group_global)
        user_ids_with_group_setting = select_group_members_ids(group, [], user_ids_with_group_global, user_ids)

        user_scope.where(id: user_ids_with_group_setting)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def add_subscribed_users
        return unless target.respond_to? :subscribers

        add_recipients(target.subscribers(project), :subscription, nil)
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def user_ids_notifiable_on(resource, notification_level = nil)
        return [] unless resource

        scope = resource.notification_settings

        if notification_level
          scope = scope.where(level: NotificationSetting.levels[notification_level])
        end

        scope.pluck(:user_id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # Build a list of user_ids based on project notification settings
      def select_project_members_ids(global_setting, user_ids_global_level_watch)
        user_ids = user_ids_notifiable_on(project, :watch)

        # If project setting is global, add to watch list if global setting is watch
        user_ids + (global_setting & user_ids_global_level_watch)
      end

      # Build a list of user_ids based on group notification settings
      def select_group_members_ids(group, project_members, global_setting, user_ids_global_level_watch)
        uids = user_ids_notifiable_on(group, :watch)

        # Group setting is global, add to user_ids list if global setting is watch
        uids + (global_setting & user_ids_global_level_watch) - project_members
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def user_ids_with_global_level_watch(ids)
        settings_with_global_level_of(:watch, ids).pluck(:user_id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def user_ids_with_global_level_custom(ids, action)
        settings_with_global_level_of(:custom, ids).pluck(:user_id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def settings_with_global_level_of(level, ids)
        NotificationSetting.where(
          user_id: ids,
          source_type: nil,
          level: NotificationSetting.levels[level]
        )
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def add_labels_subscribers(labels: nil)
        return unless target.respond_to? :labels

        (labels || target.labels).each do |label|
          add_recipients(label.subscribers(project), :subscription, nil)
        end
      end
    end

    class Default < Base
      MENTION_TYPE_ACTIONS = [:new_issue, :new_merge_request].freeze

      attr_reader :target
      attr_reader :current_user
      attr_reader :action
      attr_reader :previous_assignees
      attr_reader :skip_current_user

      def initialize(target, current_user, action:, custom_action: nil, previous_assignees: nil, skip_current_user: true)
        @target = target
        @current_user = current_user
        @action = action
        @custom_action = custom_action
        @previous_assignees = previous_assignees
        @skip_current_user = skip_current_user
      end

      def add_watchers
        add_project_watchers
      end

      def build!
        add_participants(current_user)
        add_watchers
        add_custom_notifications

        # Re-assign is considered as a mention of the new assignee
        case custom_action
        when :reassign_merge_request, :reassign_issue
          add_recipients(previous_assignees, :mention, nil)
          add_recipients(target.assignees, :mention, NotificationReason::ASSIGNED)
        end

        add_subscribed_users

        if self.class.mention_type_actions.include?(custom_action)
          # These will all be participants as well, but adding with the :mention
          # type ensures that users with the mention notification level will
          # receive them, too.
          add_mentions(current_user, target: target)

          # We use the `:participating` notification level in order to match existing legacy behavior as captured
          # in existing specs (notification_service_spec.rb ~ line 507)
          if target.is_a?(Issuable)
            add_recipients(target.assignees, :participating, NotificationReason::ASSIGNED)
          end

          add_labels_subscribers
        end
      end

      def acting_user
        current_user if skip_current_user
      end

      # Build event key to search on custom notification level
      # Check NotificationSetting.email_events
      def custom_action
        @custom_action ||= "#{action}_#{target.class.model_name.name.underscore}".to_sym
      end

      def self.mention_type_actions
        MENTION_TYPE_ACTIONS.dup
      end
    end

    class NewNote < Base
      attr_reader :note
      def initialize(note)
        @note = note
      end

      def target
        note.noteable
      end

      # NOTE: may be nil, in the case of a PersonalSnippet
      #
      # (this is okay because NotificationRecipient is written
      # to handle nil projects)
      def project
        note.project
      end

      def group
        if note.for_project_noteable?
          project.group
        else
          target.try(:group)
        end
      end

      def build!
        # Add all users participating in the thread (author, assignee, comment authors)
        add_participants(note.author)
        add_mentions(note.author, target: note)

        if note.for_project_noteable?
          # Merge project watchers
          add_project_watchers
        else
          add_group_watchers
        end

        add_custom_notifications
        add_subscribed_users
      end

      def custom_action
        :new_note
      end

      def acting_user
        note.author
      end
    end

    class MergeRequestUnmergeable < Base
      attr_reader :target
      def initialize(merge_request)
        @target = merge_request
      end

      def build!
        target.merge_participants.each do |user|
          add_recipients(user, :participating, nil)
        end
      end

      def custom_action
        :unmergeable_merge_request
      end

      def acting_user
        nil
      end
    end

    class ProjectMaintainers < Base
      attr_reader :target

      def initialize(target, action:)
        @target = target
        @action = action
      end

      def build!
        return [] unless project

        add_recipients(project.team.maintainers, :mention, nil)
      end

      def acting_user
        nil
      end
    end
  end
end

NotificationRecipientService::Builder::Default.prepend_if_ee('EE::NotificationRecipientBuilders::Default') # rubocop: disable Cop/InjectEnterpriseEditionModule
NotificationRecipientService.prepend_if_ee('EE::NotificationRecipientService')

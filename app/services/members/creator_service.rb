# frozen_string_literal: true

module Members
  # This class serves as more of an app-wide way we add/create members
  # All roads to add members should take this path.
  class CreatorService
    class << self
      def parsed_access_level(access_level)
        access_levels.fetch(access_level) { access_level.to_i }
      end

      def access_levels
        Gitlab::Access.sym_options_with_owner
      end

      def add_members( # rubocop:disable Metrics/ParameterLists
        source,
        invitees,
        access_level,
        current_user: nil,
        expires_at: nil,
        tasks_to_be_done: [],
        tasks_project_id: nil,
        ldap: nil,
        blocking_refresh: nil
      )
        return [] unless invitees.present?

        # If this user is attempting to manage Owner members and doesn't have permission, do not allow
        return [] if managing_owners?(current_user, access_level) && cannot_manage_owners?(source, current_user)

        emails, users, existing_members = parse_users_list(source, invitees)

        Member.transaction do
          common_arguments = {
            source: source,
            access_level: access_level,
            existing_members: existing_members,
            current_user: current_user,
            expires_at: expires_at,
            tasks_to_be_done: tasks_to_be_done,
            tasks_project_id: tasks_project_id,
            ldap: ldap,
            blocking_refresh: blocking_refresh
          }

          members = emails.map do |email|
            new(invitee: email, builder: InviteMemberBuilder, **common_arguments).execute
          end

          members += users.map do |user|
            new(invitee: user, **common_arguments).execute
          end

          members
        end
      end

      def add_member( # rubocop:disable Metrics/ParameterLists
        source,
        invitee,
        access_level,
        current_user: nil,
        expires_at: nil,
        ldap: nil,
        blocking_refresh: nil
      )
        add_members(source,
                  [invitee],
                  access_level,
                  current_user: current_user,
                  expires_at: expires_at,
                  ldap: ldap,
                  blocking_refresh: blocking_refresh).first
      end

      private

      def managing_owners?(current_user, access_level)
        current_user && Gitlab::Access.sym_options_with_owner[access_level] == Gitlab::Access::OWNER
      end

      def parse_users_list(source, list)
        emails = []
        user_ids = []
        users = []
        existing_members = {}

        list.each do |item|
          case item
          when User
            users << item
          when Integer
            user_ids << item
          when /\A\d+\Z/
            user_ids << item.to_i
          when Devise.email_regexp
            emails << item
          end
        end

        # the below will automatically discard invalid user_ids
        users.concat(User.id_in(user_ids)) if user_ids.present?
        # de-duplicate just in case as there is no controlling if user records and ids are sent multiple times
        users.uniq!

        users_by_emails = source.users_by_emails(emails) # preloads our request store for all emails
        # in case emails belong to a user that is being invited by user or user_id, remove them from
        # emails and let users/user_ids handle it.
        parsed_emails = emails.select do |email|
          user = users_by_emails[email]
          !user || (users.exclude?(user) && user_ids.exclude?(user.id))
        end

        if users.present? || users_by_emails.present?
          # helps not have to perform another query per user id to see if the member exists later on when fetching
          existing_members = source.members_and_requesters.with_user(users + users_by_emails.values).index_by(&:user_id)
        end

        [parsed_emails, users, existing_members]
      end
    end

    def initialize(invitee:, builder: StandardMemberBuilder, **args)
      @invitee = invitee
      @builder = builder
      @args = args
      @access_level = self.class.parsed_access_level(args[:access_level])
    end

    private_class_method :new

    def execute
      find_or_build_member
      commit_member
      after_commit_tasks

      member
    end

    private

    delegate :new_record?, to: :member
    attr_reader :invitee, :access_level, :member, :args, :builder

    def assign_member_attributes
      member.attributes = member_attributes
    end

    def commit_member
      if can_commit_member?
        assign_member_attributes
        commit_changes
      else
        add_commit_error
      end
    end

    def can_commit_member?
      # There is no current user for bulk actions, in which case anything is allowed
      return true if skip_authorization?

      if new_record?
        can_create_new_member?
      else
        can_update_existing_member?
      end
    end

    def can_create_new_member?
      raise NotImplementedError
    end

    def can_update_existing_member?
      raise NotImplementedError
    end

    # Populates the attributes of a member.
    #
    # This logic resides in a separate method so that EE can extend this logic,
    # without having to patch the `add_members` method directly.
    def member_attributes
      {
        created_by: member.created_by || current_user,
        access_level: access_level,
        expires_at: args[:expires_at]
      }
    end

    def commit_changes
      if member.request?
        approve_request
      elsif member.changed?
        # Calling #save triggers callbacks even if there is no change on object.
        # This previously caused an incident due to the hard to predict
        # behaviour caused by the large number of callbacks.
        # See https://gitlab.com/gitlab-com/gl-infra/production/-/issues/6351
        # and https://gitlab.com/gitlab-org/gitlab/-/merge_requests/80920#note_911569038
        # for details.
        member.save
      end
    end

    def after_commit_tasks
      create_member_task
    end

    def create_member_task
      return unless member.persisted?
      return if member_task_attributes.value?(nil)
      return if member.member_task.present?

      member.create_member_task(member_task_attributes)
    end

    def member_task_attributes
      {
        tasks_to_be_done: args[:tasks_to_be_done],
        project_id: args[:tasks_project_id]
      }
    end

    def approve_request
      ::Members::ApproveAccessRequestService.new(current_user,
                                                 access_level: access_level)
                                            .execute(
                                              member,
                                              skip_authorization: ldap,
                                              skip_log_audit_event: ldap
                                            )
    end

    def current_user
      args[:current_user]
    end

    def skip_authorization?
      !current_user
    end

    def add_commit_error
      msg = if new_record?
              _('not authorized to create member')
            else
              _('not authorized to update member')
            end

      member.errors.add(:base, msg)
    end

    def find_or_build_member
      @member = builder.new(source, invitee, existing_members).execute

      @member.blocking_refresh = args[:blocking_refresh]
    end

    def ldap
      args[:ldap] || false
    end

    def source
      args[:source]
    end

    def existing_members
      args[:existing_members] || {}
    end
  end
end

Members::CreatorService.prepend_mod_with('Members::CreatorService')

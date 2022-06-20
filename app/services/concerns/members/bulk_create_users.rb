# frozen_string_literal: true

module Members
  module BulkCreateUsers
    extend ActiveSupport::Concern

    included do
      class << self
        def add_users(source, users, access_level, current_user: nil, expires_at: nil, tasks_to_be_done: [], tasks_project_id: nil)
          return [] unless users.present?

          emails, users, existing_members = parse_users_list(source, users)

          Member.transaction do
            (emails + users).map! do |user|
              new(source,
                  user,
                  access_level,
                  existing_members: existing_members,
                  current_user: current_user,
                  expires_at: expires_at,
                  tasks_to_be_done: tasks_to_be_done,
                  tasks_project_id: tasks_project_id)
                .execute
            end
          end
        end

        private

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
          users.uniq! # de-duplicate just in case as there is no controlling if user records and ids are sent multiple times

          users_by_emails = source.users_by_emails(emails) # preloads our request store for all emails
          # in case emails belong to a user that is being invited by user or user_id, remove them from
          # emails and let users/user_ids handle it.
          parsed_emails = emails.select do |email|
            user = users_by_emails[email]
            !user || (users.exclude?(user) && user_ids.exclude?(user.id))
          end

          if users.present?
            # helps not have to perform another query per user id to see if the member exists later on when fetching
            existing_members = source.members_and_requesters.with_user(users).index_by(&:user_id)
          end

          [parsed_emails, users, existing_members]
        end
      end
    end

    def initialize(source, user, access_level, **args)
      super

      @existing_members = args[:existing_members] || (raise ArgumentError, "existing_members must be included in the args hash")
    end

    private

    attr_reader :existing_members

    def find_or_initialize_member_by_user
      existing_members[user.id] || source.members.build(user_id: user.id)
    end
  end
end

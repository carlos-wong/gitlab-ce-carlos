# frozen_string_literal: true

class PersonalSnippetPolicy < BasePolicy
  condition(:public_snippet, scope: :subject) { @subject.public? }
  condition(:is_author) { @user && @subject.author == @user }
  condition(:internal_snippet, scope: :subject) { @subject.internal? }

  rule { public_snippet }.policy do
    enable :read_personal_snippet
    enable :create_note
  end

  rule { is_author | admin }.policy do
    enable :read_personal_snippet
    enable :update_personal_snippet
    enable :admin_personal_snippet
    enable :create_note
  end

  rule { internal_snippet & ~external_user }.policy do
    enable :read_personal_snippet
    enable :create_note
  end

  rule { anonymous }.prevent :create_note

  rule { can?(:create_note) }.enable :award_emoji

  rule { can?(:read_all_resources) }.enable :read_personal_snippet

  # Aliasing the ability to ease GraphQL permissions check
  rule { can?(:read_personal_snippet) }.enable :read_snippet
end

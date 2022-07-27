# frozen_string_literal: true

class ProjectMember < Member
  extend ::Gitlab::Utils::Override
  SOURCE_TYPE = 'Project'
  SOURCE_TYPE_FORMAT = /\AProject\z/.freeze

  belongs_to :project, foreign_key: 'source_id'

  delegate :namespace_id, to: :project

  # Make sure project member points only to project as it source
  default_value_for :source_type, SOURCE_TYPE
  validates :source_type, format: { with: SOURCE_TYPE_FORMAT }
  default_scope { where(source_type: SOURCE_TYPE) } # rubocop:disable Cop/DefaultScope

  scope :in_project, ->(project) { where(source_id: project.id) }
  scope :in_namespaces, ->(groups) do
    joins('INNER JOIN projects ON projects.id = members.source_id')
      .where(projects: { namespace_id: groups.select(:id) })
  end

  class << self
    # Add members to projects with passed access option
    #
    # access can be an integer representing a access code
    # or symbol like :maintainer representing role
    #
    # Ex.
    #   add_members_to_projects(
    #     project_ids,
    #     user_ids,
    #     ProjectMember::MAINTAINER
    #   )
    #
    #   add_members_to_projects(
    #     project_ids,
    #     user_ids,
    #     :maintainer
    #   )
    #
    def add_members_to_projects(project_ids, users, access_level, current_user: nil, expires_at: nil)
      self.transaction do
        project_ids.each do |project_id|
          project = Project.find(project_id)

          Members::Projects::CreatorService.add_members( # rubocop:disable CodeReuse/ServiceClass
            project,
            users,
            access_level,
            current_user: current_user,
            expires_at: expires_at
          )
        end
      end
    end

    def truncate_teams(project_ids)
      ProjectMember.transaction do
        members = ProjectMember.where(source_id: project_ids)

        members.each do |member|
          member.destroy
        end
      end

      true
    rescue StandardError
      false
    end

    def truncate_team(project)
      truncate_teams [project.id]
    end

    # For those who get to see a modal with a role dropdown, here are the options presented
    def permissible_access_level_roles(current_user, project)
      # This method is a stopgap in preparation for https://gitlab.com/gitlab-org/gitlab/-/issues/364087
      if Ability.allowed?(current_user, :manage_owners, project)
        Gitlab::Access.options_with_owner
      else
        ProjectMember.access_level_roles
      end
    end

    def access_level_roles
      Gitlab::Access.options
    end
  end

  def project
    source
  end

  def notifiable_options
    { project: project }
  end

  private

  override :access_level_inclusion
  def access_level_inclusion
    unless access_level.in?(Gitlab::Access.all_values)
      errors.add(:access_level, "is not included in the list")
    end
  end

  override :refresh_member_authorized_projects
  def refresh_member_authorized_projects(blocking:)
    return unless user

    # rubocop:disable CodeReuse/ServiceClass
    if blocking
      AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker.bulk_perform_and_wait([[project.id, user.id]])
    else
      AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker.perform_async(project.id, user.id)
    end

    # Until we compare the inconsistency rates of the new, specialized service and
    # the old approach, we still run AuthorizedProjectsWorker
    # but with some delay and lower urgency as a safety net.
    UserProjectAccessChangedService.new(user_id)
                                   .execute(blocking: false, priority: UserProjectAccessChangedService::LOW_PRIORITY)
    # rubocop:enable CodeReuse/ServiceClass
  end

  # TODO: https://gitlab.com/groups/gitlab-org/-/epics/7054
  # temporary until we can we properly remove the source columns
  override :set_member_namespace_id
  def set_member_namespace_id
    self.member_namespace_id = project&.project_namespace_id
  end

  def send_invite
    run_after_commit_or_now { notification_service.invite_project_member(self, @raw_invite_token) }

    super
  end

  def post_create_hook
    # The creator of a personal project gets added as a `ProjectMember`
    # with `OWNER` access during creation of a personal project,
    # but we do not want to trigger notifications to the same person who created the personal project.
    unless project.personal_namespace_holder?(user)
      event_service.join_project(self.project, self.user)
      run_after_commit_or_now { notification_service.new_project_member(self) }
    end

    super
  end

  def post_update_hook
    if saved_change_to_access_level?
      run_after_commit { notification_service.update_project_member(self) }
    end

    super
  end

  def post_destroy_hook
    if expired?
      event_service.expired_leave_project(self.project, self.user)
    else
      event_service.leave_project(self.project, self.user)
    end

    super
  end

  def after_accept_invite
    run_after_commit_or_now do
      notification_service.accept_project_invite(self)
    end

    super
  end

  def after_decline_invite
    notification_service.decline_project_invite(self)

    super
  end

  # rubocop: disable CodeReuse/ServiceClass
  def event_service
    EventCreateService.new
  end
  # rubocop: enable CodeReuse/ServiceClass
end

ProjectMember.prepend_mod_with('ProjectMember')

# frozen_string_literal: true

class ForkTargetsFinder
  def initialize(project, user)
    @project = project
    @user = user
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def execute
    ::Namespace.where(id: user.manageable_namespaces).sort_by_type
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  attr_reader :project, :user
end

ForkTargetsFinder.prepend_if_ee('EE::ForkTargetsFinder')

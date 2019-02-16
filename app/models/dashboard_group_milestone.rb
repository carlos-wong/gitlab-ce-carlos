# frozen_string_literal: true
# Dashboard Group Milestones are milestones that allow us to pull more info out for the UI that the Milestone object doesn't allow for
class DashboardGroupMilestone < GlobalMilestone
  extend ::Gitlab::Utils::Override

  attr_reader :group_name

  def initialize(milestone)
    super

    @group_name = milestone.group.full_name
  end

  def self.build_collection(groups, params)
    milestones = Milestone.of_groups(groups.select(:id))
             .reorder_by_due_date_asc
             .order_by_name_asc
             .active
    milestones = milestones.search_title(params[:search_title]) if params[:search_title].present?
    milestones.map { |m| new(m) }
  end
end

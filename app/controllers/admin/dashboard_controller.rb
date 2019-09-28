# frozen_string_literal: true

class Admin::DashboardController < Admin::ApplicationController
  include CountHelper

  COUNTED_ITEMS = [Project, User, Group].freeze

  # rubocop: disable CodeReuse/ActiveRecord
  def index
    @counts = Gitlab::Database::Count.approximate_counts(COUNTED_ITEMS)
    @projects = Project.order_id_desc.without_deleted.with_route.limit(10)
    @users = User.order_id_desc.limit(10)
    @groups = Group.order_id_desc.with_route.limit(10)
  end
  # rubocop: enable CodeReuse/ActiveRecord
end

Admin::DashboardController.prepend_if_ee('EE::Admin::DashboardController')

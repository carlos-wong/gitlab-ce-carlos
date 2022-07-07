# frozen_string_literal: true

module Ci
  class RunnerJobsFinder
    attr_reader :runner, :params

    ALLOWED_INDEXED_COLUMNS = %w[id].freeze

    def initialize(runner, current_user, params = {})
      @runner = runner
      @user = current_user
      @params = params
    end

    def execute
      items = @runner.builds
      items = by_permission(items)
      items = by_status(items)
      sort_items(items)
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def by_permission(items)
      return items if @user.can_read_all_resources?

      items.for_project(@user.authorized_project_mirrors(Gitlab::Access::REPORTER).select(:project_id))
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def by_status(items)
      return items unless Ci::HasStatus::AVAILABLE_STATUSES.include?(params[:status])

      items.where(status: params[:status])
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def sort_items(items)
      return items unless ALLOWED_INDEXED_COLUMNS.include?(params[:order_by])

      order_by = params[:order_by]
      sort = if /\A(ASC|DESC)\z/i.match?(params[:sort])
               params[:sort]
             else
               :desc
             end

      items.order(order_by => sort)
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end

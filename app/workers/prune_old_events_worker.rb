# frozen_string_literal: true

class PruneOldEventsWorker
  include ApplicationWorker
  include CronjobQueue

  feature_category_not_owned!

  # rubocop: disable CodeReuse/ActiveRecord
  def perform
    # Contribution calendar shows maximum 12 months of events, we retain 3 years for data integrity.
    # Double nested query is used because MySQL doesn't allow DELETE subqueries on the same table.
    Event.unscoped.where(
      '(id IN (SELECT id FROM (?) ids_to_remove))',
      Event.unscoped.where(
        'created_at < ?',
        (3.years + 1.day).ago)
      .select(:id)
      .limit(10_000))
    .delete_all
  end
  # rubocop: enable CodeReuse/ActiveRecord
end

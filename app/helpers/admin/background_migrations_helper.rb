# frozen_string_literal: true

module Admin
  module BackgroundMigrationsHelper
    def batched_migration_status_badge_variant(migration)
      variants = {
        active: :info,
        paused: :warning,
        failed: :danger,
        finished: :success
      }

      variants[migration.status_name]
    end

    # The extra logic here is needed because total_tuple_count is just
    # an estimate and completed_rows also does not account for last jobs
    # whose batch size is likely larger than the actual number of rows processed
    def batched_migration_progress(migration, completed_rows)
      return 100 if migration.finished?
      return 0 unless completed_rows.to_i > 0
      return unless migration.total_tuple_count.to_i > 0

      [100 * completed_rows / migration.total_tuple_count, 99].min
    end
  end
end

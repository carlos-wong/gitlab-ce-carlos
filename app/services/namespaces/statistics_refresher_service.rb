# frozen_string_literal: true

module Namespaces
  class StatisticsRefresherService
    RefresherError = Class.new(StandardError)

    def execute(root_namespace)
      root_storage_statistics = find_or_create_root_storage_statistics(root_namespace.id)

      root_storage_statistics.recalculate!
    rescue ActiveRecord::ActiveRecordError => e
      raise RefresherError.new(e.message)
    end

    private

    def find_or_create_root_storage_statistics(root_namespace_id)
      Namespace::RootStorageStatistics
        .safe_find_or_create_by!(namespace_id: root_namespace_id)
    end
  end
end

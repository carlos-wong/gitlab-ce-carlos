# frozen_string_literal: true

module Users
  class GroupCallout < ApplicationRecord
    include Users::Calloutable

    self.table_name = 'user_group_callouts'

    belongs_to :group

    enum feature_name: {
      invite_members_banner: 1,
      approaching_seat_count_threshold: 2, # EE-only
      storage_enforcement_banner_first_enforcement_threshold: 3,
      storage_enforcement_banner_second_enforcement_threshold: 4,
      storage_enforcement_banner_third_enforcement_threshold: 5,
      storage_enforcement_banner_fourth_enforcement_threshold: 6,
      preview_user_over_limit_free_plan_alert: 7, # EE-only
      user_reached_limit_free_plan_alert: 8 # EE-only
    }

    validates :group, presence: true
    validates :feature_name,
              presence: true,
              uniqueness: { scope: [:user_id, :group_id] },
              inclusion: { in: GroupCallout.feature_names.keys }

    def source_feature_name
      "#{feature_name}_#{group_id}"
    end
  end
end

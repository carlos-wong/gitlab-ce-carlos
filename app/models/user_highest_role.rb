# frozen_string_literal: true

class UserHighestRole < ApplicationRecord
  belongs_to :user, optional: false

  validates :highest_access_level, allow_nil: true, inclusion: { in: Gitlab::Access.all_values }
end

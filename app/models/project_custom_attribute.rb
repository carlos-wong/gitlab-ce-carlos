# frozen_string_literal: true

class ProjectCustomAttribute < ApplicationRecord
  belongs_to :project

  validates :project, :key, :value, presence: true
  validates :key, uniqueness: { scope: [:project_id] }
end

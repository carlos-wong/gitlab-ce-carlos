# frozen_string_literal: true

class RedirectRoute < ApplicationRecord
  belongs_to :source, polymorphic: true # rubocop:disable Cop/PolymorphicAssociations

  validates :source, presence: true

  validates :path,
    length: { within: 1..255 },
    presence: true,
    uniqueness: { case_sensitive: false }

  scope :matching_path_and_descendants, -> (path) do
    wheres = 'LOWER(redirect_routes.path) = LOWER(?) OR LOWER(redirect_routes.path) LIKE LOWER(?)'

    where(wheres, path, "#{sanitize_sql_like(path)}/%")
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :import_export_upload do
    project { create(:project) }
  end
end

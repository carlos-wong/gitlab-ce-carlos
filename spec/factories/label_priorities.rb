# frozen_string_literal: true

FactoryBot.define do
  factory :label_priority do
    project
    label
    sequence(:priority)
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :user_detail do
    user
    job_title { 'VP of Sales' }
  end
end

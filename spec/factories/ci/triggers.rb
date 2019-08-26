# frozen_string_literal: true

FactoryBot.define do
  factory :ci_trigger_without_token, class: Ci::Trigger do
    owner

    factory :ci_trigger do
      sequence(:token) { |n| "token#{n}" }
    end
  end
end

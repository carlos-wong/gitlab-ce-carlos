# frozen_string_literal: true

FactoryBot.define do
  factory :issue do
    title { generate(:title) }
    project
    author { project.creator }
    updated_by { author }

    trait :confidential do
      confidential { true }
    end

    trait :opened do
      state_id { Issue.available_states[:opened] }
    end

    trait :locked do
      discussion_locked { true }
    end

    trait :closed do
      state_id { Issue.available_states[:closed] }
      closed_at { Time.now }
    end

    after(:build) do |issue, evaluator|
      issue.state_id = Issue.available_states[evaluator.state]
    end

    factory :closed_issue, traits: [:closed]
    factory :reopened_issue, traits: [:opened]

    factory :labeled_issue do
      transient do
        labels { [] }
      end

      after(:create) do |issue, evaluator|
        issue.update(labels: evaluator.labels)
      end
    end
  end
end

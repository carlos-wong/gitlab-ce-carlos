# frozen_string_literal: true

FactoryBot.define do
  factory :issue, traits: [:has_internal_id] do
    title { generate(:title) }
    project
    author { project.creator }
    updated_by { author }
    relative_position { RelativePositioning::START_POSITION }
    issue_type { :issue }
    association :work_item_type, :default

    trait :confidential do
      confidential { true }
    end

    trait :with_asc_relative_position do
      sequence(:relative_position) { |n| n * 1000 }
    end

    trait :with_desc_relative_position do
      sequence(:relative_position) { |n| -n * 1000 }
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

    trait :with_alert do
      after(:create) do |issue|
        create(:alert_management_alert, project: issue.project, issue: issue)
      end
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
        issue.update!(labels: evaluator.labels)
      end
    end

    trait :task do
      issue_type { :task }
      association :work_item_type, :default, :task
    end

    factory :incident do
      issue_type { :incident }
      association :work_item_type, :default, :incident

      # An escalation status record is created for all incidents
      # in app code. This is a trait to avoid creating escalation
      # status records in specs which do not need them.
      trait :with_escalation_status do
        after(:create) do |incident|
          create(:incident_management_issuable_escalation_status, issue: incident)
        end
      end
    end
  end
end

FactoryBot.define do
  factory :merge_request do
    title { generate(:title) }
    association :source_project, :repository, factory: :project
    target_project { source_project }
    author { source_project.creator }

    # $ git log --pretty=oneline feature..master
    # 5937ac0a7beb003549fc5fd26fc247adbce4a52e Add submodule from gitlab.com
    # 570e7b2abdd848b95f2f578043fc23bd6f6fd24d Change some files
    # 6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9 More submodules
    # d14d6c0abdd253381df51a723d58691b2ee1ab08 Remove ds_store files
    # c1acaa58bbcbc3eafe538cb8274ba387047b69f8 Ignore DS files
    #
    # See also RepoHelpers.sample_compare
    #
    source_branch "master"
    target_branch "feature"

    merge_status "can_be_merged"

    trait :with_diffs do
    end

    trait :with_image_diffs do
      source_branch "add_images_and_changes"
      target_branch "master"
    end

    trait :without_diffs do
      source_branch "improve/awesome"
      target_branch "master"
    end

    trait :conflict do
      source_branch "feature_conflict"
      target_branch "feature"
    end

    trait :merged do
      state :merged
    end

    trait :merged_target do
      source_branch "merged-target"
      target_branch "improve/awesome"
    end

    trait :closed do
      state :closed
    end

    trait :opened do
      state :opened
    end

    trait :invalid do
      source_branch "feature_one"
      target_branch "feature_two"
    end

    trait :locked do
      state :locked
    end

    trait :simple do
      source_branch "feature"
      target_branch "master"
    end

    trait :rebased do
      source_branch "markdown"
      target_branch "improve/awesome"
    end

    trait :diverged do
      source_branch "feature"
      target_branch "master"
    end

    trait :merge_when_pipeline_succeeds do
      merge_when_pipeline_succeeds true
      merge_user { author }
    end

    trait :remove_source_branch do
      merge_params do
        { 'force_remove_source_branch' => '1' }
      end
    end

    trait :with_test_reports do
      after(:build) do |merge_request|
        merge_request.head_pipeline = build(
          :ci_pipeline,
          :success,
          :with_test_reports,
          project: merge_request.source_project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha)
      end
    end

    trait :with_merge_request_pipeline do
      after(:build) do |merge_request|
        merge_request.merge_request_pipelines << build(:ci_pipeline,
          source: :merge_request_event,
          merge_request: merge_request,
          project: merge_request.source_project)
      end
    end

    trait :deployed_review_app do
      target_branch 'pages-deploy-target'

      transient do
        deployment { create(:deployment, :review_app) }
      end

      after(:build) do |merge_request, evaluator|
        merge_request.source_branch = evaluator.deployment.ref
        merge_request.source_project = evaluator.deployment.project
        merge_request.target_project = evaluator.deployment.project
      end
    end

    after(:build) do |merge_request|
      target_project = merge_request.target_project
      source_project = merge_request.source_project

      # Fake `fetch_ref!` if we don't have repository
      # We have too many existing tests replying on this behaviour
      unless [target_project, source_project].all?(&:repository_exists?)
        allow(merge_request).to receive(:fetch_ref!)
      end
    end

    after(:create) do |merge_request, evaluator|
      merge_request.cache_merge_request_closes_issues!
    end

    factory :merged_merge_request, traits: [:merged]
    factory :closed_merge_request, traits: [:closed]
    factory :reopened_merge_request, traits: [:opened]
    factory :invalid_merge_request, traits: [:invalid]
    factory :merge_request_with_diffs, traits: [:with_diffs]
    factory :merge_request_with_diff_notes do
      after(:create) do |mr|
        create(:diff_note_on_merge_request, noteable: mr, project: mr.source_project)
      end
    end

    factory :labeled_merge_request do
      transient do
        labels []
      end

      after(:create) do |merge_request, evaluator|
        merge_request.update(labels: evaluator.labels)
      end
    end
  end
end

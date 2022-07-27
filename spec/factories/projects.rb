# frozen_string_literal: true

require_relative '../support/helpers/test_env'

FactoryBot.define do
  # Project without repository
  #
  # Project does not have bare repository.
  # Use this factory if you don't need repository in tests
  factory :project, class: 'Project' do
    sequence(:name) { |n| "project#{n}" }
    path { name.downcase.gsub(/\s/, '_') }

    # Behaves differently to nil due to cache_has_external_* methods.
    has_external_issue_tracker { false }
    has_external_wiki { false }

    # Associations
    namespace
    creator { group ? association(:user) : namespace&.owner }

    transient do
      # Nest Project Feature attributes
      wiki_access_level { ProjectFeature::ENABLED }
      builds_access_level { ProjectFeature::ENABLED }
      snippets_access_level { ProjectFeature::ENABLED }
      issues_access_level { ProjectFeature::ENABLED }
      forking_access_level { ProjectFeature::ENABLED }
      merge_requests_access_level { ProjectFeature::ENABLED }
      repository_access_level { ProjectFeature::ENABLED }
      analytics_access_level { ProjectFeature::ENABLED }
      package_registry_access_level { ProjectFeature::ENABLED }
      pages_access_level do
        visibility_level == Gitlab::VisibilityLevel::PUBLIC ? ProjectFeature::ENABLED : ProjectFeature::PRIVATE
      end
      metrics_dashboard_access_level { ProjectFeature::PRIVATE }
      operations_access_level { ProjectFeature::ENABLED }
      container_registry_access_level { ProjectFeature::ENABLED }
      security_and_compliance_access_level { ProjectFeature::PRIVATE }

      # we can't assign the delegated `#ci_cd_settings` attributes directly, as the
      # `#ci_cd_settings` relation needs to be created first
      group_runners_enabled { nil }
      merge_pipelines_enabled { nil }
      merge_trains_enabled { nil }
      keep_latest_artifact { nil }
      import_status { nil }
      import_jid { nil }
      import_correlation_id { nil }
      import_last_error { nil }
      forward_deployment_enabled { nil }
      restrict_user_defined_variables { nil }
      ci_job_token_scope_enabled { nil }
      runner_token_expiration_interval { nil }
      runner_token_expiration_interval_human_readable { nil }
    end

    after(:build) do |project, evaluator|
      # Builds and MRs can't have higher visibility level than repository access level.
      builds_access_level = [evaluator.builds_access_level, evaluator.repository_access_level].min
      merge_requests_access_level = [evaluator.merge_requests_access_level, evaluator.repository_access_level].min

      project_feature_hash = {
        wiki_access_level: evaluator.wiki_access_level,
        builds_access_level: builds_access_level,
        snippets_access_level: evaluator.snippets_access_level,
        issues_access_level: evaluator.issues_access_level,
        forking_access_level: evaluator.forking_access_level,
        merge_requests_access_level: merge_requests_access_level,
        repository_access_level: evaluator.repository_access_level,
        package_registry_access_level: evaluator.package_registry_access_level,
        pages_access_level: evaluator.pages_access_level,
        metrics_dashboard_access_level: evaluator.metrics_dashboard_access_level,
        operations_access_level: evaluator.operations_access_level,
        analytics_access_level: evaluator.analytics_access_level,
        container_registry_access_level: evaluator.container_registry_access_level,
        security_and_compliance_access_level: evaluator.security_and_compliance_access_level
      }

      project_namespace_hash = {
        name: evaluator.name,
        path: evaluator.path,
        parent: evaluator.namespace,
        shared_runners_enabled: evaluator.shared_runners_enabled,
        visibility_level: evaluator.visibility_level
      }

      project.build_project_namespace(project_namespace_hash)
      project.build_project_feature(project_feature_hash)
    end

    after(:create) do |project, evaluator|
      # Normally the class Projects::CreateService is used for creating
      # projects, and this class takes care of making sure the owner and current
      # user have access to the project. Our specs don't use said service class,
      # thus we must manually refresh things here.
      unless project.group || project.pending_delete
        project.add_owner(project.first_owner)
      end

      if project.group
        AuthorizedProjectUpdate::ProjectRecalculateService.new(project).execute
      end

      # assign the delegated `#ci_cd_settings` attributes after create
      project.group_runners_enabled = evaluator.group_runners_enabled unless evaluator.group_runners_enabled.nil?
      project.merge_pipelines_enabled = evaluator.merge_pipelines_enabled unless evaluator.merge_pipelines_enabled.nil?
      project.merge_trains_enabled = evaluator.merge_trains_enabled unless evaluator.merge_trains_enabled.nil?
      project.keep_latest_artifact = evaluator.keep_latest_artifact unless evaluator.keep_latest_artifact.nil?
      project.restrict_user_defined_variables = evaluator.restrict_user_defined_variables unless evaluator.restrict_user_defined_variables.nil?
      project.ci_job_token_scope_enabled = evaluator.ci_job_token_scope_enabled unless evaluator.ci_job_token_scope_enabled.nil?
      project.runner_token_expiration_interval = evaluator.runner_token_expiration_interval unless evaluator.runner_token_expiration_interval.nil?
      project.runner_token_expiration_interval_human_readable = evaluator.runner_token_expiration_interval_human_readable unless evaluator.runner_token_expiration_interval_human_readable.nil?

      if evaluator.import_status
        import_state = project.import_state || project.build_import_state
        import_state.status = evaluator.import_status
        import_state.jid = evaluator.import_jid
        import_state.correlation_id_value = evaluator.import_correlation_id
        import_state.last_error = evaluator.import_last_error
        import_state.save!
      end

      # simulating ::Projects::ProcessSyncEventsWorker because most tests don't run Sidekiq inline
      project.create_ci_project_mirror!(namespace_id: project.namespace_id) unless project.ci_project_mirror
    end

    trait :public do
      visibility_level { Gitlab::VisibilityLevel::PUBLIC }
    end

    trait :internal do
      visibility_level { Gitlab::VisibilityLevel::INTERNAL }
    end

    trait :private do
      visibility_level { Gitlab::VisibilityLevel::PRIVATE }
    end

    trait :import_scheduled do
      import_status { :scheduled }
    end

    trait :import_started do
      import_status { :started }
    end

    trait :import_finished do
      import_status { :finished }
    end

    trait :import_failed do
      import_status { :failed }
    end

    trait :import_canceled do
      import_status { :canceled }
    end

    trait :jira_dvcs_cloud do
      before(:create) do |project|
        create(:project_feature_usage, :dvcs_cloud, project: project)
      end
    end

    trait :jira_dvcs_server do
      before(:create) do |project|
        create(:project_feature_usage, :dvcs_server, project: project)
      end
    end

    trait :archived do
      archived { true }
    end

    trait :hidden do
      hidden { true }
    end

    trait :last_repository_check_failed do
      last_repository_check_failed { true }
    end

    storage_version { Project::LATEST_STORAGE_VERSION }

    trait :legacy_storage do
      storage_version { nil }
    end

    trait :request_access_disabled do
      request_access_enabled { false }
    end

    trait :with_namespace_settings do
      namespace factory: [:namespace, :with_namespace_settings]
    end

    trait :with_avatar do
      avatar { fixture_file_upload('spec/fixtures/dk.png') }
    end

    trait :with_export do
      after(:create) do |project, _evaluator|
        ProjectExportWorker.new.perform(project.creator.id, project.id)
      end
    end

    trait :broken_storage do
      after(:create) do |project|
        project.update_column(:repository_storage, 'broken')
      end
    end

    # Build a custom repository by specifying a hash of `filename => content` in
    # the transient `files` attribute. Each file will be created in its own
    # commit, operating against the master branch. So, the following call:
    #
    #     create(:project, :custom_repo, files: { 'foo/a.txt' => 'foo', 'b.txt' => bar' })
    #
    # will create a repository containing two files, and two commits, in master
    trait :custom_repo do
      transient do
        files { {} }
      end

      after :create do |project, evaluator|
        raise "Failed to create repository!" unless project.repository.exists? || project.create_repository

        evaluator.files.each do |filename, content|
          project.repository.create_file(
            project.creator,
            filename,
            content,
            message: "Automatically created file #{filename}",
            branch_name: project.default_branch || 'master'
          )
        end
      end
    end

    # Test repository - https://gitlab.com/gitlab-org/gitlab-test
    trait :repository do
      test_repo

      transient do
        create_templates { nil }
        create_branch { nil }
      end

      after :create do |project, evaluator|
        if evaluator.create_templates
          templates_path = "#{evaluator.create_templates}_templates"

          project.repository.create_file(
            project.creator,
            ".gitlab/#{templates_path}/bug.md",
            'something valid',
            message: 'test 3',
            branch_name: 'master')
          project.repository.create_file(
            project.creator,
            ".gitlab/#{templates_path}/template_test.md",
            'template_test',
            message: 'test 1',
            branch_name: 'master')
          project.repository.create_file(
            project.creator,
            ".gitlab/#{templates_path}/feature_proposal.md",
            'feature_proposal',
            message: 'test 2',
            branch_name: 'master')
        end

        if evaluator.create_branch
          project.repository.create_file(
            project.creator,
            'README.md',
            "README on branch #{evaluator.create_branch}",
            message: 'Add README.md',
            branch_name: evaluator.create_branch)

        end

        project.track_project_repository
      end
    end

    trait :empty_repo do
      after(:create) do |project|
        raise "Failed to create repository!" unless project.create_repository
      end
    end

    trait :design_repo do
      after(:create) do |project|
        raise 'Failed to create design repository!' unless project.design_repository.create_if_not_exists
      end
    end

    trait :remote_mirror do
      transient do
        url { "http://foo.com" }
        enabled { true }
      end
      after(:create) do |project, evaluator|
        project.remote_mirrors.create!(url: evaluator.url, enabled: evaluator.enabled)
      end
    end

    trait :stubbed_repository do
      after(:build) do |project|
        stub_method(project, :empty_repo?) { false }
        stub_method(project.repository, :empty?) { false }
      end
    end

    trait :wiki_repo do
      after(:create) do |project|
        stub_feature_flags(main_branch_over_master: false)

        raise 'Failed to create wiki repository!' unless project.create_wiki
      end
    end

    trait :read_only do
      repository_read_only { true }
    end

    trait :broken_repo do
      after(:create) do |project|
        TestEnv.rm_storage_dir(project.repository_storage, "#{project.disk_path}.git/refs")
      end
    end

    trait :test_repo do
      after :create do |project|
        # There are various tests that rely on there being no repository cache.
        # Using raw avoids caching.
        repo = Gitlab::GlRepository::PROJECT.repository_for(project).raw
        repo.create_from_bundle(TestEnv.factory_repo_bundle_path)
      end
    end

    trait :with_import_url do
      import_finished

      import_url { generate(:url) }
    end

    trait(:wiki_enabled)            { wiki_access_level { ProjectFeature::ENABLED } }
    trait(:wiki_disabled)           { wiki_access_level { ProjectFeature::DISABLED } }
    trait(:wiki_private)            { wiki_access_level { ProjectFeature::PRIVATE } }
    trait(:builds_enabled)          { builds_access_level { ProjectFeature::ENABLED } }
    trait(:builds_disabled)         { builds_access_level { ProjectFeature::DISABLED } }
    trait(:builds_private)          { builds_access_level { ProjectFeature::PRIVATE } }
    trait(:snippets_enabled)        { snippets_access_level { ProjectFeature::ENABLED } }
    trait(:snippets_disabled)       { snippets_access_level { ProjectFeature::DISABLED } }
    trait(:snippets_private)        { snippets_access_level { ProjectFeature::PRIVATE } }
    trait(:issues_disabled)         { issues_access_level { ProjectFeature::DISABLED } }
    trait(:issues_enabled)          { issues_access_level { ProjectFeature::ENABLED } }
    trait(:issues_private)          { issues_access_level { ProjectFeature::PRIVATE } }
    trait(:forking_disabled)         { forking_access_level { ProjectFeature::DISABLED } }
    trait(:forking_enabled)          { forking_access_level { ProjectFeature::ENABLED } }
    trait(:forking_private)          { forking_access_level { ProjectFeature::PRIVATE } }
    trait(:merge_requests_enabled)  { merge_requests_access_level { ProjectFeature::ENABLED } }
    trait(:merge_requests_disabled) { merge_requests_access_level { ProjectFeature::DISABLED } }
    trait(:merge_requests_private)  { merge_requests_access_level { ProjectFeature::PRIVATE } }
    trait(:merge_requests_public)   { merge_requests_access_level { ProjectFeature::PUBLIC } }
    trait(:repository_enabled)      { repository_access_level { ProjectFeature::ENABLED } }
    trait(:repository_disabled)     { repository_access_level { ProjectFeature::DISABLED } }
    trait(:repository_private)      { repository_access_level { ProjectFeature::PRIVATE } }
    trait(:pages_public)            { pages_access_level { ProjectFeature::PUBLIC } }
    trait(:pages_enabled)           { pages_access_level { ProjectFeature::ENABLED } }
    trait(:pages_disabled)          { pages_access_level { ProjectFeature::DISABLED } }
    trait(:pages_private)           { pages_access_level { ProjectFeature::PRIVATE } }
    trait(:metrics_dashboard_enabled) { metrics_dashboard_access_level { ProjectFeature::ENABLED } }
    trait(:metrics_dashboard_disabled) { metrics_dashboard_access_level { ProjectFeature::DISABLED } }
    trait(:metrics_dashboard_private) { metrics_dashboard_access_level { ProjectFeature::PRIVATE } }
    trait(:operations_enabled)           { operations_access_level { ProjectFeature::ENABLED } }
    trait(:operations_disabled)          { operations_access_level { ProjectFeature::DISABLED } }
    trait(:operations_private)           { operations_access_level { ProjectFeature::PRIVATE } }
    trait(:analytics_enabled)           { analytics_access_level { ProjectFeature::ENABLED } }
    trait(:analytics_disabled)          { analytics_access_level { ProjectFeature::DISABLED } }
    trait(:analytics_private)           { analytics_access_level { ProjectFeature::PRIVATE } }
    trait(:container_registry_enabled)  { container_registry_access_level { ProjectFeature::ENABLED } }
    trait(:container_registry_disabled) { container_registry_access_level { ProjectFeature::DISABLED } }
    trait(:container_registry_private)  { container_registry_access_level { ProjectFeature::PRIVATE } }
    trait(:security_and_compliance_enabled)  { security_and_compliance_access_level { ProjectFeature::ENABLED } }
    trait(:security_and_compliance_disabled) { security_and_compliance_access_level { ProjectFeature::DISABLED } }
    trait(:security_and_compliance_private)  { security_and_compliance_access_level { ProjectFeature::PRIVATE } }

    trait :auto_devops do
      association :auto_devops, factory: :project_auto_devops
    end

    trait :auto_devops_disabled do
      association :auto_devops, factory: [:project_auto_devops, :disabled]
    end

    trait :without_container_expiration_policy do
      after :create do |project|
        project.container_expiration_policy.destroy!
      end
    end
  end

  trait :service_desk_disabled do
    service_desk_enabled { nil }
  end

  trait(:service_desk_enabled) do
    service_desk_enabled { true }
  end

  trait :with_error_tracking_setting do
    error_tracking_setting { association :project_error_tracking_setting }
  end

  # Project with empty repository
  #
  # This is a case when you just created a project
  # but not pushed any code there yet
  factory :project_empty_repo, parent: :project do
    empty_repo
  end

  # Project with broken repository
  #
  # Project with an invalid repository state
  factory :project_broken_repo, parent: :project do
    broken_repo
  end

  factory :forked_project_with_submodules, parent: :project do
    path { 'forked-gitlabhq' }

    after :create do |project|
      # There are various tests that rely on there being no repository cache.
      # Using raw avoids caching.
      repo = Gitlab::GlRepository::PROJECT.repository_for(project).raw
      repo.create_from_bundle(TestEnv.forked_repo_bundle_path)
    end
  end

  factory :redmine_project, parent: :project do
    has_external_issue_tracker { true }

    redmine_integration
  end

  factory :youtrack_project, parent: :project do
    has_external_issue_tracker { true }

    youtrack_integration
  end

  factory :jira_project, parent: :project do
    has_external_issue_tracker { true }

    jira_integration
  end

  factory :prometheus_project, parent: :project do
    after :create do |project|
      project.create_prometheus_integration(
        active: true,
        properties: {
          api_url: 'https://prometheus.example.com/',
          manual_configuration: true
        }
      )
    end
  end

  factory :ewm_project, parent: :project do
    has_external_issue_tracker { true }

    ewm_integration
  end

  factory :project_with_design, parent: :project do
    after(:create) do |project|
      issue = create(:issue, project: project)
      create(:design, project: project, issue: issue)
    end
  end

  trait :in_subgroup do
    namespace factory: [:group, :nested]
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageData, :aggregate_failures do
  include UsageDataHelpers

  before do
    stub_usage_data_connections
    stub_object_store_settings
    clear_memoized_values(described_class::CE_MEMOIZED_VALUES)
    stub_database_flavor_check('Cloud SQL for PostgreSQL')
  end

  describe '.data' do
    subject { described_class.data }

    it 'includes basic top and second level keys' do
      is_expected.to include(:counts)
      is_expected.to include(:counts_monthly)
      is_expected.to include(:counts_weekly)
      is_expected.to include(:license)
      is_expected.to include(:settings)

      # usage_activity_by_stage data
      is_expected.to include(:usage_activity_by_stage)
      is_expected.to include(:usage_activity_by_stage_monthly)
      expect(subject[:usage_activity_by_stage])
        .to include(:configure, :create, :manage, :monitor, :plan, :release, :verify)
      expect(subject[:usage_activity_by_stage_monthly])
        .to include(:configure, :create, :manage, :monitor, :plan, :release, :verify)
      expect(subject[:usage_activity_by_stage][:create])
        .not_to include(:merge_requests_users)
      expect(subject[:usage_activity_by_stage_monthly][:create])
        .to include(:merge_requests_users)
      expect(subject[:counts_weekly]).to include(:aggregated_metrics)
      expect(subject[:counts_monthly]).to include(:aggregated_metrics)
    end

    it 'clears memoized values' do
      allow(described_class).to receive(:clear_memoization)

      subject

      described_class::CE_MEMOIZED_VALUES.each do |key|
        expect(described_class).to have_received(:clear_memoization).with(key)
      end
    end

    it 'ensures recorded_at is set before any other usage data calculation' do
      %i(alt_usage_data redis_usage_data distinct_count count).each do |method|
        expect(described_class).not_to receive(method)
      end
      expect(described_class).to receive(:recorded_at).and_raise(Exception.new('Stopped calculating recorded_at'))

      expect { subject }.to raise_error('Stopped calculating recorded_at')
    end

    context 'when generating usage ping in critical weeks' do
      it 'does not raise error when generated in last week of the year' do
        travel_to(DateTime.parse('2020-12-29')) do
          expect { subject }.not_to raise_error
        end
      end

      it 'does not raise error when generated in first week of the year' do
        travel_to(DateTime.parse('2021-01-01')) do
          expect { subject }.not_to raise_error
        end
      end

      it 'does not raise error when generated in second week of the year' do
        travel_to(DateTime.parse('2021-01-07')) do
          expect { subject }.not_to raise_error
        end
      end

      it 'does not raise error when generated in 3rd week of the year' do
        travel_to(DateTime.parse('2021-01-14')) do
          expect { subject }.not_to raise_error
        end
      end
    end
  end

  describe 'usage_activity_by_stage_package' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        create(:project, packages: [create(:package)] )
      end

      expect(described_class.usage_activity_by_stage_package({})).to eq(
        projects_with_packages: 2
      )
      expect(described_class.usage_activity_by_stage_package(described_class.monthly_time_range_db_params)).to eq(
        projects_with_packages: 1
      )
    end
  end

  describe '.usage_activity_by_stage_configure' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        create(:cluster, user: user)
        create(:cluster, :disabled, user: user)
        create(:cluster_provider_gcp, :created)
        create(:cluster_provider_aws, :created)
        create(:cluster_platform_kubernetes)
        create(:cluster, :group, :disabled, user: user)
        create(:cluster, :group, user: user)
        create(:cluster, :instance, :disabled, :production_environment)
        create(:cluster, :instance, :production_environment)
        create(:cluster, :management_project)
      end

      expect(described_class.usage_activity_by_stage_configure({})).to include(
        clusters_management_project: 2,
        clusters_disabled: 4,
        clusters_enabled: 12,
        clusters_platforms_gke: 2,
        clusters_platforms_eks: 2,
        clusters_platforms_user: 2,
        instance_clusters_disabled: 2,
        instance_clusters_enabled: 2,
        group_clusters_disabled: 2,
        group_clusters_enabled: 2,
        project_clusters_disabled: 2,
        project_clusters_enabled: 10
      )
      expect(described_class.usage_activity_by_stage_configure(described_class.monthly_time_range_db_params)).to include(
        clusters_management_project: 1,
        clusters_disabled: 2,
        clusters_enabled: 6,
        clusters_platforms_gke: 1,
        clusters_platforms_eks: 1,
        clusters_platforms_user: 1,
        instance_clusters_disabled: 1,
        instance_clusters_enabled: 1,
        group_clusters_disabled: 1,
        group_clusters_enabled: 1,
        project_clusters_disabled: 1,
        project_clusters_enabled: 5
      )
    end
  end

  describe 'usage_activity_by_stage_create' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        project = create(:project, :repository_private,
                         :test_repo, :remote_mirror, creator: user)
        create(:merge_request, source_project: project)
        create(:deploy_key, user: user)
        create(:key, user: user)
        create(:project, creator: user, disable_overriding_approvers_per_merge_request: true)
        create(:project, creator: user, disable_overriding_approvers_per_merge_request: false)
        create(:remote_mirror, project: project, enabled: true)
        another_user = create(:user)
        another_project = create(:project, :repository, creator: another_user)
        create(:remote_mirror, project: another_project, enabled: false)
        create(:snippet, author: user)
      end

      expect(described_class.usage_activity_by_stage_create({})).to include(
        deploy_keys: 2,
        keys: 2,
        projects_with_disable_overriding_approvers_per_merge_request: 2,
        projects_without_disable_overriding_approvers_per_merge_request: 6,
        remote_mirrors: 2,
        snippets: 2
      )
      expect(described_class.usage_activity_by_stage_create(described_class.monthly_time_range_db_params)).to include(
        deploy_keys: 1,
        keys: 1,
        projects_with_disable_overriding_approvers_per_merge_request: 1,
        projects_without_disable_overriding_approvers_per_merge_request: 3,
        remote_mirrors: 1,
        snippets: 1
      )
    end
  end

  describe 'usage_activity_by_stage_manage' do
    let_it_be(:error_rate) { Gitlab::Database::PostgresHll::BatchDistinctCounter::ERROR_RATE }

    it 'includes accurate usage_activity_by_stage data' do
      stub_config(
        omniauth:
          { providers: omniauth_providers }
      )
      allow(Devise).to receive(:omniauth_providers).and_return(%w(ldapmain ldapsecondary group_saml))

      for_defined_days_back do
        user = create(:user)
        user2 = create(:user)
        create(:group_member, user: user)
        create(:authentication_event, user: user, provider: :ldapmain, result: :success)
        create(:authentication_event, user: user2, provider: :ldapsecondary, result: :success)
        create(:authentication_event, user: user2, provider: :group_saml, result: :success)
        create(:authentication_event, user: user2, provider: :group_saml, result: :success)
        create(:authentication_event, user: user, provider: :group_saml, result: :failed)
      end

      for_defined_days_back(days: [31, 29, 3]) do
        create(:event)
      end

      stub_const('Gitlab::Database::PostgresHll::BatchDistinctCounter::DEFAULT_BATCH_SIZE', 1)
      stub_const('Gitlab::Database::PostgresHll::BatchDistinctCounter::MIN_REQUIRED_BATCH_SIZE', 0)

      expect(described_class.usage_activity_by_stage_manage({})).to include(
        events: -1,
        groups: 2,
        users_created: 10,
        omniauth_providers: ['google_oauth2'],
        user_auth_by_provider: { 'group_saml' => 2, 'ldap' => 4, 'standard' => 0, 'two-factor' => 0, 'two-factor-via-u2f-device' => 0, "two-factor-via-webauthn-device" => 0 }
      )
      expect(described_class.usage_activity_by_stage_manage(described_class.monthly_time_range_db_params)).to include(
        events: be_within(error_rate).percent_of(2),
        groups: 1,
        users_created: 6,
        omniauth_providers: ['google_oauth2'],
        user_auth_by_provider: { 'group_saml' => 1, 'ldap' => 2, 'standard' => 0, 'two-factor' => 0, 'two-factor-via-u2f-device' => 0, "two-factor-via-webauthn-device" => 0 }
      )
    end

    it 'includes import gmau usage data' do
      for_defined_days_back do
        user = create(:user)
        group = create(:group)

        group.add_owner(user)

        create(:project, import_type: :github, creator_id: user.id)
        create(:jira_import_state, :finished, project: create(:project, creator_id: user.id))
        create(:issue_csv_import, user: user)
        create(:group_import_state, group: group, user: user)
        create(:bulk_import, user: user)
      end

      expect(described_class.usage_activity_by_stage_manage({})).to include(
        unique_users_all_imports: 10
      )

      expect(described_class.usage_activity_by_stage_manage(described_class.monthly_time_range_db_params)).to include(
        unique_users_all_imports: 5
      )
    end

    it 'includes imports usage data', :clean_gitlab_redis_cache do
      for_defined_days_back do
        user = create(:user)

        %w(gitlab_project gitlab github bitbucket bitbucket_server gitea git manifest fogbugz phabricator).each do |type|
          create(:project, import_type: type, creator_id: user.id)
        end

        jira_project = create(:project, creator_id: user.id)
        create(:jira_import_state, :finished, project: jira_project)

        create(:issue_csv_import, user: user)

        group = create(:group)
        group.add_owner(user)
        create(:group_import_state, group: group, user: user)

        bulk_import = create(:bulk_import, user: user)
        create(:bulk_import_entity, :group_entity, bulk_import: bulk_import)
        create(:bulk_import_entity, :project_entity, bulk_import: bulk_import)
      end

      expect(described_class.usage_activity_by_stage_manage({})).to include(
        {
          bulk_imports: {
            gitlab_v1: 2
          },
          project_imports: {
            bitbucket: 2,
            bitbucket_server: 2,
            git: 2,
            gitea: 2,
            github: 2,
            gitlab: 2,
            gitlab_migration: 2,
            gitlab_project: 2,
            manifest: 2,
            total: 18
          },
          issue_imports: {
            jira: 2,
            fogbugz: 2,
            phabricator: 2,
            csv: 2
          },
          group_imports: {
            group_import: 2,
            gitlab_migration: 2
          }
        }
      )
      expect(described_class.usage_activity_by_stage_manage(described_class.monthly_time_range_db_params)).to include(
        {
          bulk_imports: {
            gitlab_v1: 1
          },
          project_imports: {
            bitbucket: 1,
            bitbucket_server: 1,
            git: 1,
            gitea: 1,
            github: 1,
            gitlab: 1,
            gitlab_migration: 1,
            gitlab_project: 1,
            manifest: 1,
            total: 9
          },
          issue_imports: {
            jira: 1,
            fogbugz: 1,
            phabricator: 1,
            csv: 1
          },
          group_imports: {
            group_import: 1,
            gitlab_migration: 1
          }
        }
      )
    end

    def omniauth_providers
      [
        double('provider', name: 'google_oauth2'),
        double('provider', name: 'ldapmain'),
        double('provider', name: 'group_saml')
      ]
    end
  end

  describe 'usage_activity_by_stage_monitor' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user, dashboard: 'operations')
        cluster = create(:cluster, user: user)
        project = create(:project, creator: user)
        create(:clusters_integrations_prometheus, cluster: cluster)
        create(:project_error_tracking_setting)
        create(:incident)
        create(:incident, alert_management_alert: create(:alert_management_alert))
        create(:alert_management_http_integration, :active, project: project)
      end

      expect(described_class.usage_activity_by_stage_monitor({})).to include(
        clusters: 2,
        clusters_integrations_prometheus: 2,
        operations_dashboard_default_dashboard: 2,
        projects_with_error_tracking_enabled: 2,
        projects_with_incidents: 4,
        projects_with_alert_incidents: 2,
        projects_with_enabled_alert_integrations_histogram: { '1' => 2 }
      )

      data_28_days = described_class.usage_activity_by_stage_monitor(described_class.monthly_time_range_db_params)
      expect(data_28_days).to include(
        clusters: 1,
        clusters_integrations_prometheus: 1,
        operations_dashboard_default_dashboard: 1,
        projects_with_error_tracking_enabled: 1,
        projects_with_incidents: 2,
        projects_with_alert_incidents: 1
      )

      expect(data_28_days).not_to include(:projects_with_enabled_alert_integrations_histogram)
    end
  end

  describe 'usage_activity_by_stage_plan' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        project = create(:project, creator: user)
        issue = create(:issue, project: project, author: user)
        create(:issue, project: project, author: User.support_bot)
        create(:note, project: project, noteable: issue, author: user)
        create(:todo, project: project, target: issue, author: user)
        create(:jira_integration, :jira_cloud_service, active: true, project: create(:project, :jira_dvcs_cloud, creator: user))
        create(:jira_integration, active: true, project: create(:project, :jira_dvcs_server, creator: user))
      end

      expect(described_class.usage_activity_by_stage_plan({})).to include(
        notes: 2,
        projects: 2,
        todos: 2,
        service_desk_enabled_projects: 2,
        service_desk_issues: 2,
        projects_jira_active: 2,
        projects_jira_dvcs_cloud_active: 2,
        projects_jira_dvcs_server_active: 2
      )
      expect(described_class.usage_activity_by_stage_plan(described_class.monthly_time_range_db_params)).to include(
        notes: 1,
        projects: 1,
        todos: 1,
        service_desk_enabled_projects: 1,
        service_desk_issues: 1,
        projects_jira_active: 1,
        projects_jira_dvcs_cloud_active: 1,
        projects_jira_dvcs_server_active: 1
      )
    end

    it 'does not merge the data from instrumentation classes' do
      for_defined_days_back do
        user = create(:user)
        project = create(:project, creator: user)
        create(:issue, project: project, author: user)
        create(:issue, project: project, author: User.support_bot)
      end

      expect(described_class.usage_activity_by_stage_plan({})).to include(issues: 3)
      expect(described_class.usage_activity_by_stage_plan(described_class.monthly_time_range_db_params)).to include(issues: 2)
    end
  end

  describe 'usage_activity_by_stage_release' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        create(:deployment, :failed, user: user)
        release = create(:release, author: user)
        create(:milestone, project: release.project, releases: [release])
        create(:deployment, :success, user: user)
      end

      expect(described_class.usage_activity_by_stage_release({})).to include(
        deployments: 2,
        failed_deployments: 2,
        releases: 2,
        successful_deployments: 2,
        releases_with_milestones: 2
      )
      expect(described_class.usage_activity_by_stage_release(described_class.monthly_time_range_db_params)).to include(
        deployments: 1,
        failed_deployments: 1,
        releases: 1,
        successful_deployments: 1,
        releases_with_milestones: 1
      )
    end
  end

  describe 'usage_activity_by_stage_verify' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        create(:ci_build, user: user)
        create(:ci_empty_pipeline, source: :external, user: user)
        create(:ci_empty_pipeline, user: user)
        create(:ci_pipeline, :auto_devops_source, user: user)
        create(:ci_pipeline, :repository_source, user: user)
        create(:ci_pipeline_schedule, owner: user)
        create(:ci_trigger, owner: user)
      end

      expect(described_class.usage_activity_by_stage_verify({})).to include(
        ci_builds: 2,
        ci_external_pipelines: 2,
        ci_internal_pipelines: 2,
        ci_pipeline_config_auto_devops: 2,
        ci_pipeline_config_repository: 2,
        ci_pipeline_schedules: 2,
        ci_pipelines: 2,
        ci_triggers: 2
      )
      expect(described_class.usage_activity_by_stage_verify(described_class.monthly_time_range_db_params)).to include(
        ci_builds: 1,
        ci_external_pipelines: 1,
        ci_internal_pipelines: 1,
        ci_pipeline_config_auto_devops: 1,
        ci_pipeline_config_repository: 1,
        ci_pipeline_schedules: 1,
        ci_pipelines: 1,
        ci_triggers: 1
      )
    end
  end

  describe '.data' do
    let!(:ud) { build(:usage_data) }

    before do
      allow(described_class).to receive(:grafana_embed_usage_data).and_return(2)
    end

    subject { described_class.data }

    it 'gathers usage data' do
      expect(subject.keys).to include(*UsageDataHelpers::USAGE_DATA_KEYS)
    end

    it 'gathers usage counts', :aggregate_failures do
      count_data = subject[:counts]
      expect(count_data[:projects]).to eq(4)
      expect(count_data.keys).to include(*UsageDataHelpers::COUNTS_KEYS)
      expect(UsageDataHelpers::COUNTS_KEYS - count_data.keys).to be_empty
      expect(count_data.values).to all(be_a_kind_of(Integer))
    end

    it 'gathers usage counts correctly' do
      count_data = subject[:counts]

      expect(count_data[:projects]).to eq(4)
      expect(count_data[:projects_asana_active]).to eq(0)
      expect(count_data[:projects_prometheus_active]).to eq(1)
      expect(count_data[:projects_jenkins_active]).to eq(1)
      expect(count_data[:projects_jira_active]).to eq(4)
      expect(count_data[:projects_jira_server_active]).to eq(2)
      expect(count_data[:projects_jira_cloud_active]).to eq(2)
      expect(count_data[:jira_imports_projects_count]).to eq(2)
      expect(count_data[:jira_imports_total_imported_count]).to eq(3)
      expect(count_data[:jira_imports_total_imported_issues_count]).to eq(13)
      expect(count_data[:projects_slack_active]).to eq(2)
      expect(count_data[:projects_slack_slash_commands_active]).to eq(1)
      expect(count_data[:projects_custom_issue_tracker_active]).to eq(1)
      expect(count_data[:projects_mattermost_active]).to eq(1)
      expect(count_data[:groups_mattermost_active]).to eq(1)
      expect(count_data[:instances_mattermost_active]).to eq(1)
      expect(count_data[:projects_inheriting_mattermost_active]).to eq(1)
      expect(count_data[:groups_inheriting_slack_active]).to eq(1)
      expect(count_data[:projects_with_repositories_enabled]).to eq(3)
      expect(count_data[:projects_with_error_tracking_enabled]).to eq(1)
      expect(count_data[:projects_with_enabled_alert_integrations]).to eq(1)
      expect(count_data[:projects_with_terraform_reports]).to eq(2)
      expect(count_data[:projects_with_terraform_states]).to eq(2)
      expect(count_data[:projects_with_alerts_created]).to eq(1)
      expect(count_data[:protected_branches]).to eq(2)
      expect(count_data[:protected_branches_except_default]).to eq(1)
      expect(count_data[:terraform_reports]).to eq(6)
      expect(count_data[:terraform_states]).to eq(3)
      expect(count_data[:issues_created_from_gitlab_error_tracking_ui]).to eq(1)
      expect(count_data[:issues_with_associated_zoom_link]).to eq(2)
      expect(count_data[:issues_using_zoom_quick_actions]).to eq(3)
      expect(count_data[:issues_with_embedded_grafana_charts_approx]).to eq(2)
      expect(count_data[:incident_issues]).to eq(4)
      expect(count_data[:issues_created_gitlab_alerts]).to eq(1)
      expect(count_data[:issues_created_from_alerts]).to eq(3)
      expect(count_data[:issues_created_manually_from_alerts]).to eq(1)
      expect(count_data[:alert_bot_incident_issues]).to eq(4)
      expect(count_data[:clusters_enabled]).to eq(6)
      expect(count_data[:project_clusters_enabled]).to eq(4)
      expect(count_data[:group_clusters_enabled]).to eq(1)
      expect(count_data[:instance_clusters_enabled]).to eq(1)
      expect(count_data[:clusters_disabled]).to eq(3)
      expect(count_data[:project_clusters_disabled]).to eq(1)
      expect(count_data[:group_clusters_disabled]).to eq(1)
      expect(count_data[:instance_clusters_disabled]).to eq(1)
      expect(count_data[:clusters_platforms_eks]).to eq(1)
      expect(count_data[:clusters_platforms_gke]).to eq(1)
      expect(count_data[:clusters_platforms_user]).to eq(1)
      expect(count_data[:clusters_integrations_prometheus]).to eq(1)
      expect(count_data[:grafana_integrated_projects]).to eq(2)
      expect(count_data[:clusters_management_project]).to eq(1)
      expect(count_data[:kubernetes_agents]).to eq(2)
      expect(count_data[:kubernetes_agents_with_token]).to eq(1)

      expect(count_data[:deployments]).to eq(4)
      expect(count_data[:successful_deployments]).to eq(2)
      expect(count_data[:failed_deployments]).to eq(2)
      expect(count_data[:feature_flags]).to eq(1)
      expect(count_data[:snippets]).to eq(6)
      expect(count_data[:personal_snippets]).to eq(2)
      expect(count_data[:project_snippets]).to eq(4)

      expect(count_data[:projects_creating_incidents]).to eq(2)
      expect(count_data[:projects_with_packages]).to eq(2)
      expect(count_data[:packages]).to eq(4)
      expect(count_data[:user_preferences_user_gitpod_enabled]).to eq(1)
    end

    it 'gathers object store usage correctly' do
      expect(subject[:object_store]).to eq(
        { artifacts: { enabled: true, object_store: { enabled: true, direct_upload: true, background_upload: false, provider: "AWS" } },
         external_diffs: { enabled: false },
         lfs: { enabled: true, object_store: { enabled: false, direct_upload: true, background_upload: false, provider: "AWS" } },
         uploads: { enabled: nil, object_store: { enabled: false, direct_upload: true, background_upload: false, provider: "AWS" } },
         packages: { enabled: true, object_store: { enabled: false, direct_upload: false, background_upload: true, provider: "AWS" } } }
      )
    end

    context 'with existing container expiration policies' do
      let_it_be(:disabled) { create(:container_expiration_policy, enabled: false) }
      let_it_be(:enabled) { create(:container_expiration_policy, enabled: true) }

      %i[keep_n cadence older_than].each do |attribute|
        ContainerExpirationPolicy.send("#{attribute}_options").keys.each do |value|
          let_it_be("container_expiration_policy_with_#{attribute}_set_to_#{value}") { create(:container_expiration_policy, attribute => value) }
        end
      end

      let_it_be('container_expiration_policy_with_keep_n_set_to_null') { create(:container_expiration_policy, keep_n: nil) }
      let_it_be('container_expiration_policy_with_older_than_set_to_null') { create(:container_expiration_policy, older_than: nil) }

      let(:inactive_policies) { ::ContainerExpirationPolicy.where(enabled: false) }
      let(:active_policies) { ::ContainerExpirationPolicy.active }

      subject { described_class.data[:counts] }

      it 'gathers usage data' do
        expect(subject[:projects_with_expiration_policy_enabled]).to eq 19
        expect(subject[:projects_with_expiration_policy_disabled]).to eq 5

        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_unset]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_1]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_5]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_10]).to eq 13
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_25]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_50]).to eq 1

        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_unset]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_7d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_14d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_30d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_60d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_90d]).to eq 14

        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_1d]).to eq 15
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_7d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_14d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_1month]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_3month]).to eq 1
      end
    end

    context 'when queries time out' do
      let(:metric_method) { :count }

      before do
        allow_any_instance_of(ActiveRecord::Relation).to receive(metric_method).and_raise(ActiveRecord::StatementInvalid)
        allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(should_raise_for_dev)
      end

      context 'with should_raise_for_dev? true' do
        let(:should_raise_for_dev) { true }

        it 'raises an error' do
          expect { subject }.to raise_error(ActiveRecord::StatementInvalid)
        end

        context 'when metric calls find_in_batches' do
          let(:metric_method) { :find_in_batches }

          it 'raises an error for jira_usage' do
            expect { described_class.jira_usage }.to raise_error(ActiveRecord::StatementInvalid)
          end
        end
      end

      context 'with should_raise_for_dev? false' do
        let(:should_raise_for_dev) { false }

        it 'does not raise an error' do
          expect { subject }.not_to raise_error
        end

        context 'when metric calls find_in_batches' do
          let(:metric_method) { :find_in_batches }

          it 'does not raise an error for jira_usage' do
            expect { described_class.jira_usage }.not_to raise_error
          end
        end
      end
    end

    it 'includes a recording_ce_finished_at timestamp' do
      expect(subject[:recording_ce_finished_at]).to be_a(Time)
    end
  end

  describe '.system_usage_data_monthly' do
    let_it_be(:project) { create(:project, created_at: 3.days.ago) }

    before do
      env = create(:environment)
      create(:package, project: project, created_at: 3.days.ago)
      create(:package, created_at: 2.months.ago, project: project)

      [3, 31].each do |n|
        deployment_options = { created_at: n.days.ago, project: env.project, environment: env }
        create(:deployment, :failed, deployment_options)
        create(:deployment, :success, deployment_options)
        create(:project_snippet, project: project, created_at: n.days.ago)
        create(:personal_snippet, created_at: n.days.ago)
        create(:alert_management_alert, project: project, created_at: n.days.ago)
      end

      stub_application_setting(self_monitoring_project: project)

      for_defined_days_back do
        create(:product_analytics_event, project: project, se_category: 'epics', se_action: 'promote')
      end
    end

    subject { described_class.system_usage_data_monthly }

    it 'gathers monthly usage counts correctly' do
      counts_monthly = subject[:counts_monthly]

      expect(counts_monthly[:deployments]).to eq(2)
      expect(counts_monthly[:successful_deployments]).to eq(1)
      expect(counts_monthly[:failed_deployments]).to eq(1)
      expect(counts_monthly[:snippets]).to eq(2)
      expect(counts_monthly[:personal_snippets]).to eq(1)
      expect(counts_monthly[:project_snippets]).to eq(1)
      expect(counts_monthly[:projects_with_alerts_created]).to eq(1)
      expect(counts_monthly[:projects]).to eq(1)
      expect(counts_monthly[:packages]).to eq(1)
    end
  end

  describe '.runners_usage' do
    before do
      project = build(:project)
      create_list(:ci_runner, 2, :instance_type, :online)
      create(:ci_runner, :group, :online)
      create(:ci_runner, :group, :inactive)
      create_list(:ci_runner, 3, :project_type, :online, projects: [project])
    end

    subject { described_class.runners_usage }

    it 'gathers runner usage counts correctly' do
      expect(subject[:ci_runners]).to eq(7)
      expect(subject[:ci_runners_instance_type_active]).to eq(2)
      expect(subject[:ci_runners_group_type_active]).to eq(1)
      expect(subject[:ci_runners_project_type_active]).to eq(3)

      expect(subject[:ci_runners_instance_type_active_online]).to eq(2)
      expect(subject[:ci_runners_group_type_active_online]).to eq(1)
      expect(subject[:ci_runners_project_type_active_online]).to eq(3)
    end
  end

  describe '.usage_counters' do
    subject { described_class.usage_counters }

    it { is_expected.to include(:kubernetes_agent_gitops_sync) }
    it { is_expected.to include(:kubernetes_agent_k8s_api_proxy_request) }
    it { is_expected.to include(:package_events_i_package_pull_package) }
    it { is_expected.to include(:package_events_i_package_delete_package_by_user) }
    it { is_expected.to include(:package_events_i_package_conan_push_package) }
  end

  describe '.usage_data_counters' do
    subject { described_class.usage_data_counters }

    it { is_expected.to all(respond_to :totals) }
    it { is_expected.to all(respond_to :fallback_totals) }

    describe 'the results of calling #totals on all objects in the array' do
      subject { described_class.usage_data_counters.map(&:totals) }

      it { is_expected.to all(be_a Hash) }
      it { is_expected.to all(have_attributes(keys: all(be_a Symbol), values: all(be_a Integer))) }
    end

    describe 'the results of calling #fallback_totals on all objects in the array' do
      subject { described_class.usage_data_counters.map(&:fallback_totals) }

      it { is_expected.to all(be_a Hash) }
      it { is_expected.to all(have_attributes(keys: all(be_a Symbol), values: all(eq(-1)))) }
    end

    it 'does not have any conflicts' do
      all_keys = subject.flat_map { |counter| counter.totals.keys }

      expect(all_keys.size).to eq all_keys.to_set.size
    end
  end

  describe '.license_usage_data' do
    subject { described_class.license_usage_data }

    it 'gathers license data' do
      expect(subject[:uuid]).to eq(Gitlab::CurrentSettings.uuid)
      expect(subject[:version]).to eq(Gitlab::VERSION)
      expect(subject[:installation_type]).to eq('gitlab-development-kit')
      expect(subject[:active_user_count]).to eq(User.active.size)
      expect(subject[:recorded_at]).to be_a(Time)
    end
  end

  context 'when not relying on database records' do
    describe '.features_usage_data_ce' do
      subject { described_class.features_usage_data_ce }

      it 'gathers feature usage data', :aggregate_failures do
        expect(subject[:instance_auto_devops_enabled]).to eq(Gitlab::CurrentSettings.auto_devops_enabled?)
        expect(subject[:mattermost_enabled]).to eq(Gitlab.config.mattermost.enabled)
        expect(subject[:signup_enabled]).to eq(Gitlab::CurrentSettings.allow_signup?)
        expect(subject[:ldap_enabled]).to eq(Gitlab.config.ldap.enabled)
        expect(subject[:gravatar_enabled]).to eq(Gitlab::CurrentSettings.gravatar_enabled?)
        expect(subject[:omniauth_enabled]).to eq(Gitlab::Auth.omniauth_enabled?)
        expect(subject[:reply_by_email_enabled]).to eq(Gitlab::IncomingEmail.enabled?)
        expect(subject[:container_registry_enabled]).to eq(Gitlab.config.registry.enabled)
        expect(subject[:dependency_proxy_enabled]).to eq(Gitlab.config.dependency_proxy.enabled)
        expect(subject[:gitlab_shared_runners_enabled]).to eq(Gitlab.config.gitlab_ci.shared_runners_enabled)
        expect(subject[:web_ide_clientside_preview_enabled]).to eq(Gitlab::CurrentSettings.web_ide_clientside_preview_enabled?)
        expect(subject[:grafana_link_enabled]).to eq(Gitlab::CurrentSettings.grafana_enabled?)
        expect(subject[:gitpod_enabled]).to eq(Gitlab::CurrentSettings.gitpod_enabled?)
      end

      context 'with embedded Prometheus' do
        it 'returns true when embedded Prometheus is enabled' do
          allow(Gitlab::Prometheus::Internal).to receive(:prometheus_enabled?).and_return(true)

          expect(subject[:prometheus_enabled]).to eq(true)
        end

        it 'returns false when embedded Prometheus is disabled' do
          allow(Gitlab::Prometheus::Internal).to receive(:prometheus_enabled?).and_return(false)

          expect(subject[:prometheus_enabled]).to eq(false)
        end
      end

      context 'with embedded grafana' do
        it 'returns true when embedded grafana is enabled' do
          stub_application_setting(grafana_enabled: true)

          expect(subject[:grafana_link_enabled]).to eq(true)
        end

        it 'returns false when embedded grafana is disabled' do
          stub_application_setting(grafana_enabled: false)

          expect(subject[:grafana_link_enabled]).to eq(false)
        end
      end

      context 'with Gitpod' do
        it 'returns true when is enabled' do
          stub_application_setting(gitpod_enabled: true)

          expect(subject[:gitpod_enabled]).to eq(true)
        end

        it 'returns false when is disabled' do
          stub_application_setting(gitpod_enabled: false)

          expect(subject[:gitpod_enabled]).to eq(false)
        end
      end
    end

    describe '.components_usage_data' do
      subject { described_class.components_usage_data }

      it 'gathers basic components usage data' do
        stub_application_setting(container_registry_vendor: 'gitlab', container_registry_version: 'x.y.z')

        expect(subject[:gitlab_pages][:enabled]).to eq(Gitlab.config.pages.enabled)
        expect(subject[:gitlab_pages][:version]).to eq(Gitlab::Pages::VERSION)
        expect(subject[:git][:version]).to eq(Gitlab::Git.version)
        expect(subject[:database][:adapter]).to eq(ApplicationRecord.database.adapter_name)
        expect(subject[:database][:version]).to eq(ApplicationRecord.database.version)
        expect(subject[:database][:pg_system_id]).to eq(ApplicationRecord.database.system_id)
        expect(subject[:database][:flavor]).to eq('Cloud SQL for PostgreSQL')
        expect(subject[:mail][:smtp_server]).to eq(ActionMailer::Base.smtp_settings[:address])
        expect(subject[:gitaly][:version]).to be_present
        expect(subject[:gitaly][:servers]).to be >= 1
        expect(subject[:gitaly][:clusters]).to be >= 0
        expect(subject[:gitaly][:filesystems]).to be_an(Array)
        expect(subject[:gitaly][:filesystems].first).to be_a(String)
        expect(subject[:container_registry_server][:vendor]).to eq('gitlab')
        expect(subject[:container_registry_server][:version]).to eq('x.y.z')
      end
    end

    describe '.object_store_config' do
      let(:component) { 'lfs' }

      subject { described_class.object_store_config(component) }

      context 'when object_store is not configured' do
        it 'returns component enable status only' do
          allow(Settings).to receive(:[]).with(component).and_return({ 'enabled' => false })

          expect(subject).to eq({ enabled: false })
        end
      end

      context 'when object_store is configured' do
        it 'returns filtered object store config' do
          allow(Settings).to receive(:[]).with(component)
            .and_return(
              { 'enabled' => true,
                'object_store' =>
                { 'enabled' => true,
                  'remote_directory' => component,
                  'direct_upload' => true,
                  'connection' =>
                { 'provider' => 'AWS', 'aws_access_key_id' => 'minio', 'aws_secret_access_key' => 'gdk-minio', 'region' => 'gdk', 'endpoint' => 'http://127.0.0.1:9000', 'path_style' => true },
                  'background_upload' => false,
                  'proxy_download' => false } })

          expect(subject).to eq(
            { enabled: true, object_store: { enabled: true, direct_upload: true, background_upload: false, provider: "AWS" } })
        end
      end

      context 'when retrieve component setting meets exception' do
        before do
          allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(should_raise_for_dev)
          allow(Settings).to receive(:[]).with(component).and_raise(StandardError)
        end

        context 'with should_raise_for_dev? false' do
          let(:should_raise_for_dev) { false }

          it 'returns -1 for component enable status' do
            expect(subject).to eq({ enabled: -1 })
          end
        end

        context 'with should_raise_for_dev? true' do
          let(:should_raise_for_dev) { true }

          it 'raises an error' do
            expect { subject.value }.to raise_error(StandardError)
          end
        end
      end
    end

    describe '.object_store_usage_data' do
      subject { described_class.object_store_usage_data }

      it 'fetches object store config of five components' do
        %w(artifacts external_diffs lfs uploads packages).each do |component|
          expect(described_class).to receive(:object_store_config).with(component).and_return("#{component}_object_store_config")
        end

        expect(subject).to eq(
          object_store: {
            artifacts: 'artifacts_object_store_config',
            external_diffs: 'external_diffs_object_store_config',
            lfs: 'lfs_object_store_config',
            uploads: 'uploads_object_store_config',
            packages: 'packages_object_store_config'
          })
      end
    end

    describe '.grafana_embed_usage_data' do
      subject { described_class.grafana_embed_usage_data }

      let(:project) { create(:project) }
      let(:description_with_embed) { "Some comment\n\nhttps://grafana.example.com/d/xvAk4q0Wk/go-processes?orgId=1&from=1573238522762&to=1573240322762&var-job=prometheus&var-interval=10m&panelId=1&fullscreen" }
      let(:description_with_unintegrated_embed) { "Some comment\n\nhttps://grafana.exp.com/d/xvAk4q0Wk/go-processes?orgId=1&from=1573238522762&to=1573240322762&var-job=prometheus&var-interval=10m&panelId=1&fullscreen" }
      let(:description_with_non_grafana_inline_metric) { "Some comment\n\n#{Gitlab::Routing.url_helpers.metrics_namespace_project_environment_url(*['foo', 'bar', 12])}" }

      shared_examples "zero count" do
        it "does not count the issue" do
          expect(subject).to eq(0)
        end
      end

      context 'with project grafana integration enabled' do
        before do
          create(:grafana_integration, project: project, enabled: true)
        end

        context 'with valid and invalid embeds' do
          before do
            # Valid
            create(:issue, project: project, description: description_with_embed)
            create(:issue, project: project, description: description_with_embed)
            # In-Valid
            create(:issue, project: project, description: description_with_unintegrated_embed)
            create(:issue, project: project, description: description_with_non_grafana_inline_metric)
            create(:issue, project: project, description: nil)
            create(:issue, project: project, description: '')
            create(:issue, project: project)
          end

          it 'counts only the issues with embeds' do
            expect(subject).to eq(2)
          end
        end
      end

      context 'with project grafana integration disabled' do
        before do
          create(:grafana_integration, project: project, enabled: false)
        end

        context 'with one issue having a grafana link in the description and one without' do
          before do
            create(:issue, project: project, description: description_with_embed)
            create(:issue, project: project)
          end

          it_behaves_like('zero count')
        end
      end

      context 'with an un-integrated project' do
        context 'with one issue having a grafana link in the description and one without' do
          before do
            create(:issue, project: project, description: description_with_embed)
            create(:issue, project: project)
          end

          it_behaves_like('zero count')
        end
      end
    end

    describe ".operating_system" do
      let(:ohai_data) { { "platform" => "ubuntu", "platform_version" => "20.04" } }

      before do
        allow_next_instance_of(Ohai::System) do |ohai|
          allow(ohai).to receive(:data).and_return(ohai_data)
        end
      end

      subject { described_class.operating_system }

      it { is_expected.to eq("ubuntu-20.04") }

      context 'when on Debian with armv architecture' do
        let(:ohai_data) { { "platform" => "debian", "platform_version" => "10", 'kernel' => { 'machine' => 'armv' } } }

        it { is_expected.to eq("raspbian-10") }
      end
    end

    describe ".system_usage_data_settings" do
      let(:prometheus_client) { double(Gitlab::PrometheusClient) }
      let(:snowplow_gitlab_host?) { Gitlab::CurrentSettings.snowplow_collector_hostname == 'snowplow.trx.gitlab.net' }

      before do
        allow(described_class).to receive(:operating_system).and_return('ubuntu-20.04')
        expect(prometheus_client).to receive(:query).with(/gitlab_usage_ping:gitaly_apdex:ratio_avg_over_time_5m/).and_return([
          {
            'metric' => {},
            'value' => [1616016381.473, '0.95']
          }
        ])
        expect(described_class).to receive(:with_prometheus_client).and_yield(prometheus_client)
      end

      subject { described_class.system_usage_data_settings }

      it 'gathers encrypted secrets usage data', :aggregate_failures do
        expect(subject[:settings][:ldap_encrypted_secrets_enabled]).to eq(Gitlab::Auth::Ldap::Config.encrypted_secrets.active?)
        expect(subject[:settings][:smtp_encrypted_secrets_enabled]).to eq(Gitlab::Email::SmtpConfig.encrypted_secrets.active?)
      end

      it 'populates operating system information' do
        expect(subject[:settings][:operating_system]).to eq('ubuntu-20.04')
      end

      it 'gathers gitaly apdex', :aggregate_failures do
        expect(subject[:settings][:gitaly_apdex]).to be_within(0.001).of(0.95)
      end

      it 'reports collected data categories' do
        expected_value = %w[standard subscription operational optional]

        allow_next_instance_of(ServicePing::PermitDataCategories) do |instance|
          expect(instance).to receive(:execute).and_return(expected_value)
        end

        expect(subject[:settings][:collected_data_categories]).to eq(expected_value)
      end

      it 'gathers service_ping_features_enabled' do
        expect(subject[:settings][:service_ping_features_enabled]).to eq(Gitlab::CurrentSettings.usage_ping_features_enabled)
      end

      it 'gathers user_cap_feature_enabled' do
        expect(subject[:settings][:user_cap_feature_enabled]).to eq(Gitlab::CurrentSettings.new_user_signups_cap)
      end

      it 'reports status of the certificate_based_clusters feature flag as true' do
        expect(subject[:settings][:certificate_based_clusters_ff]).to eq(true)
      end

      context 'with certificate_based_clusters disabled' do
        before do
          stub_feature_flags(certificate_based_clusters: false)
        end

        it 'reports status of the certificate_based_clusters feature flag as false' do
          expect(subject[:settings][:certificate_based_clusters_ff]).to eq(false)
        end
      end

      context 'snowplow stats' do
        before do
          stub_feature_flags(usage_data_instrumentation: false)
        end

        it 'gathers snowplow stats' do
          expect(subject[:settings][:snowplow_enabled]).to eq(Gitlab::CurrentSettings.snowplow_enabled?)
          expect(subject[:settings][:snowplow_configured_to_gitlab_collector]).to eq(snowplow_gitlab_host?)
        end
      end
    end
  end

  describe '.merge_requests_users', :clean_gitlab_redis_shared_state do
    let(:time_period) { { created_at: 2.days.ago..time } }
    let(:time) { Time.current }

    before do
      counter = Gitlab::UsageDataCounters::TrackUniqueEvents
      merge_request = Event::TARGET_TYPES[:merge_request]
      design = Event::TARGET_TYPES[:design]

      counter.track_event(event_action: :commented, event_target: merge_request, author_id: 1, time: time)
      counter.track_event(event_action: :opened, event_target: merge_request, author_id: 1, time: time)
      counter.track_event(event_action: :merged, event_target: merge_request, author_id: 2, time: time)
      counter.track_event(event_action: :closed, event_target: merge_request, author_id: 3, time: time)
      counter.track_event(event_action: :opened, event_target: merge_request, author_id: 4, time: time - 3.days)
      counter.track_event(event_action: :created, event_target: design, author_id: 5, time: time)
    end

    it 'returns the distinct count of users using merge requests (via events table) within the specified time period' do
      expect(described_class.merge_requests_users(time_period)).to eq(3)
    end
  end

  def for_defined_days_back(days: [31, 3])
    days.each do |n|
      travel_to(n.days.ago) do
        yield
      end
    end
  end

  describe '#action_monthly_active_users', :clean_gitlab_redis_shared_state do
    let(:time_period) { { created_at: 2.days.ago..time } }
    let(:time) { Time.zone.now }
    let(:user1) { build(:user, id: 1) }
    let(:user2) { build(:user, id: 2) }
    let(:user3) { build(:user, id: 3) }
    let(:user4) { build(:user, id: 4) }
    let(:project) { build(:project) }

    before do
      counter = Gitlab::UsageDataCounters::TrackUniqueEvents
      project_type = Event::TARGET_TYPES[:project]
      wiki = Event::TARGET_TYPES[:wiki]
      design = Event::TARGET_TYPES[:design]

      counter.track_event(event_action: :pushed, event_target: project_type, author_id: 1)
      counter.track_event(event_action: :pushed, event_target: project_type, author_id: 1)
      counter.track_event(event_action: :pushed, event_target: project_type, author_id: 2)
      counter.track_event(event_action: :pushed, event_target: project_type, author_id: 3)
      counter.track_event(event_action: :pushed, event_target: project_type, author_id: 4, time: time - 3.days)
      counter.track_event(event_action: :created, event_target: wiki, author_id: 3)
      counter.track_event(event_action: :created, event_target: design, author_id: 3)
      counter.track_event(event_action: :created, event_target: design, author_id: 4)

      counter = Gitlab::UsageDataCounters::EditorUniqueCounter

      counter.track_web_ide_edit_action(author: user1, project: project)
      counter.track_web_ide_edit_action(author: user1, project: project)
      counter.track_sfe_edit_action(author: user1, project: project)
      counter.track_snippet_editor_edit_action(author: user1, project: project)
      counter.track_snippet_editor_edit_action(author: user1, time: time - 3.days, project: project)

      counter.track_web_ide_edit_action(author: user2, project: project)
      counter.track_sfe_edit_action(author: user2, project: project)

      counter.track_web_ide_edit_action(author: user3, time: time - 3.days, project: project)
      counter.track_snippet_editor_edit_action(author: user3, project: project)
    end

    it 'returns the distinct count of user actions within the specified time period' do
      expect(described_class.action_monthly_active_users(time_period)).to eq(
        {
          action_monthly_active_users_design_management: 2,
          action_monthly_active_users_project_repo: 3,
          action_monthly_active_users_wiki_repo: 1,
          action_monthly_active_users_git_write: 4,
          action_monthly_active_users_web_ide_edit: 2,
          action_monthly_active_users_sfe_edit: 2,
          action_monthly_active_users_snippet_editor_edit: 2,
          action_monthly_active_users_ide_edit: 3
        }
      )
    end
  end

  describe 'redis_hll_counters' do
    subject { described_class.redis_hll_counters }

    let(:categories) { ::Gitlab::UsageDataCounters::HLLRedisCounter.categories }

    let(:ignored_metrics) { ["i_package_composer_deploy_token_weekly"] }

    it 'has all known_events' do
      stub_feature_flags(use_redis_hll_instrumentation_classes: false)
      expect(subject).to have_key(:redis_hll_counters)

      expect(subject[:redis_hll_counters].keys).to match_array(categories)

      categories.each do |category|
        keys = ::Gitlab::UsageDataCounters::HLLRedisCounter.events_for_category(category)

        metrics = keys.map { |key| "#{key}_weekly" } + keys.map { |key| "#{key}_monthly" }
        metrics -= ignored_metrics

        if ::Gitlab::UsageDataCounters::HLLRedisCounter::CATEGORIES_FOR_TOTALS.include?(category)
          metrics.append("#{category}_total_unique_counts_weekly", "#{category}_total_unique_counts_monthly")
        end

        expect(subject[:redis_hll_counters][category].keys).to match_array(metrics)
      end
    end
  end

  describe '.aggregated_metrics_data' do
    it 'uses ::Gitlab::Usage::Metrics::Aggregates::Aggregate methods', :aggregate_failures do
      expected_payload = {
        counts_weekly: { aggregated_metrics: { global_search_gmau: 123 } },
        counts_monthly: { aggregated_metrics: { global_search_gmau: 456 } },
        counts: { aggregate_global_search_gmau: 789 }
      }

      expect_next_instance_of(::Gitlab::Usage::Metrics::Aggregates::Aggregate) do |instance|
        expect(instance).to receive(:weekly_data).and_return(global_search_gmau: 123)
        expect(instance).to receive(:monthly_data).and_return(global_search_gmau: 456)
        expect(instance).to receive(:all_time_data).and_return(global_search_gmau: 789)
      end
      expect(described_class.aggregated_metrics_data).to eq(expected_payload)
    end
  end

  describe '.service_desk_counts' do
    subject { described_class.send(:service_desk_counts) }

    let(:project) { create(:project, :service_desk_enabled) }

    it 'gathers Service Desk data' do
      create_list(:issue, 2, :confidential, author: User.support_bot, project: project)

      expect(subject).to eq(service_desk_enabled_projects: 1,
                            service_desk_issues: 2)
    end
  end

  describe '.email_campaign_counts' do
    subject { described_class.send(:email_campaign_counts) }

    context 'when queries time out' do
      before do
        allow_any_instance_of(ActiveRecord::Relation).to receive(:count).and_raise(ActiveRecord::StatementInvalid)
        allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(should_raise_for_dev)
      end

      context 'with should_raise_for_dev? true' do
        let(:should_raise_for_dev) { true }

        it 'raises an error' do
          expect { subject }.to raise_error(ActiveRecord::StatementInvalid)
        end
      end

      context 'with should_raise_for_dev? false' do
        let(:should_raise_for_dev) { false }

        it 'returns -1 for email campaign data' do
          expected_data = {
            "in_product_marketing_email_create_0_sent" => -1,
            "in_product_marketing_email_create_0_cta_clicked" => -1,
            "in_product_marketing_email_create_1_sent" => -1,
            "in_product_marketing_email_create_1_cta_clicked" => -1,
            "in_product_marketing_email_create_2_sent" => -1,
            "in_product_marketing_email_create_2_cta_clicked" => -1,
            "in_product_marketing_email_team_short_0_sent" => -1,
            "in_product_marketing_email_team_short_0_cta_clicked" => -1,
            "in_product_marketing_email_trial_short_0_sent" => -1,
            "in_product_marketing_email_trial_short_0_cta_clicked" => -1,
            "in_product_marketing_email_admin_verify_0_sent" => -1,
            "in_product_marketing_email_admin_verify_0_cta_clicked" => -1,
            "in_product_marketing_email_verify_0_sent" => -1,
            "in_product_marketing_email_verify_0_cta_clicked" => -1,
            "in_product_marketing_email_verify_1_sent" => -1,
            "in_product_marketing_email_verify_1_cta_clicked" => -1,
            "in_product_marketing_email_verify_2_sent" => -1,
            "in_product_marketing_email_verify_2_cta_clicked" => -1,
            "in_product_marketing_email_trial_0_sent" => -1,
            "in_product_marketing_email_trial_0_cta_clicked" => -1,
            "in_product_marketing_email_trial_1_sent" => -1,
            "in_product_marketing_email_trial_1_cta_clicked" => -1,
            "in_product_marketing_email_trial_2_sent" => -1,
            "in_product_marketing_email_trial_2_cta_clicked" => -1,
            "in_product_marketing_email_team_0_sent" => -1,
            "in_product_marketing_email_team_0_cta_clicked" => -1,
            "in_product_marketing_email_team_1_sent" => -1,
            "in_product_marketing_email_team_1_cta_clicked" => -1,
            "in_product_marketing_email_team_2_sent" => -1,
            "in_product_marketing_email_team_2_cta_clicked" => -1
          }

          expect(subject).to eq(expected_data)
        end
      end
    end

    context 'when there are entries' do
      before do
        create(:in_product_marketing_email, track: :create, series: 0, cta_clicked_at: Time.zone.now)
        create(:in_product_marketing_email, track: :verify, series: 0)
      end

      it 'gathers email campaign data' do
        expected_data = {
          "in_product_marketing_email_create_0_sent" => 1,
          "in_product_marketing_email_create_0_cta_clicked" => 1,
          "in_product_marketing_email_create_1_sent" => 0,
          "in_product_marketing_email_create_1_cta_clicked" => 0,
          "in_product_marketing_email_create_2_sent" => 0,
          "in_product_marketing_email_create_2_cta_clicked" => 0,
          "in_product_marketing_email_team_short_0_sent" => 0,
          "in_product_marketing_email_team_short_0_cta_clicked" => 0,
          "in_product_marketing_email_trial_short_0_sent" => 0,
          "in_product_marketing_email_trial_short_0_cta_clicked" => 0,
          "in_product_marketing_email_admin_verify_0_sent" => 0,
          "in_product_marketing_email_admin_verify_0_cta_clicked" => 0,
          "in_product_marketing_email_verify_0_sent" => 1,
          "in_product_marketing_email_verify_0_cta_clicked" => 0,
          "in_product_marketing_email_verify_1_sent" => 0,
          "in_product_marketing_email_verify_1_cta_clicked" => 0,
          "in_product_marketing_email_verify_2_sent" => 0,
          "in_product_marketing_email_verify_2_cta_clicked" => 0,
          "in_product_marketing_email_trial_0_sent" => 0,
          "in_product_marketing_email_trial_0_cta_clicked" => 0,
          "in_product_marketing_email_trial_1_sent" => 0,
          "in_product_marketing_email_trial_1_cta_clicked" => 0,
          "in_product_marketing_email_trial_2_sent" => 0,
          "in_product_marketing_email_trial_2_cta_clicked" => 0,
          "in_product_marketing_email_team_0_sent" => 0,
          "in_product_marketing_email_team_0_cta_clicked" => 0,
          "in_product_marketing_email_team_1_sent" => 0,
          "in_product_marketing_email_team_1_cta_clicked" => 0,
          "in_product_marketing_email_team_2_sent" => 0,
          "in_product_marketing_email_team_2_cta_clicked" => 0
        }

        expect(subject).to eq(expected_data)
      end
    end
  end

  describe ".with_duration" do
    it 'records duration' do
      expect(::Gitlab::Usage::ServicePing::LegacyMetricTimingDecorator)
        .to receive(:new).with(2, kind_of(Float))

      described_class.with_duration { 1 + 1 }
    end
  end

  context 'on Gitlab.com' do
    before do
      allow(Gitlab).to receive(:com?).and_return(true)
    end

    describe '.system_usage_data' do
      subject { described_class.system_usage_data }

      it 'returns fallback value for disabled metrics' do
        expect(subject[:counts][:ci_internal_pipelines]).to eq(Gitlab::Utils::UsageData::FALLBACK)
        expect(subject[:counts][:issues_created_gitlab_alerts]).to eq(Gitlab::Utils::UsageData::FALLBACK)
        expect(subject[:counts][:issues_created_manually_from_alerts]).to eq(Gitlab::Utils::UsageData::FALLBACK)
      end
    end
  end
end

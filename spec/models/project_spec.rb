# frozen_string_literal: true

require 'spec_helper'

describe Project do
  include ProjectForksHelper
  include GitHelpers
  include ExternalAuthorizationServiceHelpers

  it_behaves_like 'having unique enum values'

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:creator).class_name('User') }
    it { is_expected.to belong_to(:pool_repository) }
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_many(:services) }
    it { is_expected.to have_many(:events) }
    it { is_expected.to have_many(:merge_requests) }
    it { is_expected.to have_many(:issues) }
    it { is_expected.to have_many(:milestones) }
    it { is_expected.to have_many(:project_members).dependent(:delete_all) }
    it { is_expected.to have_many(:users).through(:project_members) }
    it { is_expected.to have_many(:requesters).dependent(:delete_all) }
    it { is_expected.to have_many(:notes) }
    it { is_expected.to have_many(:snippets).class_name('ProjectSnippet') }
    it { is_expected.to have_many(:deploy_keys_projects) }
    it { is_expected.to have_many(:deploy_keys) }
    it { is_expected.to have_many(:hooks) }
    it { is_expected.to have_many(:protected_branches) }
    it { is_expected.to have_one(:slack_service) }
    it { is_expected.to have_one(:microsoft_teams_service) }
    it { is_expected.to have_one(:mattermost_service) }
    it { is_expected.to have_one(:hangouts_chat_service) }
    it { is_expected.to have_one(:packagist_service) }
    it { is_expected.to have_one(:pushover_service) }
    it { is_expected.to have_one(:asana_service) }
    it { is_expected.to have_many(:boards) }
    it { is_expected.to have_one(:campfire_service) }
    it { is_expected.to have_one(:discord_service) }
    it { is_expected.to have_one(:drone_ci_service) }
    it { is_expected.to have_one(:emails_on_push_service) }
    it { is_expected.to have_one(:pipelines_email_service) }
    it { is_expected.to have_one(:irker_service) }
    it { is_expected.to have_one(:pivotaltracker_service) }
    it { is_expected.to have_one(:hipchat_service) }
    it { is_expected.to have_one(:flowdock_service) }
    it { is_expected.to have_one(:assembla_service) }
    it { is_expected.to have_one(:slack_slash_commands_service) }
    it { is_expected.to have_one(:mattermost_slash_commands_service) }
    it { is_expected.to have_one(:buildkite_service) }
    it { is_expected.to have_one(:bamboo_service) }
    it { is_expected.to have_one(:teamcity_service) }
    it { is_expected.to have_one(:jira_service) }
    it { is_expected.to have_one(:redmine_service) }
    it { is_expected.to have_one(:youtrack_service) }
    it { is_expected.to have_one(:custom_issue_tracker_service) }
    it { is_expected.to have_one(:bugzilla_service) }
    it { is_expected.to have_one(:gitlab_issue_tracker_service) }
    it { is_expected.to have_one(:external_wiki_service) }
    it { is_expected.to have_one(:project_feature) }
    it { is_expected.to have_one(:project_repository) }
    it { is_expected.to have_one(:statistics).class_name('ProjectStatistics') }
    it { is_expected.to have_one(:import_data).class_name('ProjectImportData') }
    it { is_expected.to have_one(:last_event).class_name('Event') }
    it { is_expected.to have_one(:forked_from_project).through(:fork_network_member) }
    it { is_expected.to have_one(:auto_devops).class_name('ProjectAutoDevops') }
    it { is_expected.to have_one(:error_tracking_setting).class_name('ErrorTracking::ProjectErrorTrackingSetting') }
    it { is_expected.to have_many(:commit_statuses) }
    it { is_expected.to have_many(:ci_pipelines) }
    it { is_expected.to have_many(:builds) }
    it { is_expected.to have_many(:build_trace_section_names)}
    it { is_expected.to have_many(:runner_projects) }
    it { is_expected.to have_many(:runners) }
    it { is_expected.to have_many(:variables) }
    it { is_expected.to have_many(:triggers) }
    it { is_expected.to have_many(:pages_domains) }
    it { is_expected.to have_many(:labels).class_name('ProjectLabel') }
    it { is_expected.to have_many(:users_star_projects) }
    it { is_expected.to have_many(:repository_languages) }
    it { is_expected.to have_many(:environments) }
    it { is_expected.to have_many(:deployments) }
    it { is_expected.to have_many(:todos) }
    it { is_expected.to have_many(:releases) }
    it { is_expected.to have_many(:lfs_objects_projects) }
    it { is_expected.to have_many(:project_group_links) }
    it { is_expected.to have_many(:notification_settings).dependent(:delete_all) }
    it { is_expected.to have_many(:forked_to_members).class_name('ForkNetworkMember') }
    it { is_expected.to have_many(:forks).through(:forked_to_members) }
    it { is_expected.to have_many(:uploads) }
    it { is_expected.to have_many(:pipeline_schedules) }
    it { is_expected.to have_many(:members_and_requesters) }
    it { is_expected.to have_many(:clusters) }
    it { is_expected.to have_many(:kubernetes_namespaces) }
    it { is_expected.to have_many(:custom_attributes).class_name('ProjectCustomAttribute') }
    it { is_expected.to have_many(:project_badges).class_name('ProjectBadge') }
    it { is_expected.to have_many(:lfs_file_locks) }
    it { is_expected.to have_many(:project_deploy_tokens) }
    it { is_expected.to have_many(:deploy_tokens).through(:project_deploy_tokens) }

    it 'has an inverse relationship with merge requests' do
      expect(described_class.reflect_on_association(:merge_requests).has_inverse?).to eq(:target_project)
    end

    context 'after initialized' do
      it "has a project_feature" do
        expect(described_class.new.project_feature).to be_present
      end
    end

    context 'when creating a new project' do
      it 'automatically creates a CI/CD settings row' do
        project = create(:project)

        expect(project.ci_cd_settings).to be_an_instance_of(ProjectCiCdSetting)
        expect(project.ci_cd_settings).to be_persisted
      end
    end

    context 'updating cd_cd_settings' do
      it 'does not raise an error' do
        project = create(:project)

        expect { project.update(ci_cd_settings: nil) }.not_to raise_exception
      end
    end

    describe '#members & #requesters' do
      let(:project) { create(:project, :public, :access_requestable) }
      let(:requester) { create(:user) }
      let(:developer) { create(:user) }
      before do
        project.request_access(requester)
        project.add_developer(developer)
      end

      it_behaves_like 'members and requesters associations' do
        let(:namespace) { project }
      end
    end

    describe 'ci_pipelines association' do
      it 'returns only pipelines from ci_sources' do
        expect(Ci::Pipeline).to receive(:ci_sources).and_call_original

        subject.ci_pipelines
      end
    end
  end

  describe 'modules' do
    subject { described_class }

    it { is_expected.to include_module(Gitlab::ConfigHelper) }
    it { is_expected.to include_module(Gitlab::ShellAdapter) }
    it { is_expected.to include_module(Gitlab::VisibilityLevel) }
    it { is_expected.to include_module(Referable) }
    it { is_expected.to include_module(Sortable) }
  end

  describe '.missing_kubernetes_namespace' do
    let!(:project) { create(:project) }
    let!(:cluster) { create(:cluster, :provided_by_user, :group) }
    let(:kubernetes_namespaces) { project.kubernetes_namespaces }

    subject { described_class.missing_kubernetes_namespace(kubernetes_namespaces) }

    it { is_expected.to contain_exactly(project) }

    context 'kubernetes namespace exists' do
      before do
        create(:cluster_kubernetes_namespace, project: project, cluster: cluster)
      end

      it { is_expected.to be_empty }
    end
  end

  describe 'validation' do
    let!(:project) { create(:project) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_length_of(:path).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(2000) }
    it { is_expected.to validate_length_of(:ci_config_path).is_at_most(255) }
    it { is_expected.to allow_value('').for(:ci_config_path) }
    it { is_expected.not_to allow_value('test/../foo').for(:ci_config_path) }
    it { is_expected.not_to allow_value('/test/foo').for(:ci_config_path) }
    it { is_expected.to validate_presence_of(:creator) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:repository_storage) }

    it 'validates build timeout constraints' do
      is_expected.to validate_numericality_of(:build_timeout)
        .only_integer
        .is_greater_than_or_equal_to(10.minutes)
        .is_less_than(1.month)
        .with_message('needs to be beetween 10 minutes and 1 month')
    end

    it 'does not allow new projects beyond user limits' do
      project2 = build(:project)

      allow(project2)
        .to receive(:creator)
        .and_return(
          double(can_create_project?: false, projects_limit: 0).as_null_object
        )

      expect(project2).not_to be_valid
    end

    describe 'wiki path conflict' do
      context "when the new path has been used by the wiki of other Project" do
        it 'has an error on the name attribute' do
          new_project = build_stubbed(:project, namespace_id: project.namespace_id, path: "#{project.path}.wiki")

          expect(new_project).not_to be_valid
          expect(new_project.errors[:name].first).to eq('has already been taken')
        end
      end

      context "when the new wiki path has been used by the path of other Project" do
        it 'has an error on the name attribute' do
          project_with_wiki_suffix = create(:project, path: 'foo.wiki')
          new_project = build_stubbed(:project, namespace_id: project_with_wiki_suffix.namespace_id, path: 'foo')

          expect(new_project).not_to be_valid
          expect(new_project.errors[:name].first).to eq('has already been taken')
        end
      end
    end

    context 'repository storages inclusion' do
      let(:project2) { build(:project, repository_storage: 'missing') }

      before do
        storages = { 'custom' => { 'path' => 'tmp/tests/custom_repositories' } }
        allow(Gitlab.config.repositories).to receive(:storages).and_return(storages)
      end

      it "does not allow repository storages that don't match a label in the configuration" do
        expect(project2).not_to be_valid
        expect(project2.errors[:repository_storage].first).to match(/is not included in the list/)
      end
    end

    describe 'import_url' do
      it 'does not allow an invalid URI as import_url' do
        project = build(:project, import_url: 'invalid://')

        expect(project).not_to be_valid
      end

      it 'does allow a SSH URI as import_url for persisted projects' do
        project = create(:project)
        project.import_url = 'ssh://test@gitlab.com/project.git'

        expect(project).to be_valid
      end

      it 'does not allow a SSH URI as import_url for new projects' do
        project = build(:project, import_url: 'ssh://test@gitlab.com/project.git')

        expect(project).not_to be_valid
      end

      it 'does allow a valid URI as import_url' do
        project = build(:project, import_url: 'http://gitlab.com/project.git')

        expect(project).to be_valid
      end

      it 'allows an empty URI' do
        project = build(:project, import_url: '')

        expect(project).to be_valid
      end

      it 'does not produce import data on an empty URI' do
        project = build(:project, import_url: '')

        expect(project.import_data).to be_nil
      end

      it 'does not produce import data on an invalid URI' do
        project = build(:project, import_url: 'test://')

        expect(project.import_data).to be_nil
      end

      it "does not allow import_url pointing to localhost" do
        project = build(:project, import_url: 'http://localhost:9000/t.git')

        expect(project).to be_invalid
        expect(project.errors[:import_url].first).to include('Requests to localhost are not allowed')
      end

      it 'does not allow import_url pointing to the local network' do
        project = build(:project, import_url: 'https://192.168.1.1')

        expect(project).to be_invalid
        expect(project.errors[:import_url].first).to include('Requests to the local network are not allowed')
      end

      it "does not allow import_url with invalid ports for new projects" do
        project = build(:project, import_url: 'http://github.com:25/t.git')

        expect(project).to be_invalid
        expect(project.errors[:import_url].first).to include('Only allowed ports are 80, 443')
      end

      it "does not allow import_url with invalid ports for persisted projects" do
        project = create(:project)
        project.import_url = 'http://github.com:25/t.git'

        expect(project).to be_invalid
        expect(project.errors[:import_url].first).to include('Only allowed ports are 22, 80, 443')
      end

      it "does not allow import_url with invalid user" do
        project = build(:project, import_url: 'http://$user:password@github.com/t.git')

        expect(project).to be_invalid
        expect(project.errors[:import_url].first).to include('Username needs to start with an alphanumeric character')
      end

      include_context 'invalid urls'

      it 'does not allow urls with CR or LF characters' do
        project = build(:project)

        aggregate_failures do
          urls_with_CRLF.each do |url|
            project.import_url = url

            expect(project).not_to be_valid
            expect(project.errors.full_messages.first).to match(/is blocked: URI is invalid/)
          end
        end
      end
    end

    describe 'project pending deletion' do
      let!(:project_pending_deletion) do
        create(:project,
               pending_delete: true)
      end
      let(:new_project) do
        build(:project,
              name: project_pending_deletion.name,
              namespace: project_pending_deletion.namespace)
      end

      before do
        new_project.validate
      end

      it 'contains errors related to the project being deleted' do
        expect(new_project.errors.full_messages.first).to eq('The project is still being deleted. Please try again later.')
      end
    end

    describe 'path validation' do
      it 'allows paths reserved on the root namespace' do
        project = build(:project, path: 'api')

        expect(project).to be_valid
      end

      it 'rejects paths reserved on another level' do
        project = build(:project, path: 'tree')

        expect(project).not_to be_valid
      end

      it 'rejects nested paths' do
        parent = create(:group, :nested, path: 'environments')
        project = build(:project, path: 'folders', namespace: parent)

        expect(project).not_to be_valid
      end

      it 'allows a reserved group name' do
        parent = create(:group)
        project = build(:project, path: 'avatar', namespace: parent)

        expect(project).to be_valid
      end

      it 'allows a path ending in a period' do
        project = build(:project, path: 'foo.')

        expect(project).to be_valid
      end
    end
  end

  describe '#all_pipelines' do
    let(:project) { create(:project) }

    before do
      create(:ci_pipeline, project: project, ref: 'master', source: :web)
      create(:ci_pipeline, project: project, ref: 'master', source: :external)
    end

    it 'has all pipelines' do
      expect(project.all_pipelines.size).to eq(2)
    end

    context 'when builds are disabled' do
      before do
        project.project_feature.update_attribute(:builds_access_level, ProjectFeature::DISABLED)
      end

      it 'returns .external pipelines' do
        expect(project.all_pipelines).to all(have_attributes(source: 'external'))
        expect(project.all_pipelines.size).to eq(1)
      end
    end
  end

  describe '#ci_pipelines' do
    let(:project) { create(:project) }

    before do
      create(:ci_pipeline, project: project, ref: 'master', source: :web)
      create(:ci_pipeline, project: project, ref: 'master', source: :external)
    end

    it 'has ci pipelines' do
      expect(project.ci_pipelines.size).to eq(2)
    end

    context 'when builds are disabled' do
      before do
        project.project_feature.update_attribute(:builds_access_level, ProjectFeature::DISABLED)
      end

      it 'returns .external pipelines' do
        expect(project.ci_pipelines).to all(have_attributes(source: 'external'))
        expect(project.ci_pipelines.size).to eq(1)
      end
    end
  end

  describe 'project token' do
    it 'sets an random token if none provided' do
      project = FactoryBot.create(:project, runners_token: '')
      expect(project.runners_token).not_to eq('')
    end

    it 'does not set an random token if one provided' do
      project = FactoryBot.create(:project, runners_token: 'my-token')
      expect(project.runners_token).to eq('my-token')
    end
  end

  describe 'Respond to' do
    it { is_expected.to respond_to(:url_to_repo) }
    it { is_expected.to respond_to(:repo_exists?) }
    it { is_expected.to respond_to(:execute_hooks) }
    it { is_expected.to respond_to(:owner) }
    it { is_expected.to respond_to(:path_with_namespace) }
    it { is_expected.to respond_to(:full_path) }
  end

  describe 'delegation' do
    [:add_guest, :add_reporter, :add_developer, :add_maintainer, :add_user, :add_users].each do |method|
      it { is_expected.to delegate_method(method).to(:team) }
    end

    it { is_expected.to delegate_method(:members).to(:team).with_prefix(true) }
    it { is_expected.to delegate_method(:name).to(:owner).with_prefix(true).with_arguments(allow_nil: true) }
    it { is_expected.to delegate_method(:group_clusters_enabled?).to(:group).with_arguments(allow_nil: true) }
    it { is_expected.to delegate_method(:root_ancestor).to(:namespace).with_arguments(allow_nil: true) }
    it { is_expected.to delegate_method(:last_pipeline).to(:commit).with_arguments(allow_nil: true) }
  end

  describe '#to_reference_with_postfix' do
    it 'returns the full path with reference_postfix' do
      namespace = create(:namespace, path: 'sample-namespace')
      project = create(:project, path: 'sample-project', namespace: namespace)

      expect(project.to_reference_with_postfix).to eq 'sample-namespace/sample-project>'
    end
  end

  describe '#to_reference' do
    let(:owner)     { create(:user, name: 'Gitlab') }
    let(:namespace) { create(:namespace, path: 'sample-namespace', owner: owner) }
    let(:project)   { create(:project, path: 'sample-project', namespace: namespace) }
    let(:group)     { create(:group, name: 'Group', path: 'sample-group') }

    context 'when nil argument' do
      it 'returns nil' do
        expect(project.to_reference).to be_nil
      end
    end

    context 'when full is true' do
      it 'returns complete path to the project' do
        expect(project.to_reference(full: true)).to          eq 'sample-namespace/sample-project'
        expect(project.to_reference(project, full: true)).to eq 'sample-namespace/sample-project'
        expect(project.to_reference(group, full: true)).to   eq 'sample-namespace/sample-project'
      end
    end

    context 'when same project argument' do
      it 'returns nil' do
        expect(project.to_reference(project)).to be_nil
      end
    end

    context 'when cross namespace project argument' do
      let(:another_namespace_project) { create(:project, name: 'another-project') }

      it 'returns complete path to the project' do
        expect(project.to_reference(another_namespace_project)).to eq 'sample-namespace/sample-project'
      end
    end

    context 'when same namespace / cross-project argument' do
      let(:another_project) { create(:project, namespace: namespace) }

      it 'returns path to the project' do
        expect(project.to_reference(another_project)).to eq 'sample-project'
      end
    end

    context 'when different namespace / cross-project argument' do
      let(:another_namespace) { create(:namespace, path: 'another-namespace', owner: owner) }
      let(:another_project)   { create(:project, path: 'another-project', namespace: another_namespace) }

      it 'returns full path to the project' do
        expect(project.to_reference(another_project)).to eq 'sample-namespace/sample-project'
      end
    end

    context 'when argument is a namespace' do
      context 'with same project path' do
        it 'returns path to the project' do
          expect(project.to_reference(namespace)).to eq 'sample-project'
        end
      end

      context 'with different project path' do
        it 'returns full path to the project' do
          expect(project.to_reference(group)).to eq 'sample-namespace/sample-project'
        end
      end
    end
  end

  describe '#to_human_reference' do
    let(:owner) { create(:user, name: 'Gitlab') }
    let(:namespace) { create(:namespace, name: 'Sample namespace', owner: owner) }
    let(:project) { create(:project, name: 'Sample project', namespace: namespace) }

    context 'when nil argument' do
      it 'returns nil' do
        expect(project.to_human_reference).to be_nil
      end
    end

    context 'when same project argument' do
      it 'returns nil' do
        expect(project.to_human_reference(project)).to be_nil
      end
    end

    context 'when cross namespace project argument' do
      let(:another_namespace_project) { create(:project, name: 'another-project') }

      it 'returns complete name with namespace of the project' do
        expect(project.to_human_reference(another_namespace_project)).to eq 'Gitlab / Sample project'
      end
    end

    context 'when same namespace / cross-project argument' do
      let(:another_project) { create(:project, namespace: namespace) }

      it 'returns name of the project' do
        expect(project.to_human_reference(another_project)).to eq 'Sample project'
      end
    end
  end

  describe '#merge_method' do
    using RSpec::Parameterized::TableSyntax

    where(:ff, :rebase, :method) do
      true  | true  | :ff
      true  | false | :ff
      false | true  | :rebase_merge
      false | false | :merge
    end

    with_them do
      let(:project) { build(:project, merge_requests_rebase_enabled: rebase, merge_requests_ff_only_enabled: ff) }

      subject { project.merge_method }

      it { is_expected.to eq(method) }
    end
  end

  it 'returns valid url to repo' do
    project = described_class.new(path: 'somewhere')
    expect(project.url_to_repo).to eq(Gitlab.config.gitlab_shell.ssh_path_prefix + 'somewhere.git')
  end

  describe "#web_url" do
    let(:project) { create(:project, path: "somewhere") }

    it 'returns the full web URL for this repo' do
      expect(project.web_url).to eq("#{Gitlab.config.gitlab.url}/#{project.namespace.full_path}/somewhere")
    end
  end

  describe "#readme_url" do
    context 'with a non-existing repository' do
      let(:project) { create(:project) }

      it 'returns nil' do
        expect(project.readme_url).to be_nil
      end
    end

    context 'with an existing repository' do
      context 'when no README exists' do
        let(:project) { create(:project, :empty_repo) }

        it 'returns nil' do
          expect(project.readme_url).to be_nil
        end
      end

      context 'when a README exists' do
        let(:project) { create(:project, :repository) }

        it 'returns the README' do
          expect(project.readme_url).to eq("#{project.web_url}/blob/master/README.md")
        end
      end
    end
  end

  describe "#new_issuable_address" do
    let(:project) { create(:project, path: "somewhere") }
    let(:user) { create(:user) }

    context 'incoming email enabled' do
      before do
        stub_incoming_email_setting(enabled: true, address: "p+%{key}@gl.ab")
      end

      it 'returns the address to create a new issue' do
        address = "p+#{project.full_path_slug}-#{project.project_id}-#{user.incoming_email_token}-issue@gl.ab"

        expect(project.new_issuable_address(user, 'issue')).to eq(address)
      end

      it 'returns the address to create a new merge request' do
        address = "p+#{project.full_path_slug}-#{project.project_id}-#{user.incoming_email_token}-merge-request@gl.ab"

        expect(project.new_issuable_address(user, 'merge_request')).to eq(address)
      end

      it 'returns nil with invalid address type' do
        expect(project.new_issuable_address(user, 'invalid_param')).to be_nil
      end
    end

    context 'incoming email disabled' do
      before do
        stub_incoming_email_setting(enabled: false)
      end

      it 'returns nil' do
        expect(project.new_issuable_address(user, 'issue')).to be_nil
      end

      it 'returns nil' do
        expect(project.new_issuable_address(user, 'merge_request')).to be_nil
      end
    end
  end

  describe 'last_activity methods' do
    let(:timestamp) { 2.hours.ago }
    # last_activity_at gets set to created_at upon creation
    let(:project) { create(:project, created_at: timestamp, updated_at: timestamp) }

    describe 'last_activity' do
      it 'alias last_activity to last_event' do
        last_event = create(:event, :closed, project: project)

        expect(project.last_activity).to eq(last_event)
      end
    end

    describe 'last_activity_date' do
      it 'returns the creation date of the project\'s last event if present' do
        new_event = create(:event, :closed, project: project, created_at: Time.now)

        project.reload
        expect(project.last_activity_at.to_i).to eq(new_event.created_at.to_i)
      end

      it 'returns the project\'s last update date if it has no events' do
        expect(project.last_activity_date).to eq(project.updated_at)
      end

      it 'returns the most recent timestamp' do
        project.update(updated_at: nil,
                       last_activity_at: timestamp,
                       last_repository_updated_at: timestamp - 1.hour)

        expect(project.last_activity_date).to be_like_time(timestamp)

        project.update(updated_at: timestamp,
                       last_activity_at: timestamp - 1.hour,
                       last_repository_updated_at: nil)

        expect(project.last_activity_date).to be_like_time(timestamp)
      end
    end
  end

  describe '#get_issue' do
    let(:project) { create(:project) }
    let!(:issue)  { create(:issue, project: project) }
    let(:user)    { create(:user) }

    before do
      project.add_developer(user)
    end

    context 'with default issues tracker' do
      it 'returns an issue' do
        expect(project.get_issue(issue.iid, user)).to eq issue
      end

      it 'returns count of open issues' do
        expect(project.open_issues_count).to eq(1)
      end

      it 'returns nil when no issue found' do
        expect(project.get_issue(999, user)).to be_nil
      end

      it "returns nil when user doesn't have access" do
        user = create(:user)
        expect(project.get_issue(issue.iid, user)).to eq nil
      end
    end

    context 'with external issues tracker' do
      let!(:internal_issue) { create(:issue, project: project) }
      before do
        allow(project).to receive(:external_issue_tracker).and_return(true)
      end

      context 'when internal issues are enabled' do
        it 'returns interlan issue' do
          issue = project.get_issue(internal_issue.iid, user)

          expect(issue).to be_kind_of(Issue)
          expect(issue.iid).to eq(internal_issue.iid)
          expect(issue.project).to eq(project)
        end

        it 'returns an ExternalIssue when internal issue does not exists' do
          issue = project.get_issue('FOO-1234', user)

          expect(issue).to be_kind_of(ExternalIssue)
          expect(issue.iid).to eq('FOO-1234')
          expect(issue.project).to eq(project)
        end
      end

      context 'when internal issues are disabled' do
        before do
          project.issues_enabled = false
          project.save!
        end

        it 'returns always an External issues' do
          issue = project.get_issue(internal_issue.iid, user)
          expect(issue).to be_kind_of(ExternalIssue)
          expect(issue.iid).to eq(internal_issue.iid.to_s)
          expect(issue.project).to eq(project)
        end

        it 'returns an ExternalIssue when internal issue does not exists' do
          issue = project.get_issue('FOO-1234', user)
          expect(issue).to be_kind_of(ExternalIssue)
          expect(issue.iid).to eq('FOO-1234')
          expect(issue.project).to eq(project)
        end
      end
    end
  end

  describe '#issue_exists?' do
    let(:project) { create(:project) }

    it 'is truthy when issue exists' do
      expect(project).to receive(:get_issue).and_return(double)
      expect(project.issue_exists?(1)).to be_truthy
    end

    it 'is falsey when issue does not exist' do
      expect(project).to receive(:get_issue).and_return(nil)
      expect(project.issue_exists?(1)).to be_falsey
    end
  end

  describe '#to_param' do
    context 'with namespace' do
      before do
        @group = create(:group, name: 'gitlab')
        @project = create(:project, name: 'gitlabhq', namespace: @group)
      end

      it { expect(@project.to_param).to eq('gitlabhq') }
    end

    context 'with invalid path' do
      it 'returns previous path to keep project suitable for use in URLs when persisted' do
        project = create(:project, path: 'gitlab')
        project.path = 'foo&bar'

        expect(project).not_to be_valid
        expect(project.to_param).to eq 'gitlab'
      end

      it 'returns current path when new record' do
        project = build(:project, path: 'gitlab')
        project.path = 'foo&bar'

        expect(project).not_to be_valid
        expect(project.to_param).to eq 'foo&bar'
      end
    end
  end

  describe '#repository' do
    let(:project) { create(:project, :repository) }

    it 'returns valid repo' do
      expect(project.repository).to be_kind_of(Repository)
    end
  end

  describe '#default_issues_tracker?' do
    it "is true if used internal tracker" do
      project = build(:project)

      expect(project.default_issues_tracker?).to be_truthy
    end

    it "is false if used other tracker" do
      # NOTE: The current nature of this factory requires persistence
      project = create(:redmine_project)

      expect(project.default_issues_tracker?).to be_falsey
    end
  end

  describe '#empty_repo?' do
    context 'when the repo does not exist' do
      let(:project) { build_stubbed(:project) }

      it 'returns true' do
        expect(project.empty_repo?).to be(true)
      end
    end

    context 'when the repo exists' do
      let(:project) { create(:project, :repository) }
      let(:empty_project) { create(:project, :empty_repo) }

      it { expect(empty_project.empty_repo?).to be(true) }
      it { expect(project.empty_repo?).to be(false) }
    end
  end

  describe '#external_issue_tracker' do
    let(:project) { create(:project) }
    let(:ext_project) { create(:redmine_project) }

    context 'on existing projects with no value for has_external_issue_tracker' do
      before do
        project.update_column(:has_external_issue_tracker, nil)
        ext_project.update_column(:has_external_issue_tracker, nil)
      end

      it 'updates the has_external_issue_tracker boolean' do
        expect do
          project.external_issue_tracker
        end.to change { project.reload.has_external_issue_tracker }.to(false)

        expect do
          ext_project.external_issue_tracker
        end.to change { ext_project.reload.has_external_issue_tracker }.to(true)
      end
    end

    it 'returns nil and does not query services when there is no external issue tracker' do
      expect(project).not_to receive(:services)

      expect(project.external_issue_tracker).to eq(nil)
    end

    it 'retrieves external_issue_tracker querying services and cache it when there is external issue tracker' do
      ext_project.reload # Factory returns a project with changed attributes
      expect(ext_project).to receive(:services).once.and_call_original

      2.times { expect(ext_project.external_issue_tracker).to be_a_kind_of(RedmineService) }
    end
  end

  describe '#cache_has_external_issue_tracker' do
    let(:project) { create(:project, has_external_issue_tracker: nil) }

    it 'stores true if there is any external_issue_tracker' do
      services = double(:service, external_issue_trackers: [RedmineService.new])
      expect(project).to receive(:services).and_return(services)

      expect do
        project.cache_has_external_issue_tracker
      end.to change { project.has_external_issue_tracker}.to(true)
    end

    it 'stores false if there is no external_issue_tracker' do
      services = double(:service, external_issue_trackers: [])
      expect(project).to receive(:services).and_return(services)

      expect do
        project.cache_has_external_issue_tracker
      end.to change { project.has_external_issue_tracker}.to(false)
    end

    it 'does not cache data when in a read-only GitLab instance' do
      allow(Gitlab::Database).to receive(:read_only?) { true }

      expect do
        project.cache_has_external_issue_tracker
      end.not_to change { project.has_external_issue_tracker }
    end
  end

  describe '#cache_has_external_wiki' do
    let(:project) { create(:project, has_external_wiki: nil) }

    it 'stores true if there is any external_wikis' do
      services = double(:service, external_wikis: [ExternalWikiService.new])
      expect(project).to receive(:services).and_return(services)

      expect do
        project.cache_has_external_wiki
      end.to change { project.has_external_wiki}.to(true)
    end

    it 'stores false if there is no external_wikis' do
      services = double(:service, external_wikis: [])
      expect(project).to receive(:services).and_return(services)

      expect do
        project.cache_has_external_wiki
      end.to change { project.has_external_wiki}.to(false)
    end

    it 'does not cache data when in a read-only GitLab instance' do
      allow(Gitlab::Database).to receive(:read_only?) { true }

      expect do
        project.cache_has_external_wiki
      end.not_to change { project.has_external_wiki }
    end
  end

  describe '#has_wiki?' do
    let(:no_wiki_project)       { create(:project, :wiki_disabled, has_external_wiki: false) }
    let(:wiki_enabled_project)  { create(:project) }
    let(:external_wiki_project) { create(:project, has_external_wiki: true) }

    it 'returns true if project is wiki enabled or has external wiki' do
      expect(wiki_enabled_project).to have_wiki
      expect(external_wiki_project).to have_wiki
      expect(no_wiki_project).not_to have_wiki
    end
  end

  describe '#external_wiki' do
    let(:project) { create(:project) }

    context 'with an active external wiki' do
      before do
        create(:service, project: project, type: 'ExternalWikiService', active: true)
        project.external_wiki
      end

      it 'sets :has_external_wiki as true' do
        expect(project.has_external_wiki).to be(true)
      end

      it 'sets :has_external_wiki as false if an external wiki service is destroyed later' do
        expect(project.has_external_wiki).to be(true)

        project.services.external_wikis.first.destroy

        expect(project.has_external_wiki).to be(false)
      end
    end

    context 'with an inactive external wiki' do
      before do
        create(:service, project: project, type: 'ExternalWikiService', active: false)
      end

      it 'sets :has_external_wiki as false' do
        expect(project.has_external_wiki).to be(false)
      end
    end

    context 'with no external wiki' do
      before do
        project.external_wiki
      end

      it 'sets :has_external_wiki as false' do
        expect(project.has_external_wiki).to be(false)
      end

      it 'sets :has_external_wiki as true if an external wiki service is created later' do
        expect(project.has_external_wiki).to be(false)

        create(:service, project: project, type: 'ExternalWikiService', active: true)

        expect(project.has_external_wiki).to be(true)
      end
    end
  end

  describe '#star_count' do
    it 'counts stars from multiple users' do
      user1 = create(:user)
      user2 = create(:user)
      project = create(:project, :public)

      expect(project.star_count).to eq(0)

      user1.toggle_star(project)
      expect(project.reload.star_count).to eq(1)

      user2.toggle_star(project)
      project.reload
      expect(project.reload.star_count).to eq(2)

      user1.toggle_star(project)
      project.reload
      expect(project.reload.star_count).to eq(1)

      user2.toggle_star(project)
      project.reload
      expect(project.reload.star_count).to eq(0)
    end

    it 'counts stars on the right project' do
      user = create(:user)
      project1 = create(:project, :public)
      project2 = create(:project, :public)

      expect(project1.star_count).to eq(0)
      expect(project2.star_count).to eq(0)

      user.toggle_star(project1)
      project1.reload
      project2.reload
      expect(project1.star_count).to eq(1)
      expect(project2.star_count).to eq(0)

      user.toggle_star(project1)
      project1.reload
      project2.reload
      expect(project1.star_count).to eq(0)
      expect(project2.star_count).to eq(0)

      user.toggle_star(project2)
      project1.reload
      project2.reload
      expect(project1.star_count).to eq(0)
      expect(project2.star_count).to eq(1)

      user.toggle_star(project2)
      project1.reload
      project2.reload
      expect(project1.star_count).to eq(0)
      expect(project2.star_count).to eq(0)
    end
  end

  describe '#avatar_type' do
    let(:project) { create(:project) }

    it 'is true if avatar is image' do
      project.update_attribute(:avatar, 'uploads/avatar.png')
      expect(project.avatar_type).to be_truthy
    end

    it 'is false if avatar is html page' do
      project.update_attribute(:avatar, 'uploads/avatar.html')
      expect(project.avatar_type).to eq(['file format is not supported. Please try one of the following supported formats: png, jpg, jpeg, gif, bmp, tiff, ico'])
    end
  end

  describe '#avatar_url' do
    subject { project.avatar_url }

    let(:project) { create(:project) }

    context 'when avatar file is uploaded' do
      let(:project) { create(:project, :public, :with_avatar) }

      it 'shows correct url' do
        expect(project.avatar_url).to eq(project.avatar.url)
        expect(project.avatar_url(only_path: false)).to eq([Gitlab.config.gitlab.url, project.avatar.url].join)
      end
    end

    context 'when avatar file in git' do
      before do
        allow(project).to receive(:avatar_in_git) { true }
      end

      let(:avatar_path) { "/#{project.full_path}/avatar" }

      it { is_expected.to eq "http://#{Gitlab.config.gitlab.host}#{avatar_path}" }
    end

    context 'when git repo is empty' do
      let(:project) { create(:project) }

      it { is_expected.to eq nil }
    end
  end

  describe '#pipeline_for' do
    let(:project) { create(:project, :repository) }
    let!(:pipeline) { create_pipeline(project) }

    shared_examples 'giving the correct pipeline' do
      it { is_expected.to eq(pipeline) }

      context 'return latest' do
        let!(:pipeline2) { create_pipeline(project) }

        it { is_expected.to eq(pipeline2) }
      end
    end

    context 'with explicit sha' do
      subject { project.pipeline_for('master', pipeline.sha) }

      it_behaves_like 'giving the correct pipeline'
    end

    context 'with implicit sha' do
      subject { project.pipeline_for('master') }

      it_behaves_like 'giving the correct pipeline'
    end
  end

  describe '#builds_enabled' do
    let(:project) { create(:project) }

    subject { project.builds_enabled }

    it { expect(project.builds_enabled?).to be_truthy }
  end

  describe '.sort_by_attribute' do
    it 'reorders the input relation by start count desc' do
      project1 = create(:project, star_count: 2)
      project2 = create(:project, star_count: 1)
      project3 = create(:project)

      projects = described_class.sort_by_attribute(:stars_desc)

      expect(projects).to eq([project1, project2, project3])
    end
  end

  describe '.with_shared_runners' do
    subject { described_class.with_shared_runners }

    context 'when shared runners are enabled for project' do
      let!(:project) { create(:project, shared_runners_enabled: true) }

      it "returns a project" do
        is_expected.to eq([project])
      end
    end

    context 'when shared runners are disabled for project' do
      let!(:project) { create(:project, shared_runners_enabled: false) }

      it "returns an empty array" do
        is_expected.to be_empty
      end
    end
  end

  describe '.cached_count', :use_clean_rails_memory_store_caching do
    let(:group)     { create(:group, :public) }
    let!(:project1) { create(:project, :public, group: group) }
    let!(:project2) { create(:project, :public, group: group) }

    it 'returns total project count' do
      expect(described_class).to receive(:count).once.and_call_original

      3.times do
        expect(described_class.cached_count).to eq(2)
      end
    end
  end

  describe '.trending' do
    let(:group)    { create(:group, :public) }
    let(:project1) { create(:project, :public, group: group) }
    let(:project2) { create(:project, :public, group: group) }

    before do
      2.times do
        create(:note_on_commit, project: project1)
      end

      create(:note_on_commit, project: project2)

      TrendingProject.refresh!
    end

    subject { described_class.trending.to_a }

    it 'sorts projects by the amount of notes in descending order' do
      expect(subject).to eq([project1, project2])
    end

    it 'does not take system notes into account' do
      10.times do
        create(:note_on_commit, project: project2, system: true)
      end

      expect(described_class.trending.to_a).to eq([project1, project2])
    end
  end

  describe '.starred_by' do
    it 'returns only projects starred by the given user' do
      user1 = create(:user)
      user2 = create(:user)
      project1 = create(:project)
      project2 = create(:project)
      create(:project)
      user1.toggle_star(project1)
      user2.toggle_star(project2)

      expect(described_class.starred_by(user1)).to contain_exactly(project1)
    end
  end

  describe '.visible_to_user' do
    let!(:project) { create(:project, :private) }
    let!(:user)    { create(:user) }

    subject { described_class.visible_to_user(user) }

    describe 'when a user has access to a project' do
      before do
        project.add_user(user, Gitlab::Access::MAINTAINER)
      end

      it { is_expected.to eq([project]) }
    end

    describe 'when a user does not have access to any projects' do
      it { is_expected.to eq([]) }
    end
  end

  context 'repository storage by default' do
    let(:project) { build(:project) }

    before do
      storages = {
        'default' => Gitlab::GitalyClient::StorageSettings.new('path' => 'tmp/tests/repositories'),
        'picked'  => Gitlab::GitalyClient::StorageSettings.new('path' => 'tmp/tests/repositories')
      }
      allow(Gitlab.config.repositories).to receive(:storages).and_return(storages)
    end

    it 'picks storage from ApplicationSetting' do
      expect_any_instance_of(ApplicationSetting).to receive(:pick_repository_storage).and_return('picked')

      expect(project.repository_storage).to eq('picked')
    end
  end

  context 'shared runners by default' do
    let(:project) { create(:project) }

    subject { project.shared_runners_enabled }

    context 'are enabled' do
      before do
        stub_application_setting(shared_runners_enabled: true)
      end

      it { is_expected.to be_truthy }
    end

    context 'are disabled' do
      before do
        stub_application_setting(shared_runners_enabled: false)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#any_runners?' do
    context 'shared runners' do
      let(:project) { create(:project, shared_runners_enabled: shared_runners_enabled) }
      let(:specific_runner) { create(:ci_runner, :project, projects: [project]) }
      let(:shared_runner) { create(:ci_runner, :instance) }

      context 'for shared runners disabled' do
        let(:shared_runners_enabled) { false }

        it 'has no runners available' do
          expect(project.any_runners?).to be_falsey
        end

        it 'has a specific runner' do
          specific_runner

          expect(project.any_runners?).to be_truthy
        end

        it 'has a shared runner, but they are prohibited to use' do
          shared_runner

          expect(project.any_runners?).to be_falsey
        end

        it 'checks the presence of specific runner' do
          specific_runner

          expect(project.any_runners? { |runner| runner == specific_runner }).to be_truthy
        end

        it 'returns false if match cannot be found' do
          specific_runner

          expect(project.any_runners? { false }).to be_falsey
        end
      end

      context 'for shared runners enabled' do
        let(:shared_runners_enabled) { true }

        it 'has a shared runner' do
          shared_runner

          expect(project.any_runners?).to be_truthy
        end

        it 'checks the presence of shared runner' do
          shared_runner

          expect(project.any_runners? { |runner| runner == shared_runner }).to be_truthy
        end

        it 'returns false if match cannot be found' do
          shared_runner

          expect(project.any_runners? { false }).to be_falsey
        end
      end
    end

    context 'group runners' do
      let(:project) { create(:project, group_runners_enabled: group_runners_enabled) }
      let(:group) { create(:group, projects: [project]) }
      let(:group_runner) { create(:ci_runner, :group, groups: [group]) }

      context 'for group runners disabled' do
        let(:group_runners_enabled) { false }

        it 'has no runners available' do
          expect(project.any_runners?).to be_falsey
        end

        it 'has a group runner, but they are prohibited to use' do
          group_runner

          expect(project.any_runners?).to be_falsey
        end
      end

      context 'for group runners enabled' do
        let(:group_runners_enabled) { true }

        it 'has a group runner' do
          group_runner

          expect(project.any_runners?).to be_truthy
        end

        it 'checks the presence of group runner' do
          group_runner

          expect(project.any_runners? { |runner| runner == group_runner }).to be_truthy
        end

        it 'returns false if match cannot be found' do
          group_runner

          expect(project.any_runners? { false }).to be_falsey
        end
      end
    end
  end

  describe '#shared_runners' do
    let!(:runner) { create(:ci_runner, :instance) }

    subject { project.shared_runners }

    context 'when shared runners are enabled for project' do
      let!(:project) { create(:project, shared_runners_enabled: true) }

      it "returns a list of shared runners" do
        is_expected.to eq([runner])
      end
    end

    context 'when shared runners are disabled for project' do
      let!(:project) { create(:project, shared_runners_enabled: false) }

      it "returns a empty list" do
        is_expected.to be_empty
      end
    end
  end

  describe '#visibility_level' do
    let(:project) { build(:project) }

    subject { project.visibility_level }

    context 'by default' do
      it { is_expected.to eq(Gitlab::VisibilityLevel::PRIVATE) }
    end

    context 'when set to INTERNAL in application settings' do
      before do
        stub_application_setting(default_project_visibility: Gitlab::VisibilityLevel::INTERNAL)
      end

      it { is_expected.to eq(Gitlab::VisibilityLevel::INTERNAL) }
    end
  end

  describe '#visibility_level_allowed?' do
    let(:project) { create(:project, :internal) }

    context 'when checking on non-forked project' do
      it { expect(project.visibility_level_allowed?(Gitlab::VisibilityLevel::PRIVATE)).to be_truthy }
      it { expect(project.visibility_level_allowed?(Gitlab::VisibilityLevel::INTERNAL)).to be_truthy }
      it { expect(project.visibility_level_allowed?(Gitlab::VisibilityLevel::PUBLIC)).to be_truthy }
    end

    context 'when checking on forked project' do
      let(:project)        { create(:project, :internal) }
      let(:forked_project) { fork_project(project) }

      it { expect(forked_project.visibility_level_allowed?(Gitlab::VisibilityLevel::PRIVATE)).to be_truthy }
      it { expect(forked_project.visibility_level_allowed?(Gitlab::VisibilityLevel::INTERNAL)).to be_truthy }
      it { expect(forked_project.visibility_level_allowed?(Gitlab::VisibilityLevel::PUBLIC)).to be_falsey }
    end
  end

  describe '#pages_deployed?' do
    let(:project) { create(:project) }

    subject { project.pages_deployed? }

    context 'if public folder does exist' do
      before do
        allow(Dir).to receive(:exist?).with(project.public_pages_path).and_return(true)
      end

      it { is_expected.to be_truthy }
    end

    context "if public folder doesn't exist" do
      it { is_expected.to be_falsey }
    end
  end

  describe '#pages_url' do
    let(:group) { create(:group, name: group_name) }
    let(:project) { create(:project, namespace: group, name: project_name) }
    let(:domain) { 'Example.com' }

    subject { project.pages_url }

    before do
      allow(Settings.pages).to receive(:host).and_return(domain)
      allow(Gitlab.config.pages).to receive(:url).and_return('http://example.com')
    end

    context 'group page' do
      let(:group_name) { 'Group' }
      let(:project_name) { 'group.example.com' }

      it { is_expected.to eq("http://group.example.com") }
    end

    context 'project page' do
      let(:group_name) { 'Group' }
      let(:project_name) { 'Project' }

      it { is_expected.to eq("http://group.example.com/project") }
    end
  end

  describe '#pages_group_url' do
    let(:group) { create(:group, name: group_name) }
    let(:project) { create(:project, namespace: group, name: project_name) }
    let(:domain) { 'Example.com' }
    let(:port) { 1234 }

    subject { project.pages_group_url }

    before do
      allow(Settings.pages).to receive(:host).and_return(domain)
      allow(Gitlab.config.pages).to receive(:url).and_return("http://example.com:#{port}")
    end

    context 'group page' do
      let(:group_name) { 'Group' }
      let(:project_name) { 'group.example.com' }

      it { is_expected.to eq("http://group.example.com:#{port}") }
    end

    context 'project page' do
      let(:group_name) { 'Group' }
      let(:project_name) { 'Project' }

      it { is_expected.to eq("http://group.example.com:#{port}") }
    end
  end

  describe '.search' do
    let(:project) { create(:project, description: 'kitten mittens') }

    it 'returns projects with a matching name' do
      expect(described_class.search(project.name)).to eq([project])
    end

    it 'returns projects with a partially matching name' do
      expect(described_class.search(project.name[0..2])).to eq([project])
    end

    it 'returns projects with a matching name regardless of the casing' do
      expect(described_class.search(project.name.upcase)).to eq([project])
    end

    it 'returns projects with a matching description' do
      expect(described_class.search(project.description)).to eq([project])
    end

    it 'returns projects with a partially matching description' do
      expect(described_class.search('kitten')).to eq([project])
    end

    it 'returns projects with a matching description regardless of the casing' do
      expect(described_class.search('KITTEN')).to eq([project])
    end

    it 'returns projects with a matching path' do
      expect(described_class.search(project.path)).to eq([project])
    end

    it 'returns projects with a partially matching path' do
      expect(described_class.search(project.path[0..2])).to eq([project])
    end

    it 'returns projects with a matching path regardless of the casing' do
      expect(described_class.search(project.path.upcase)).to eq([project])
    end

    describe 'with pending_delete project' do
      let(:pending_delete_project) { create(:project, pending_delete: true) }

      it 'shows pending deletion project' do
        search_result = described_class.search(pending_delete_project.name)

        expect(search_result).to eq([pending_delete_project])
      end
    end
  end

  describe '.optionally_search' do
    let(:project) { create(:project) }

    it 'searches for projects matching the query if one is given' do
      relation = described_class.optionally_search(project.name)

      expect(relation).to eq([project])
    end

    it 'returns the current relation if no search query is given' do
      relation = described_class.where(id: project.id)

      expect(relation.optionally_search).to eq(relation)
    end
  end

  describe '.paginate_in_descending_order_using_id' do
    let!(:project1) { create(:project) }
    let!(:project2) { create(:project) }

    it 'orders the relation in descending order' do
      expect(described_class.paginate_in_descending_order_using_id)
        .to eq([project2, project1])
    end

    it 'applies a limit to the relation' do
      expect(described_class.paginate_in_descending_order_using_id(limit: 1))
        .to eq([project2])
    end

    it 'limits projects by and ID when given' do
      expect(described_class.paginate_in_descending_order_using_id(before: project2.id))
        .to eq([project1])
    end
  end

  describe '.including_namespace_and_owner' do
    it 'eager loads the namespace and namespace owner' do
      create(:project)

      row = described_class.eager_load_namespace_and_owner.to_a.first
      recorder = ActiveRecord::QueryRecorder.new { row.namespace.owner }

      expect(recorder.count).to be_zero
    end
  end

  describe '#expire_caches_before_rename' do
    let(:project) { create(:project, :repository) }
    let(:repo)    { double(:repo, exists?: true) }
    let(:wiki)    { double(:wiki, exists?: true) }

    it 'expires the caches of the repository and wiki' do
      allow(Repository).to receive(:new)
        .with('foo', project)
        .and_return(repo)

      allow(Repository).to receive(:new)
        .with('foo.wiki', project)
        .and_return(wiki)

      expect(repo).to receive(:before_delete)
      expect(wiki).to receive(:before_delete)

      project.expire_caches_before_rename('foo')
    end
  end

  describe '.search_by_title' do
    let(:project) { create(:project, name: 'kittens') }

    it 'returns projects with a matching name' do
      expect(described_class.search_by_title(project.name)).to eq([project])
    end

    it 'returns projects with a partially matching name' do
      expect(described_class.search_by_title('kitten')).to eq([project])
    end

    it 'returns projects with a matching name regardless of the casing' do
      expect(described_class.search_by_title('KITTENS')).to eq([project])
    end
  end

  context 'when checking projects from groups' do
    let(:private_group)    { create(:group, visibility_level: 0)  }
    let(:internal_group)   { create(:group, visibility_level: 10) }

    let(:private_project)  { create(:project, :private, group: private_group) }
    let(:internal_project) { create(:project, :internal, group: internal_group) }

    context 'when group is private project can not be internal' do
      it { expect(private_project.visibility_level_allowed?(Gitlab::VisibilityLevel::INTERNAL)).to be_falsey }
    end

    context 'when group is internal project can not be public' do
      it { expect(internal_project.visibility_level_allowed?(Gitlab::VisibilityLevel::PUBLIC)).to be_falsey }
    end
  end

  describe '#track_project_repository' do
    shared_examples 'tracks storage location' do
      context 'when a project repository entry does not exist' do
        it 'creates a new entry' do
          expect { project.track_project_repository }.to change(project, :project_repository)
        end

        it 'tracks the project storage location' do
          project.track_project_repository

          expect(project.project_repository).to have_attributes(
            disk_path: project.disk_path,
            shard_name: project.repository_storage
          )
        end
      end

      context 'when a tracking entry exists' do
        let!(:project_repository) { create(:project_repository, project: project) }
        let!(:shard) { create(:shard, name: 'foo') }

        it 'does not create a new entry in the database' do
          expect { project.track_project_repository }.not_to change(project, :project_repository)
        end

        it 'updates the project storage location' do
          allow(project).to receive(:disk_path).and_return('fancy/new/path')
          allow(project).to receive(:repository_storage).and_return('foo')

          project.track_project_repository

          expect(project.project_repository).to have_attributes(
            disk_path: 'fancy/new/path',
            shard_name: 'foo'
          )
        end
      end
    end

    context 'with projects on legacy storage' do
      let(:project) { create(:project, :repository, :legacy_storage) }

      it_behaves_like 'tracks storage location'
    end

    context 'with projects on hashed storage' do
      let(:project) { create(:project, :repository) }

      it_behaves_like 'tracks storage location'
    end
  end

  describe '#create_repository' do
    let(:project) { create(:project, :repository) }
    let(:shell) { Gitlab::Shell.new }

    before do
      allow(project).to receive(:gitlab_shell).and_return(shell)
    end

    context 'using a regular repository' do
      it 'creates the repository' do
        expect(shell).to receive(:create_repository)
          .with(project.repository_storage, project.disk_path, project.full_path)
          .and_return(true)

        expect(project.repository).to receive(:after_create)

        expect(project.create_repository).to eq(true)
      end

      it 'adds an error if the repository could not be created' do
        expect(shell).to receive(:create_repository)
          .with(project.repository_storage, project.disk_path, project.full_path)
          .and_return(false)

        expect(project.repository).not_to receive(:after_create)

        expect(project.create_repository).to eq(false)
        expect(project.errors).not_to be_empty
      end
    end

    context 'using a forked repository' do
      it 'does nothing' do
        expect(project).to receive(:forked?).and_return(true)
        expect(shell).not_to receive(:create_repository)

        project.create_repository
      end
    end
  end

  describe '#ensure_repository' do
    let(:project) { create(:project, :repository) }
    let(:shell) { Gitlab::Shell.new }

    before do
      allow(project).to receive(:gitlab_shell).and_return(shell)
    end

    it 'creates the repository if it not exist' do
      allow(project).to receive(:repository_exists?)
        .and_return(false)

      allow(shell).to receive(:create_repository)
        .with(project.repository_storage, project.disk_path, project.full_path)
        .and_return(true)

      expect(project).to receive(:create_repository).with(force: true)

      project.ensure_repository
    end

    it 'does not create the repository if it exists' do
      allow(project).to receive(:repository_exists?)
        .and_return(true)

      expect(project).not_to receive(:create_repository)

      project.ensure_repository
    end

    it 'creates the repository if it is a fork' do
      expect(project).to receive(:forked?).and_return(true)

      allow(project).to receive(:repository_exists?)
        .and_return(false)

      expect(shell).to receive(:create_repository)
        .with(project.repository_storage, project.disk_path, project.full_path)
        .and_return(true)

      project.ensure_repository
    end
  end

  describe 'handling import URL' do
    it 'returns the sanitized URL' do
      project = create(:project, :import_started, import_url: 'http://user:pass@test.com')

      project.import_state.finish

      expect(project.reload.import_url).to eq('http://test.com')
    end
  end

  describe '#container_registry_url' do
    let(:project) { create(:project) }

    subject { project.container_registry_url }

    before do
      stub_container_registry_config(**registry_settings)
    end

    context 'for enabled registry' do
      let(:registry_settings) do
        { enabled: true,
          host_port: 'example.com' }
      end

      it { is_expected.not_to be_nil }
    end

    context 'for disabled registry' do
      let(:registry_settings) do
        { enabled: false }
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#has_container_registry_tags?' do
    let(:project) { create(:project) }

    context 'when container registry is enabled' do
      before do
        stub_container_registry_config(enabled: true)
      end

      context 'when tags are present for multi-level registries' do
        before do
          create(:container_repository, project: project, name: 'image')

          stub_container_registry_tags(repository: /image/,
                                       tags: %w[latest rc1])
        end

        it 'has image tags' do
          expect(project).to have_container_registry_tags
        end
      end

      context 'when tags are present for root repository' do
        before do
          stub_container_registry_tags(repository: project.full_path,
                                       tags: %w[latest rc1 pre1])
        end

        it 'has image tags' do
          expect(project).to have_container_registry_tags
        end
      end

      context 'when there are no tags at all' do
        before do
          stub_container_registry_tags(repository: :any, tags: [])
        end

        it 'does not have image tags' do
          expect(project).not_to have_container_registry_tags
        end
      end
    end

    context 'when container registry is disabled' do
      before do
        stub_container_registry_config(enabled: false)
      end

      it 'does not have image tags' do
        expect(project).not_to have_container_registry_tags
      end

      it 'does not check root repository tags' do
        expect(project).not_to receive(:full_path)
        expect(project).not_to have_container_registry_tags
      end

      it 'iterates through container repositories' do
        expect(project).to receive(:container_repositories)
        expect(project).not_to have_container_registry_tags
      end
    end
  end

  describe '#ci_config_path=' do
    let(:project) { create(:project) }

    it 'sets nil' do
      project.update!(ci_config_path: nil)

      expect(project.ci_config_path).to be_nil
    end

    it 'sets a string' do
      project.update!(ci_config_path: 'foo/.gitlab_ci.yml')

      expect(project.ci_config_path).to eq('foo/.gitlab_ci.yml')
    end

    it 'sets a string but removes all null characters' do
      project.update!(ci_config_path: "f\0oo/\0/.gitlab_ci.yml")

      expect(project.ci_config_path).to eq('foo//.gitlab_ci.yml')
    end
  end

  describe '#latest_successful_build_for' do
    let(:project) { create(:project, :repository) }
    let(:pipeline) { create_pipeline(project) }

    context 'with many builds' do
      it 'gives the latest builds from latest pipeline' do
        pipeline1 = create_pipeline(project)
        pipeline2 = create_pipeline(project)
        create_build(pipeline1, 'test')
        create_build(pipeline1, 'test2')
        build1_p2 = create_build(pipeline2, 'test')
        create_build(pipeline2, 'test2')

        expect(project.latest_successful_build_for(build1_p2.name))
          .to eq(build1_p2)
      end
    end

    context 'with succeeded pipeline' do
      let!(:build) { create_build }

      context 'standalone pipeline' do
        it 'returns builds for ref for default_branch' do
          expect(project.latest_successful_build_for(build.name))
            .to eq(build)
        end

        it 'returns empty relation if the build cannot be found' do
          expect(project.latest_successful_build_for('TAIL'))
            .to be_nil
        end
      end

      context 'with some pending pipeline' do
        before do
          create_build(create_pipeline(project, 'pending'))
        end

        it 'gives the latest build from latest pipeline' do
          expect(project.latest_successful_build_for(build.name))
            .to eq(build)
        end
      end
    end

    context 'with pending pipeline' do
      it 'returns empty relation' do
        pipeline.update(status: 'pending')
        pending_build = create_build(pipeline)

        expect(project.latest_successful_build_for(pending_build.name)).to be_nil
      end
    end
  end

  describe '#latest_successful_build_for!' do
    let(:project) { create(:project, :repository) }
    let(:pipeline) { create_pipeline(project) }

    context 'with many builds' do
      it 'gives the latest builds from latest pipeline' do
        pipeline1 = create_pipeline(project)
        pipeline2 = create_pipeline(project)
        create_build(pipeline1, 'test')
        create_build(pipeline1, 'test2')
        build1_p2 = create_build(pipeline2, 'test')
        create_build(pipeline2, 'test2')

        expect(project.latest_successful_build_for(build1_p2.name))
          .to eq(build1_p2)
      end
    end

    context 'with succeeded pipeline' do
      let!(:build) { create_build }

      context 'standalone pipeline' do
        it 'returns builds for ref for default_branch' do
          expect(project.latest_successful_build_for!(build.name))
            .to eq(build)
        end

        it 'returns exception if the build cannot be found' do
          expect { project.latest_successful_build_for!(build.name, 'TAIL') }
            .to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'with some pending pipeline' do
        before do
          create_build(create_pipeline(project, 'pending'))
        end

        it 'gives the latest build from latest pipeline' do
          expect(project.latest_successful_build_for!(build.name))
            .to eq(build)
        end
      end
    end

    context 'with pending pipeline' do
      it 'returns empty relation' do
        pipeline.update(status: 'pending')
        pending_build = create_build(pipeline)

        expect { project.latest_successful_build_for!(pending_build.name) }
          .to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#import_status' do
    context 'with import_state' do
      it 'returns the right status' do
        project = create(:project, :import_started)

        expect(project.import_status).to eq("started")
      end
    end

    context 'without import_state' do
      it 'returns none' do
        project = create(:project)

        expect(project.import_status).to eq('none')
      end
    end
  end

  describe '#human_import_status_name' do
    context 'with import_state' do
      it 'returns the right human import status' do
        project = create(:project, :import_started)

        expect(project.human_import_status_name).to eq('started')
      end
    end

    context 'without import_state' do
      it 'returns none' do
        project = create(:project)

        expect(project.human_import_status_name).to eq('none')
      end
    end
  end

  describe '#add_import_job' do
    let(:import_jid) { '123' }

    context 'forked' do
      let(:forked_from_project) { create(:project, :repository) }
      let(:project) { create(:project) }

      before do
        fork_project(forked_from_project, nil, target_project: project)
      end

      it 'schedules a RepositoryForkWorker job' do
        expect(RepositoryForkWorker).to receive(:perform_async).with(project.id).and_return(import_jid)

        expect(project.add_import_job).to eq(import_jid)
      end

      context 'without repository' do
        it 'schedules RepositoryImportWorker' do
          project = create(:project, import_url: generate(:url))

          expect(RepositoryImportWorker).to receive(:perform_async).with(project.id).and_return(import_jid)
          expect(project.add_import_job).to eq(import_jid)
        end
      end
    end

    context 'not forked' do
      it 'schedules a RepositoryImportWorker job' do
        project = create(:project, import_url: generate(:url))

        expect(RepositoryImportWorker).to receive(:perform_async).with(project.id).and_return(import_jid)
        expect(project.add_import_job).to eq(import_jid)
      end
    end
  end

  describe '#gitlab_project_import?' do
    subject(:project) { build(:project, import_type: 'gitlab_project') }

    it { expect(project.gitlab_project_import?).to be true }
  end

  describe '#gitea_import?' do
    subject(:project) { build(:project, import_type: 'gitea') }

    it { expect(project.gitea_import?).to be true }
  end

  describe '#has_remote_mirror?' do
    let(:project) { create(:project, :remote_mirror, :import_started) }
    subject { project.has_remote_mirror? }

    before do
      allow_any_instance_of(RemoteMirror).to receive(:refresh_remote)
    end

    it 'returns true when a remote mirror is enabled' do
      is_expected.to be_truthy
    end

    it 'returns false when remote mirror is disabled' do
      project.remote_mirrors.first.update(enabled: false)

      is_expected.to be_falsy
    end
  end

  describe '#update_remote_mirrors' do
    let(:project) { create(:project, :remote_mirror, :import_started) }
    delegate :update_remote_mirrors, to: :project

    before do
      allow_any_instance_of(RemoteMirror).to receive(:refresh_remote)
    end

    it 'syncs enabled remote mirror' do
      expect_any_instance_of(RemoteMirror).to receive(:sync)

      update_remote_mirrors
    end

    it 'does nothing when remote mirror is disabled globally and not overridden' do
      stub_application_setting(mirror_available: false)
      project.remote_mirror_available_overridden = false

      expect_any_instance_of(RemoteMirror).not_to receive(:sync)

      update_remote_mirrors
    end

    it 'does not sync disabled remote mirrors' do
      project.remote_mirrors.first.update(enabled: false)

      expect_any_instance_of(RemoteMirror).not_to receive(:sync)

      update_remote_mirrors
    end
  end

  describe '#remote_mirror_available?' do
    let(:project) { create(:project) }

    context 'when remote mirror global setting is enabled' do
      it 'returns true' do
        expect(project.remote_mirror_available?).to be(true)
      end
    end

    context 'when remote mirror global setting is disabled' do
      before do
        stub_application_setting(mirror_available: false)
      end

      it 'returns true when overridden' do
        project.remote_mirror_available_overridden = true

        expect(project.remote_mirror_available?).to be(true)
      end

      it 'returns false when not overridden' do
        expect(project.remote_mirror_available?).to be(false)
      end
    end
  end

  describe '#ancestors_upto', :nested_groups do
    let(:parent) { create(:group) }
    let(:child) { create(:group, parent: parent) }
    let(:child2) { create(:group, parent: child) }
    let(:project) { create(:project, namespace: child2) }

    it 'returns all ancestors when no namespace is given' do
      expect(project.ancestors_upto).to contain_exactly(child2, child, parent)
    end

    it 'includes ancestors upto but excluding the given ancestor' do
      expect(project.ancestors_upto(parent)).to contain_exactly(child2, child)
    end

    describe 'with hierarchy_order' do
      it 'returns ancestors ordered by descending hierarchy' do
        expect(project.ancestors_upto(hierarchy_order: :desc)).to eq([parent, child, child2])
      end

      it 'can be used with upto option' do
        expect(project.ancestors_upto(parent, hierarchy_order: :desc)).to eq([child, child2])
      end
    end
  end

  describe '#root_ancestor' do
    let(:project) { create(:project) }

    subject { project.root_ancestor }

    it { is_expected.to eq(project.namespace) }

    context 'in a group' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }

      it { is_expected.to eq(group) }
    end

    context 'in a nested group', :nested_groups do
      let(:root) { create(:group) }
      let(:child) { create(:group, parent: root) }
      let(:project) { create(:project, group: child) }

      it { is_expected.to eq(root) }
    end
  end

  describe '#lfs_enabled?' do
    let(:project) { create(:project) }

    shared_examples 'project overrides group' do
      it 'returns true when enabled in project' do
        project.update_attribute(:lfs_enabled, true)

        expect(project.lfs_enabled?).to be_truthy
      end

      it 'returns false when disabled in project' do
        project.update_attribute(:lfs_enabled, false)

        expect(project.lfs_enabled?).to be_falsey
      end

      it 'returns the value from the namespace, when no value is set in project' do
        expect(project.lfs_enabled?).to eq(project.namespace.lfs_enabled?)
      end
    end

    context 'LFS disabled in group' do
      before do
        project.namespace.update_attribute(:lfs_enabled, false)
        enable_lfs
      end

      it_behaves_like 'project overrides group'
    end

    context 'LFS enabled in group' do
      before do
        project.namespace.update_attribute(:lfs_enabled, true)
        enable_lfs
      end

      it_behaves_like 'project overrides group'
    end

    describe 'LFS disabled globally' do
      shared_examples 'it always returns false' do
        it do
          expect(project.lfs_enabled?).to be_falsey
          expect(project.namespace.lfs_enabled?).to be_falsey
        end
      end

      context 'when no values are set' do
        it_behaves_like 'it always returns false'
      end

      context 'when all values are set to true' do
        before do
          project.namespace.update_attribute(:lfs_enabled, true)
          project.update_attribute(:lfs_enabled, true)
        end

        it_behaves_like 'it always returns false'
      end
    end
  end

  describe '#daily_statistics_enabled?' do
    it { is_expected.to be_daily_statistics_enabled }

    context 'when :project_daily_statistics is disabled for the project' do
      before do
        stub_feature_flags(project_daily_statistics: { thing: subject, enabled: false })
      end

      it { is_expected.not_to be_daily_statistics_enabled }
    end
  end

  describe '#change_head' do
    let(:project) { create(:project, :repository) }

    it 'returns error if branch does not exist' do
      expect(project.change_head('unexisted-branch')).to be false
      expect(project.errors.size).to eq(1)
    end

    it 'calls the before_change_head and after_change_head methods' do
      expect(project.repository).to receive(:before_change_head)
      expect(project.repository).to receive(:after_change_head)

      project.change_head(project.default_branch)
    end

    it 'updates commit count' do
      expect(ProjectCacheWorker).to receive(:perform_async).with(project.id, [], [:commit_count])

      project.change_head(project.default_branch)
    end

    it 'copies the gitattributes' do
      expect(project.repository).to receive(:copy_gitattributes).with(project.default_branch)
      project.change_head(project.default_branch)
    end

    it 'reloads the default branch' do
      expect(project).to receive(:reload_default_branch)
      project.change_head(project.default_branch)
    end
  end

  context 'forks' do
    include ProjectForksHelper

    let(:project) { create(:project, :public) }
    let!(:forked_project) { fork_project(project) }

    describe '#fork_network' do
      it 'includes a fork of the project' do
        expect(project.fork_network.projects).to include(forked_project)
      end

      it 'includes a fork of a fork' do
        other_fork = fork_project(forked_project)

        expect(project.fork_network.projects).to include(other_fork)
      end

      it 'includes sibling forks' do
        other_fork = fork_project(project)

        expect(forked_project.fork_network.projects).to include(other_fork)
      end

      it 'includes the base project' do
        expect(forked_project.fork_network.projects).to include(project.reload)
      end
    end

    describe '#in_fork_network_of?' do
      it 'is true for a real fork' do
        expect(forked_project.in_fork_network_of?(project)).to be_truthy
      end

      it 'is true for a fork of a fork', :postgresql do
        other_fork = fork_project(forked_project)

        expect(other_fork.in_fork_network_of?(project)).to be_truthy
      end

      it 'is true for sibling forks' do
        sibling = fork_project(project)

        expect(sibling.in_fork_network_of?(forked_project)).to be_truthy
      end

      it 'is false when another project is given' do
        other_project = build_stubbed(:project)

        expect(forked_project.in_fork_network_of?(other_project)).to be_falsy
      end
    end

    describe '#fork_source' do
      let!(:second_fork) { fork_project(forked_project) }

      it 'returns the direct source if it exists' do
        expect(second_fork.fork_source).to eq(forked_project)
      end

      it 'returns the root of the fork network when the directs source was deleted' do
        forked_project.destroy

        expect(second_fork.fork_source).to eq(project)
      end

      it 'returns nil if it is the root of the fork network' do
        expect(project.fork_source).to be_nil
      end
    end

    describe '#forks' do
      it 'includes direct forks of the project' do
        expect(project.forks).to contain_exactly(forked_project)
      end
    end

    describe '#lfs_storage_project' do
      it 'returns self for non-forks' do
        expect(project.lfs_storage_project).to eq project
      end

      it 'returns the fork network root for forks' do
        second_fork = fork_project(forked_project)

        expect(second_fork.lfs_storage_project).to eq project
      end

      it 'returns self when fork_source is nil' do
        expect(forked_project).to receive(:fork_source).and_return(nil)

        expect(forked_project.lfs_storage_project).to eq forked_project
      end
    end

    describe '#all_lfs_objects' do
      let(:lfs_object) { create(:lfs_object) }

      before do
        project.lfs_objects << lfs_object
      end

      it 'returns the lfs object for a project' do
        expect(project.all_lfs_objects).to contain_exactly(lfs_object)
      end

      it 'returns the lfs object for a fork' do
        expect(forked_project.all_lfs_objects).to contain_exactly(lfs_object)
      end
    end
  end

  describe '#set_repository_read_only!' do
    let(:project) { create(:project) }

    it 'returns true when there is no existing git transfer in progress' do
      expect(project.set_repository_read_only!).to be_truthy
    end

    it 'returns false when there is an existing git transfer in progress' do
      allow(project).to receive(:git_transfer_in_progress?) { true }

      expect(project.set_repository_read_only!).to be_falsey
    end
  end

  describe '#set_repository_writable!' do
    it 'sets repository_read_only to false' do
      project = create(:project, :read_only)

      expect { project.set_repository_writable! }
        .to change(project, :repository_read_only)
        .from(true).to(false)
    end
  end

  describe '#pushes_since_gc' do
    let(:project) { create(:project) }

    after do
      project.reset_pushes_since_gc
    end

    context 'without any pushes' do
      it 'returns 0' do
        expect(project.pushes_since_gc).to eq(0)
      end
    end

    context 'with a number of pushes' do
      it 'returns the number of pushes' do
        3.times { project.increment_pushes_since_gc }

        expect(project.pushes_since_gc).to eq(3)
      end
    end
  end

  describe '#increment_pushes_since_gc' do
    let(:project) { create(:project) }

    after do
      project.reset_pushes_since_gc
    end

    it 'increments the number of pushes since the last GC' do
      3.times { project.increment_pushes_since_gc }

      expect(project.pushes_since_gc).to eq(3)
    end
  end

  describe '#reset_pushes_since_gc' do
    let(:project) { create(:project) }

    after do
      project.reset_pushes_since_gc
    end

    it 'resets the number of pushes since the last GC' do
      3.times { project.increment_pushes_since_gc }

      project.reset_pushes_since_gc

      expect(project.pushes_since_gc).to eq(0)
    end
  end

  describe '#deployment_variables' do
    context 'when project has no deployment service' do
      let(:project) { create(:project) }

      it 'returns an empty array' do
        expect(project.deployment_variables).to eq []
      end
    end

    context 'when project uses mock deployment service' do
      let(:project) { create(:mock_deployment_project) }

      it 'returns an empty array' do
        expect(project.deployment_variables).to eq []
      end
    end

    context 'when project has a deployment service' do
      shared_examples 'same behavior between KubernetesService and Platform::Kubernetes' do
        it 'returns variables from this service' do
          expect(project.deployment_variables).to include(
            { key: 'KUBE_TOKEN', value: project.deployment_platform.token, public: false, masked: true }
          )
        end
      end

      context 'when user configured kubernetes from Integration > Kubernetes' do
        let(:project) { create(:kubernetes_project) }

        it_behaves_like 'same behavior between KubernetesService and Platform::Kubernetes'
      end

      context 'when user configured kubernetes from CI/CD > Clusters and KubernetesNamespace migration has not been executed' do
        let!(:cluster) { create(:cluster, :project, :provided_by_gcp) }
        let(:project) { cluster.project }

        it_behaves_like 'same behavior between KubernetesService and Platform::Kubernetes'
      end

      context 'when user configured kubernetes from CI/CD > Clusters and KubernetesNamespace migration has been executed' do
        let!(:kubernetes_namespace) { create(:cluster_kubernetes_namespace, :with_token) }
        let!(:cluster) { kubernetes_namespace.cluster }
        let(:project) { kubernetes_namespace.project }

        it 'returns token from kubernetes namespace' do
          expect(project.deployment_variables).to include(
            { key: 'KUBE_TOKEN', value: kubernetes_namespace.service_account_token, public: false, masked: true }
          )
        end
      end
    end
  end

  describe '#default_environment' do
    let(:project) { create(:project) }

    it 'returns production environment when it exists' do
      production = create(:environment, name: "production", project: project)
      create(:environment, name: 'staging', project: project)

      expect(project.default_environment).to eq(production)
    end

    it 'returns first environment when no production environment exists' do
      create(:environment, name: 'staging', project: project)
      create(:environment, name: 'foo', project: project)

      expect(project.default_environment).to eq(project.environments.first)
    end

    it 'returns nil when no available environment exists' do
      expect(project.default_environment).to be_nil
    end
  end

  describe '#ci_variables_for' do
    let(:project) { create(:project) }

    let!(:ci_variable) do
      create(:ci_variable, value: 'secret', project: project)
    end

    let!(:protected_variable) do
      create(:ci_variable, :protected, value: 'protected', project: project)
    end

    subject { project.reload.ci_variables_for(ref: 'ref') }

    before do
      stub_application_setting(
        default_branch_protection: Gitlab::Access::PROTECTION_NONE)
    end

    shared_examples 'ref is protected' do
      it 'contains all the variables' do
        is_expected.to contain_exactly(ci_variable, protected_variable)
      end
    end

    context 'when the ref is not protected' do
      before do
        allow(project).to receive(:protected_for?).with('ref').and_return(false)
      end

      it 'contains only the CI variables' do
        is_expected.to contain_exactly(ci_variable)
      end
    end

    context 'when the ref is a protected branch' do
      before do
        allow(project).to receive(:protected_for?).with('ref').and_return(true)
      end

      it_behaves_like 'ref is protected'
    end

    context 'when the ref is a protected tag' do
      before do
        allow(project).to receive(:protected_for?).with('ref').and_return(true)
      end

      it_behaves_like 'ref is protected'
    end
  end

  describe '#any_lfs_file_locks?', :request_store do
    set(:project) { create(:project) }

    it 'returns false when there are no LFS file locks' do
      expect(project.any_lfs_file_locks?).to be_falsey
    end

    it 'returns a cached true when there are LFS file locks' do
      create(:lfs_file_lock, project: project)

      expect(project.lfs_file_locks).to receive(:any?).once.and_call_original

      2.times { expect(project.any_lfs_file_locks?).to be_truthy }
    end
  end

  describe '#protected_for?' do
    let(:project) { create(:project, :repository) }

    subject { project.protected_for?(ref) }

    shared_examples 'ref is not protected' do
      before do
        stub_application_setting(
          default_branch_protection: Gitlab::Access::PROTECTION_NONE)
      end

      it 'returns false' do
        is_expected.to be false
      end
    end

    shared_examples 'ref is protected branch' do
      before do
        create(:protected_branch, name: 'master', project: project)
      end

      it 'returns true' do
        is_expected.to be true
      end
    end

    shared_examples 'ref is protected tag' do
      before do
        create(:protected_tag, name: 'v1.0.0', project: project)
      end

      it 'returns true' do
        is_expected.to be true
      end
    end

    context 'when ref is nil' do
      let(:ref) { nil }

      it 'returns false' do
        is_expected.to be false
      end
    end

    context 'when ref is ref name' do
      context 'when ref is ambiguous' do
        let(:ref) { 'ref' }

        before do
          project.repository.add_branch(project.creator, 'ref', 'master')
          project.repository.add_tag(project.creator, 'ref', 'master')
        end

        it 'raises an error' do
          expect { subject }.to raise_error(Repository::AmbiguousRefError)
        end
      end

      context 'when the ref is not protected' do
        let(:ref) { 'master' }

        it_behaves_like 'ref is not protected'
      end

      context 'when the ref is a protected branch' do
        let(:ref) { 'master' }

        it_behaves_like 'ref is protected branch'
      end

      context 'when the ref is a protected tag' do
        let(:ref) { 'v1.0.0' }

        it_behaves_like 'ref is protected tag'
      end

      context 'when ref does not exist' do
        let(:ref) { 'something' }

        it 'returns false' do
          is_expected.to be false
        end
      end
    end

    context 'when ref is full ref' do
      context 'when the ref is not protected' do
        let(:ref) { 'refs/heads/master' }

        it_behaves_like 'ref is not protected'
      end

      context 'when the ref is a protected branch' do
        let(:ref) { 'refs/heads/master' }

        it_behaves_like 'ref is protected branch'
      end

      context 'when the ref is a protected tag' do
        let(:ref) { 'refs/tags/v1.0.0' }

        it_behaves_like 'ref is protected tag'
      end

      context 'when branch ref name is a full tag ref' do
        let(:ref) { 'refs/tags/something' }

        before do
          project.repository.add_branch(project.creator, ref, 'master')
        end

        context 'when ref is not protected' do
          it 'returns false' do
            is_expected.to be false
          end
        end

        context 'when ref is a protected branch' do
          before do
            create(:protected_branch, name: 'refs/tags/something', project: project)
          end

          it 'returns true' do
            is_expected.to be true
          end
        end
      end

      context 'when ref does not exist' do
        let(:ref) { 'refs/heads/something' }

        it 'returns false' do
          is_expected.to be false
        end
      end
    end
  end

  describe '#update_project_statistics' do
    let(:project) { create(:project) }

    it "is called after creation" do
      expect(project.statistics).to be_a ProjectStatistics
      expect(project.statistics).to be_persisted
    end

    it "copies the namespace_id" do
      expect(project.statistics.namespace_id).to eq project.namespace_id
    end

    it "updates the namespace_id when changed" do
      namespace = create(:namespace)
      project.update(namespace: namespace)

      expect(project.statistics.namespace_id).to eq namespace.id
    end
  end

  describe 'inside_path' do
    let!(:project1) { create(:project, namespace: create(:namespace, path: 'name_pace')) }
    let!(:project2) { create(:project) }
    let!(:project3) { create(:project, namespace: create(:namespace, path: 'namespace')) }
    let!(:path) { project1.namespace.full_path }

    it 'returns correct project' do
      expect(described_class.inside_path(path)).to eq([project1])
    end
  end

  describe '#route_map_for' do
    let(:project) { create(:project, :repository) }
    let(:route_map) do
      <<-MAP.strip_heredoc
      - source: /source/(.*)/
        public: '\\1'
      MAP
    end

    before do
      project.repository.create_file(User.last, '.gitlab/route-map.yml', route_map, message: 'Add .gitlab/route-map.yml', branch_name: 'master')
    end

    context 'when there is a .gitlab/route-map.yml at the commit' do
      context 'when the route map is valid' do
        it 'returns a route map' do
          map = project.route_map_for(project.commit.sha)
          expect(map).to be_a_kind_of(Gitlab::RouteMap)
        end
      end

      context 'when the route map is invalid' do
        let(:route_map) { 'INVALID' }

        it 'returns nil' do
          expect(project.route_map_for(project.commit.sha)).to be_nil
        end
      end
    end

    context 'when there is no .gitlab/route-map.yml at the commit' do
      it 'returns nil' do
        expect(project.route_map_for(project.commit.parent.sha)).to be_nil
      end
    end
  end

  describe '#public_path_for_source_path' do
    let(:project) { create(:project, :repository) }
    let(:route_map) do
      Gitlab::RouteMap.new(<<-MAP.strip_heredoc)
        - source: /source/(.*)/
          public: '\\1'
      MAP
    end
    let(:sha) { project.commit.id }

    context 'when there is a route map' do
      before do
        allow(project).to receive(:route_map_for).with(sha).and_return(route_map)
      end

      context 'when the source path is mapped' do
        it 'returns the public path' do
          expect(project.public_path_for_source_path('source/file.html', sha)).to eq('file.html')
        end
      end

      context 'when the source path is not mapped' do
        it 'returns nil' do
          expect(project.public_path_for_source_path('file.html', sha)).to be_nil
        end
      end
    end

    context 'when there is no route map' do
      before do
        allow(project).to receive(:route_map_for).with(sha).and_return(nil)
      end

      it 'returns nil' do
        expect(project.public_path_for_source_path('source/file.html', sha)).to be_nil
      end
    end
  end

  describe '#parent' do
    let(:project) { create(:project) }

    it { expect(project.parent).to eq(project.namespace) }
  end

  describe '#parent_id' do
    let(:project) { create(:project) }

    it { expect(project.parent_id).to eq(project.namespace_id) }
  end

  describe '#parent_changed?' do
    let(:project) { create(:project) }

    before do
      project.namespace_id = 7
    end

    it { expect(project.parent_changed?).to be_truthy }
  end

  def enable_lfs
    allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)
  end

  describe '#pages_url' do
    let(:group) { create(:group, name: 'Group') }
    let(:nested_group) { create(:group, parent: group) }
    let(:domain) { 'Example.com' }

    subject { project.pages_url }

    before do
      allow(Settings.pages).to receive(:host).and_return(domain)
      allow(Gitlab.config.pages).to receive(:url).and_return('http://example.com')
    end

    context 'top-level group' do
      let(:project) { create(:project, namespace: group, name: project_name) }

      context 'group page' do
        let(:project_name) { 'group.example.com' }

        it { is_expected.to eq("http://group.example.com") }
      end

      context 'project page' do
        let(:project_name) { 'Project' }

        it { is_expected.to eq("http://group.example.com/project") }
      end
    end

    context 'nested group' do
      let(:project) { create(:project, namespace: nested_group, name: project_name) }
      let(:expected_url) { "http://group.example.com/#{nested_group.path}/#{project.path}" }

      context 'group page' do
        let(:project_name) { 'group.example.com' }

        it { is_expected.to eq(expected_url) }
      end

      context 'project page' do
        let(:project_name) { 'Project' }

        it { is_expected.to eq(expected_url) }
      end
    end
  end

  describe '#http_url_to_repo' do
    let(:project) { create(:project) }

    it 'returns the url to the repo without a username' do
      expect(project.http_url_to_repo).to eq("#{project.web_url}.git")
      expect(project.http_url_to_repo).not_to include('@')
    end
  end

  describe '#lfs_http_url_to_repo' do
    let(:project) { create(:project) }

    it 'returns the url to the repo without a username' do
      lfs_http_url_to_repo = project.lfs_http_url_to_repo('operation_that_doesnt_matter')

      expect(lfs_http_url_to_repo).to eq("#{project.web_url}.git")
      expect(lfs_http_url_to_repo).not_to include('@')
    end
  end

  describe '#pipeline_status' do
    let(:project) { create(:project, :repository) }
    it 'builds a pipeline status' do
      expect(project.pipeline_status).to be_a(Gitlab::Cache::Ci::ProjectPipelineStatus)
    end

    it 'hase a loaded pipeline status' do
      expect(project.pipeline_status).to be_loaded
    end
  end

  describe '#append_or_update_attribute' do
    let(:project) { create(:project) }

    it 'shows full error updating an invalid MR' do
      error_message = 'Failed to replace merge_requests because one or more of the new records could not be saved.'\
        ' Validate fork Source project is not a fork of the target project'

      expect { project.append_or_update_attribute(:merge_requests, [create(:merge_request)]) }
        .to raise_error(ActiveRecord::RecordNotSaved, error_message)
    end

    it 'updates the project successfully' do
      merge_request = create(:merge_request, target_project: project, source_project: project)

      expect { project.append_or_update_attribute(:merge_requests, [merge_request]) }
        .not_to raise_error
    end
  end

  describe '#update' do
    let(:project) { create(:project) }

    it 'validates the visibility' do
      expect(project).to receive(:visibility_level_allowed_as_fork).and_call_original
      expect(project).to receive(:visibility_level_allowed_by_group).and_call_original

      project.update(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
    end

    it 'does not validate the visibility' do
      expect(project).not_to receive(:visibility_level_allowed_as_fork).and_call_original
      expect(project).not_to receive(:visibility_level_allowed_by_group).and_call_original

      project.update(updated_at: Time.now)
    end
  end

  describe '#last_repository_updated_at' do
    it 'sets to created_at upon creation' do
      project = create(:project, created_at: 2.hours.ago)

      expect(project.last_repository_updated_at.to_i).to eq(project.created_at.to_i)
    end
  end

  describe '.public_or_visible_to_user' do
    let!(:user) { create(:user) }

    let!(:private_project) do
      create(:project, :private, creator: user, namespace: user.namespace)
    end

    let!(:public_project) { create(:project, :public) }

    context 'with a user' do
      let(:projects) do
        described_class.all.public_or_visible_to_user(user)
      end

      it 'includes projects the user has access to' do
        expect(projects).to include(private_project)
      end

      it 'includes projects the user can see' do
        expect(projects).to include(public_project)
      end
    end

    context 'without a user' do
      it 'only includes public projects' do
        projects = described_class.all.public_or_visible_to_user

        expect(projects).to eq([public_project])
      end
    end
  end

  describe '.with_feature_available_for_user' do
    let!(:user) { create(:user) }
    let!(:feature) { MergeRequest }
    let!(:project) { create(:project, :public, :merge_requests_enabled) }

    subject { described_class.with_feature_available_for_user(feature, user) }

    context 'when user has access to project' do
      subject { described_class.with_feature_available_for_user(feature, user) }

      before do
        project.add_guest(user)
      end

      context 'when public project' do
        context 'when feature is public' do
          it 'returns project' do
            is_expected.to include(project)
          end
        end

        context 'when feature is private' do
          let!(:project) { create(:project, :public, :merge_requests_private) }

          it 'returns project when user has access to the feature' do
            project.add_maintainer(user)

            is_expected.to include(project)
          end

          it 'does not return project when user does not have the minimum access level required' do
            is_expected.not_to include(project)
          end
        end
      end

      context 'when private project' do
        let!(:project) { create(:project) }

        it 'returns project when user has access to the feature' do
          project.add_maintainer(user)

          is_expected.to include(project)
        end

        it 'does not return project when user does not have the minimum access level required' do
          is_expected.not_to include(project)
        end
      end
    end

    context 'when user does not have access to project' do
      let!(:project) { create(:project) }

      it 'does not return project when user cant access project' do
        is_expected.not_to include(project)
      end
    end
  end

  describe '#pages_available?' do
    let(:project) { create(:project, group: group) }

    subject { project.pages_available? }

    before do
      allow(Gitlab.config.pages).to receive(:enabled).and_return(true)
    end

    context 'when the project is in a top level namespace' do
      let(:group) { create(:group) }

      it { is_expected.to be(true) }
    end

    context 'when the project is in a subgroup' do
      let(:group) { create(:group, :nested) }

      it { is_expected.to be(true) }
    end
  end

  describe '#remove_private_deploy_keys' do
    let!(:project) { create(:project) }

    context 'for a private deploy key' do
      let!(:key) { create(:deploy_key, public: false) }
      let!(:deploy_keys_project) { create(:deploy_keys_project, deploy_key: key, project: project) }

      context 'when the key is not linked to another project' do
        it 'removes the key' do
          project.remove_private_deploy_keys

          expect(project.deploy_keys).not_to include(key)
        end
      end

      context 'when the key is linked to another project' do
        before do
          another_project = create(:project)
          create(:deploy_keys_project, deploy_key: key, project: another_project)
        end

        it 'does not remove the key' do
          project.remove_private_deploy_keys

          expect(project.deploy_keys).to include(key)
        end
      end
    end

    context 'for a public deploy key' do
      let!(:key) { create(:deploy_key, public: true) }
      let!(:deploy_keys_project) { create(:deploy_keys_project, deploy_key: key, project: project) }

      it 'does not remove the key' do
        project.remove_private_deploy_keys

        expect(project.deploy_keys).to include(key)
      end
    end
  end

  describe '#remove_pages' do
    let(:project) { create(:project) }
    let(:namespace) { project.namespace }
    let(:pages_path) { project.pages_path }

    around do |example|
      FileUtils.mkdir_p(pages_path)
      begin
        example.run
      ensure
        FileUtils.rm_rf(pages_path)
      end
    end

    it 'removes the pages directory' do
      expect_any_instance_of(Projects::UpdatePagesConfigurationService).to receive(:execute)
      expect_any_instance_of(Gitlab::PagesTransfer).to receive(:rename_project).and_return(true)
      expect(PagesWorker).to receive(:perform_in).with(5.minutes, :remove, namespace.full_path, anything)

      project.remove_pages
    end

    it 'is a no-op when there is no namespace' do
      project.namespace.delete
      project.reload

      expect_any_instance_of(Projects::UpdatePagesConfigurationService).not_to receive(:execute)
      expect_any_instance_of(Gitlab::PagesTransfer).not_to receive(:rename_project)

      project.remove_pages
    end

    it 'is run when the project is destroyed' do
      expect(project).to receive(:remove_pages).and_call_original

      project.destroy
    end
  end

  describe '#remove_export' do
    let(:project) { create(:project, :with_export) }

    it 'removes the export' do
      project.remove_exports

      expect(project.export_file_exists?).to be_falsey
    end
  end

  describe '#forks_count' do
    it 'returns the number of forks' do
      project = build(:project)

      expect_any_instance_of(Projects::ForksCountService).to receive(:count).and_return(1)

      expect(project.forks_count).to eq(1)
    end
  end

  describe '#git_transfer_in_progress?' do
    let(:project) { build(:project) }

    subject { project.git_transfer_in_progress? }

    it 'returns false when repo_reference_count and wiki_reference_count are 0' do
      allow(project).to receive(:repo_reference_count) { 0 }
      allow(project).to receive(:wiki_reference_count) { 0 }

      expect(subject).to be_falsey
    end

    it 'returns true when repo_reference_count is > 0' do
      allow(project).to receive(:repo_reference_count) { 2 }
      allow(project).to receive(:wiki_reference_count) { 0 }

      expect(subject).to be_truthy
    end

    it 'returns true when wiki_reference_count is > 0' do
      allow(project).to receive(:repo_reference_count) { 0 }
      allow(project).to receive(:wiki_reference_count) { 2 }

      expect(subject).to be_truthy
    end
  end

  context 'legacy storage' do
    set(:project) { create(:project, :repository, :legacy_storage) }
    let(:gitlab_shell) { Gitlab::Shell.new }
    let(:project_storage) { project.send(:storage) }

    before do
      allow(project).to receive(:gitlab_shell).and_return(gitlab_shell)
    end

    describe '#base_dir' do
      it 'returns base_dir based on namespace only' do
        expect(project.base_dir).to eq(project.namespace.full_path)
      end
    end

    describe '#disk_path' do
      it 'returns disk_path based on namespace and project path' do
        expect(project.disk_path).to eq("#{project.namespace.full_path}/#{project.path}")
      end
    end

    describe '#ensure_storage_path_exists' do
      it 'delegates to gitlab_shell to ensure namespace is created' do
        expect(gitlab_shell).to receive(:add_namespace).with(project.repository_storage, project.base_dir)

        project.ensure_storage_path_exists
      end
    end

    describe '#legacy_storage?' do
      it 'returns true when storage_version is nil' do
        project = build(:project, storage_version: nil)

        expect(project.legacy_storage?).to be_truthy
      end

      it 'returns true when the storage_version is 0' do
        project = build(:project, storage_version: 0)

        expect(project.legacy_storage?).to be_truthy
      end
    end

    describe '#hashed_storage?' do
      it 'returns false' do
        expect(project.hashed_storage?(:repository)).to be_falsey
      end
    end

    describe '#pages_path' do
      it 'returns a path where pages are stored' do
        expect(project.pages_path).to eq(File.join(Settings.pages.path, project.namespace.full_path, project.path))
      end
    end

    describe '#migrate_to_hashed_storage!' do
      let(:project) { create(:project, :empty_repo, :legacy_storage) }

      it 'returns true' do
        expect(project.migrate_to_hashed_storage!).to be_truthy
      end

      it 'does not run validation' do
        expect(project).not_to receive(:valid?)

        project.migrate_to_hashed_storage!
      end

      it 'schedules HashedStorage::ProjectMigrateWorker with delayed start when the project repo is in use' do
        Gitlab::ReferenceCounter.new(Gitlab::GlRepository::PROJECT.identifier_for_subject(project)).increase

        expect(HashedStorage::ProjectMigrateWorker).to receive(:perform_in)

        project.migrate_to_hashed_storage!
      end

      it 'schedules HashedStorage::ProjectMigrateWorker with delayed start when the wiki repo is in use' do
        Gitlab::ReferenceCounter.new(Gitlab::GlRepository::WIKI.identifier_for_subject(project)).increase

        expect(HashedStorage::ProjectMigrateWorker).to receive(:perform_in)

        project.migrate_to_hashed_storage!
      end

      it 'schedules HashedStorage::ProjectMigrateWorker' do
        expect(HashedStorage::ProjectMigrateWorker).to receive(:perform_async).with(project.id)

        project.migrate_to_hashed_storage!
      end
    end

    describe '#rollback_to_legacy_storage!' do
      let(:project) { create(:project, :empty_repo, :legacy_storage) }

      it 'returns nil' do
        expect(project.rollback_to_legacy_storage!).to be_nil
      end

      it 'does not run validations' do
        expect(project).not_to receive(:valid?)

        project.rollback_to_legacy_storage!
      end
    end
  end

  context 'hashed storage' do
    set(:project) { create(:project, :repository, skip_disk_validation: true) }
    let(:gitlab_shell) { Gitlab::Shell.new }
    let(:hash) { Digest::SHA2.hexdigest(project.id.to_s) }
    let(:hashed_prefix) { File.join('@hashed', hash[0..1], hash[2..3]) }
    let(:hashed_path) { File.join(hashed_prefix, hash) }

    before do
      stub_application_setting(hashed_storage_enabled: true)
    end

    describe '#legacy_storage?' do
      it 'returns false' do
        expect(project.legacy_storage?).to be_falsey
      end
    end

    describe '#hashed_storage?' do
      it 'returns true if rolled out' do
        expect(project.hashed_storage?(:attachments)).to be_truthy
      end

      it 'returns false when not rolled out yet' do
        project.storage_version = 1

        expect(project.hashed_storage?(:attachments)).to be_falsey
      end
    end

    describe '#base_dir' do
      it 'returns base_dir based on hash of project id' do
        expect(project.base_dir).to eq(hashed_prefix)
      end
    end

    describe '#disk_path' do
      it 'returns disk_path based on hash of project id' do
        expect(project.disk_path).to eq(hashed_path)
      end
    end

    describe '#ensure_storage_path_exists' do
      it 'delegates to gitlab_shell to ensure namespace is created' do
        allow(project).to receive(:gitlab_shell).and_return(gitlab_shell)

        expect(gitlab_shell).to receive(:add_namespace).with(project.repository_storage, hashed_prefix)

        project.ensure_storage_path_exists
      end
    end

    describe '#pages_path' do
      it 'returns a path where pages are stored' do
        expect(project.pages_path).to eq(File.join(Settings.pages.path, project.namespace.full_path, project.path))
      end
    end

    describe '#migrate_to_hashed_storage!' do
      let(:project) { create(:project, :repository, skip_disk_validation: true) }

      it 'returns nil' do
        expect(project.migrate_to_hashed_storage!).to be_nil
      end

      it 'does not flag as read-only' do
        expect { project.migrate_to_hashed_storage! }.not_to change { project.repository_read_only }
      end

      context 'when partially migrated' do
        it 'enqueues a job' do
          project = create(:project, storage_version: 1, skip_disk_validation: true)

          Sidekiq::Testing.fake! do
            expect { project.migrate_to_hashed_storage! }.to change(HashedStorage::ProjectMigrateWorker.jobs, :size).by(1)
          end
        end
      end
    end

    describe '#rollback_to_legacy_storage!' do
      let(:project) { create(:project, :repository, skip_disk_validation: true) }

      it 'returns true' do
        expect(project.rollback_to_legacy_storage!).to be_truthy
      end

      it 'does not run validations' do
        expect(project).not_to receive(:valid?)

        project.rollback_to_legacy_storage!
      end

      it 'does not flag as read-only' do
        expect { project.rollback_to_legacy_storage! }.not_to change { project.repository_read_only }
      end

      it 'enqueues a job' do
        Sidekiq::Testing.fake! do
          expect { project.rollback_to_legacy_storage! }.to change(HashedStorage::ProjectRollbackWorker.jobs, :size).by(1)
        end
      end
    end
  end

  describe '#has_ci?' do
    set(:project) { create(:project) }
    let(:repository) { double }

    before do
      expect(project).to receive(:repository) { repository }
    end

    context 'when has .gitlab-ci.yml' do
      before do
        expect(repository).to receive(:gitlab_ci_yml) { 'content' }
      end

      it "CI is available" do
        expect(project).to have_ci
      end
    end

    context 'when there is no .gitlab-ci.yml' do
      before do
        expect(repository).to receive(:gitlab_ci_yml) { nil }
      end

      it "CI is available" do
        expect(project).to have_ci
      end

      context 'when auto devops is disabled' do
        before do
          stub_application_setting(auto_devops_enabled: false)
        end

        it "CI is not available" do
          expect(project).not_to have_ci
        end
      end
    end
  end

  describe '#auto_devops_enabled?' do
    before do
      allow(Feature).to receive(:enabled?).and_call_original
      Feature.get(:force_autodevops_on_by_default).enable_percentage_of_actors(0)
    end

    set(:project) { create(:project) }

    subject { project.auto_devops_enabled? }

    context 'when explicitly enabled' do
      before do
        create(:project_auto_devops, project: project)
      end

      it { is_expected.to be_truthy }
    end

    context 'when explicitly disabled' do
      before do
        create(:project_auto_devops, project: project, enabled: false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when enabled in settings' do
      before do
        stub_application_setting(auto_devops_enabled: true)
      end

      it { is_expected.to be_truthy }
    end

    context 'when disabled in settings' do
      before do
        stub_application_setting(auto_devops_enabled: false)
      end

      it { is_expected.to be_falsey }

      context 'when explicitly enabled' do
        before do
          create(:project_auto_devops, project: project)
        end

        it { is_expected.to be_truthy }
      end

      context 'when explicitly disabled' do
        before do
          create(:project_auto_devops, :disabled, project: project)
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when force_autodevops_on_by_default is enabled for the project' do
      it { is_expected.to be_truthy }
    end

    context 'with group parents' do
      let(:instance_enabled) { true }

      before do
        stub_application_setting(auto_devops_enabled: instance_enabled)
        project.update!(namespace: parent_group)
      end

      context 'when enabled on parent' do
        let(:parent_group) { create(:group, :auto_devops_enabled) }

        context 'when auto devops instance enabled' do
          it { is_expected.to be_truthy }
        end

        context 'when auto devops instance disabled' do
          let(:instance_disabled) { false }

          it { is_expected.to be_truthy }
        end
      end

      context 'when disabled on parent' do
        let(:parent_group) { create(:group, :auto_devops_disabled) }

        context 'when auto devops instance enabled' do
          it { is_expected.to be_falsy }
        end

        context 'when auto devops instance disabled' do
          let(:instance_disabled) { false }

          it { is_expected.to be_falsy }
        end
      end

      context 'when enabled on root parent', :nested_groups do
        let(:parent_group) { create(:group, parent: create(:group, :auto_devops_enabled)) }

        context 'when auto devops instance enabled' do
          it { is_expected.to be_truthy }
        end

        context 'when auto devops instance disabled' do
          let(:instance_disabled) { false }

          it { is_expected.to be_truthy }
        end

        context 'when explicitly disabled on parent' do
          let(:parent_group) { create(:group, :auto_devops_disabled, parent: create(:group, :auto_devops_enabled)) }

          it { is_expected.to be_falsy }
        end
      end

      context 'when disabled on root parent', :nested_groups do
        let(:parent_group) { create(:group, parent: create(:group, :auto_devops_disabled)) }

        context 'when auto devops instance enabled' do
          it { is_expected.to be_falsy }
        end

        context 'when auto devops instance disabled' do
          let(:instance_disabled) { false }

          it { is_expected.to be_falsy }
        end

        context 'when explicitly disabled on parent' do
          let(:parent_group) { create(:group, :auto_devops_disabled, parent: create(:group, :auto_devops_enabled)) }

          it { is_expected.to be_falsy }
        end
      end
    end
  end

  describe '#has_auto_devops_implicitly_enabled?' do
    set(:project) { create(:project) }

    context 'when disabled in settings' do
      before do
        stub_application_setting(auto_devops_enabled: false)
      end

      it 'does not have auto devops implicitly disabled' do
        expect(project).not_to have_auto_devops_implicitly_enabled
      end
    end

    context 'when enabled in settings' do
      before do
        stub_application_setting(auto_devops_enabled: true)
      end

      it 'auto devops is implicitly disabled' do
        expect(project).to have_auto_devops_implicitly_enabled
      end

      context 'when explicitly disabled' do
        before do
          create(:project_auto_devops, project: project, enabled: false)
        end

        it 'does not have auto devops implicitly disabled' do
          expect(project).not_to have_auto_devops_implicitly_enabled
        end
      end

      context 'when explicitly enabled' do
        before do
          create(:project_auto_devops, project: project, enabled: true)
        end

        it 'does not have auto devops implicitly disabled' do
          expect(project).not_to have_auto_devops_implicitly_enabled
        end
      end
    end

    context 'when enabled on group' do
      it 'has auto devops implicitly enabled' do
        project.update(namespace: create(:group, :auto_devops_enabled))

        expect(project).to have_auto_devops_implicitly_enabled
      end
    end

    context 'when enabled on parent group' do
      it 'has auto devops implicitly enabled' do
        subgroup = create(:group, parent: create(:group, :auto_devops_enabled))
        project.update(namespace: subgroup)

        expect(project).to have_auto_devops_implicitly_enabled
      end
    end
  end

  describe '#has_auto_devops_implicitly_disabled?' do
    set(:project) { create(:project) }

    before do
      allow(Feature).to receive(:enabled?).and_call_original
      Feature.get(:force_autodevops_on_by_default).enable_percentage_of_actors(0)
    end

    context 'when explicitly disabled' do
      before do
        create(:project_auto_devops, project: project, enabled: false)
      end

      it 'does not have auto devops implicitly disabled' do
        expect(project).not_to have_auto_devops_implicitly_disabled
      end
    end

    context 'when explicitly enabled' do
      before do
        create(:project_auto_devops, project: project, enabled: true)
      end

      it 'does not have auto devops implicitly disabled' do
        expect(project).not_to have_auto_devops_implicitly_disabled
      end
    end

    context 'when enabled in settings' do
      before do
        stub_application_setting(auto_devops_enabled: true)
      end

      it 'does not have auto devops implicitly disabled' do
        expect(project).not_to have_auto_devops_implicitly_disabled
      end
    end

    context 'when disabled in settings' do
      before do
        stub_application_setting(auto_devops_enabled: false)
      end

      it 'auto devops is implicitly disabled' do
        expect(project).to have_auto_devops_implicitly_disabled
      end

      context 'when force_autodevops_on_by_default is enabled for the project' do
        before do
          create(:project_auto_devops, project: project, enabled: false)

          Feature.get(:force_autodevops_on_by_default).enable_percentage_of_actors(100)
        end

        it 'does not have auto devops implicitly disabled' do
          expect(project).not_to have_auto_devops_implicitly_disabled
        end
      end

      context 'when disabled on group' do
        it 'has auto devops implicitly disabled' do
          project.update!(namespace: create(:group, :auto_devops_disabled))

          expect(project).to have_auto_devops_implicitly_disabled
        end
      end

      context 'when disabled on parent group' do
        it 'has auto devops implicitly disabled' do
          subgroup = create(:group, parent: create(:group, :auto_devops_disabled))
          project.update!(namespace: subgroup)

          expect(project).to have_auto_devops_implicitly_disabled
        end
      end
    end
  end

  describe '#api_variables' do
    set(:project) { create(:project) }

    it 'exposes API v4 URL' do
      expect(project.api_variables.first[:key]).to eq 'CI_API_V4_URL'
      expect(project.api_variables.first[:value]).to include '/api/v4'
    end

    it 'contains a URL variable for every supported API version' do
      # Ensure future API versions have proper variables defined. We're not doing this for v3.
      supported_versions = API::API.versions - ['v3']
      supported_versions = supported_versions.select do |version|
        API::API.routes.select { |route| route.version == version }.many?
      end

      required_variables = supported_versions.map do |version|
        "CI_API_#{version.upcase}_URL"
      end

      expect(project.api_variables.map { |variable| variable[:key] })
        .to contain_exactly(*required_variables)
    end
  end

  describe '#auto_devops_variables' do
    set(:project) { create(:project) }

    subject { project.auto_devops_variables }

    context 'when enabled in instance settings' do
      before do
        stub_application_setting(auto_devops_enabled: true)
      end

      context 'when domain is empty' do
        before do
          stub_application_setting(auto_devops_domain: nil)
        end

        it 'variables does not include AUTO_DEVOPS_DOMAIN' do
          is_expected.not_to include(domain_variable)
        end
      end

      context 'when domain is configured' do
        before do
          stub_application_setting(auto_devops_domain: 'example.com')
        end

        it 'variables includes AUTO_DEVOPS_DOMAIN' do
          is_expected.to include(domain_variable)
        end
      end
    end

    context 'when explicitly enabled' do
      context 'when domain is empty' do
        before do
          create(:project_auto_devops, project: project, domain: nil)
        end

        it 'variables does not include AUTO_DEVOPS_DOMAIN' do
          is_expected.not_to include(domain_variable)
        end
      end

      context 'when domain is configured' do
        before do
          create(:project_auto_devops, project: project, domain: 'example.com')
        end

        it 'variables includes AUTO_DEVOPS_DOMAIN' do
          is_expected.to include(domain_variable)
        end
      end
    end

    def domain_variable
      { key: 'AUTO_DEVOPS_DOMAIN', value: 'example.com', public: true }
    end
  end

  describe '#latest_successful_builds_for' do
    let(:project) { build(:project) }

    before do
      allow(project).to receive(:default_branch).and_return('master')
    end

    context 'without a ref' do
      it 'returns a pipeline for the default branch' do
        expect(project)
          .to receive(:latest_successful_pipeline_for_default_branch)

        project.latest_successful_pipeline_for
      end
    end

    context 'with the ref set to the default branch' do
      it 'returns a pipeline for the default branch' do
        expect(project)
          .to receive(:latest_successful_pipeline_for_default_branch)

        project.latest_successful_pipeline_for(project.default_branch)
      end
    end

    context 'with a ref that is not the default branch' do
      it 'returns the latest successful pipeline for the given ref' do
        expect(project.ci_pipelines).to receive(:latest_successful_for).with('foo')

        project.latest_successful_pipeline_for('foo')
      end
    end
  end

  describe '#check_repository_path_availability' do
    let(:project) { build(:project) }

    it 'skips gitlab-shell exists?' do
      project.skip_disk_validation = true

      expect(project.gitlab_shell).not_to receive(:exists?)
      expect(project.check_repository_path_availability).to be_truthy
    end
  end

  describe '#latest_successful_pipeline_for_default_branch' do
    let(:project) { build(:project) }

    before do
      allow(project).to receive(:default_branch).and_return('master')
    end

    it 'memoizes and returns the latest successful pipeline for the default branch' do
      pipeline = double(:pipeline)

      expect(project.ci_pipelines).to receive(:latest_successful_for)
        .with(project.default_branch)
        .and_return(pipeline)
        .once

      2.times do
        expect(project.latest_successful_pipeline_for_default_branch)
          .to eq(pipeline)
      end
    end
  end

  describe '#after_import' do
    let(:project) { create(:project) }
    let(:import_state) { create(:import_state, project: project) }

    it 'runs the correct hooks' do
      expect(project.repository).to receive(:after_import)
      expect(project.wiki.repository).to receive(:after_import)
      expect(import_state).to receive(:finish)
      expect(project).to receive(:update_project_counter_caches)
      expect(import_state).to receive(:remove_jid)
      expect(project).to receive(:after_create_default_branch)
      expect(project).to receive(:refresh_markdown_cache!)
      expect(InternalId).to receive(:flush_records!).with(project: project)

      project.after_import
    end

    context 'branch protection' do
      let(:project) { create(:project, :repository) }

      before do
        create(:import_state, :started, project: project)
      end

      it 'does not protect when branch protection is disabled' do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_NONE)

        project.after_import

        expect(project.protected_branches).to be_empty
      end

      it "gives developer access to push when branch protection is set to 'developers can push'" do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_DEV_CAN_PUSH)

        project.after_import

        expect(project.protected_branches).not_to be_empty
        expect(project.default_branch).to eq(project.protected_branches.first.name)
        expect(project.protected_branches.first.push_access_levels.map(&:access_level)).to eq([Gitlab::Access::DEVELOPER])
      end

      it "gives developer access to merge when branch protection is set to 'developers can merge'" do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_DEV_CAN_MERGE)

        project.after_import

        expect(project.protected_branches).not_to be_empty
        expect(project.default_branch).to eq(project.protected_branches.first.name)
        expect(project.protected_branches.first.merge_access_levels.map(&:access_level)).to eq([Gitlab::Access::DEVELOPER])
      end

      it 'protects default branch' do
        project.after_import

        expect(project.protected_branches).not_to be_empty
        expect(project.default_branch).to eq(project.protected_branches.first.name)
        expect(project.protected_branches.first.push_access_levels.map(&:access_level)).to eq([Gitlab::Access::MAINTAINER])
        expect(project.protected_branches.first.merge_access_levels.map(&:access_level)).to eq([Gitlab::Access::MAINTAINER])
      end
    end
  end

  describe '#update_project_counter_caches' do
    let(:project) { create(:project) }

    it 'updates all project counter caches' do
      expect_any_instance_of(Projects::OpenIssuesCountService)
        .to receive(:refresh_cache)
        .and_call_original

      expect_any_instance_of(Projects::OpenMergeRequestsCountService)
        .to receive(:refresh_cache)
        .and_call_original

      project.update_project_counter_caches
    end
  end

  describe '#wiki_repository_exists?' do
    it 'returns true when the wiki repository exists' do
      project = create(:project, :wiki_repo)

      expect(project.wiki_repository_exists?).to eq(true)
    end

    it 'returns false when the wiki repository does not exist' do
      project = create(:project)

      expect(project.wiki_repository_exists?).to eq(false)
    end
  end

  describe '#write_repository_config' do
    set(:project) { create(:project, :repository) }

    it 'writes full path in .git/config when key is missing' do
      project.write_repository_config

      expect(rugged_config['gitlab.fullpath']).to eq project.full_path
    end

    it 'updates full path in .git/config when key is present' do
      project.write_repository_config(gl_full_path: 'old/path')

      expect { project.write_repository_config }.to change { rugged_config['gitlab.fullpath'] }.from('old/path').to(project.full_path)
    end

    it 'does not raise an error with an empty repository' do
      project = create(:project_empty_repo)

      expect { project.write_repository_config }.not_to raise_error
    end
  end

  describe '#execute_hooks' do
    let(:data) { { ref: 'refs/heads/master', data: 'data' } }
    it 'executes active projects hooks with the specified scope' do
      hook = create(:project_hook, merge_requests_events: false, push_events: true)
      expect(ProjectHook).to receive(:select_active)
        .with(:push_hooks, data)
        .and_return([hook])
      project = create(:project, hooks: [hook])

      expect_any_instance_of(ProjectHook).to receive(:async_execute).once

      project.execute_hooks(data, :push_hooks)
    end

    it 'does not execute project hooks that dont match the specified scope' do
      hook = create(:project_hook, merge_requests_events: true, push_events: false)
      project = create(:project, hooks: [hook])

      expect_any_instance_of(ProjectHook).not_to receive(:async_execute).once

      project.execute_hooks(data, :push_hooks)
    end

    it 'does not execute project hooks which are not active' do
      hook = create(:project_hook, push_events: true)
      expect(ProjectHook).to receive(:select_active)
        .with(:push_hooks, data)
        .and_return([])
      project = create(:project, hooks: [hook])

      expect_any_instance_of(ProjectHook).not_to receive(:async_execute).once

      project.execute_hooks(data, :push_hooks)
    end

    it 'executes the system hooks with the specified scope' do
      expect_any_instance_of(SystemHooksService).to receive(:execute_hooks).with(data, :merge_request_hooks)

      project = build(:project)
      project.execute_hooks(data, :merge_request_hooks)
    end

    it 'executes the system hooks when inside a transaction' do
      allow_any_instance_of(WebHookService).to receive(:execute)

      create(:system_hook, merge_requests_events: true)

      project = build(:project)

      # Ideally, we'd test that `WebHookWorker.jobs.size` increased by 1,
      # but since the entire spec run takes place in a transaction, we never
      # actually get to the `after_commit` hook that queues these jobs.
      expect do
        project.transaction do
          project.execute_hooks(data, :merge_request_hooks)
        end
      end.not_to raise_error # Sidekiq::Worker::EnqueueFromTransactionError
    end
  end

  describe '#badges' do
    let(:project_group) { create(:group) }
    let(:project) { create(:project, path: 'avatar', namespace: project_group) }

    before do
      create_list(:project_badge, 2, project: project)
      create(:group_badge, group: project_group)
    end

    it 'returns the project and the project group badges' do
      create(:group_badge, group: create(:group))

      expect(Badge.count).to eq 4
      expect(project.badges.count).to eq 3
    end

    if Group.supports_nested_objects?
      context 'with nested_groups' do
        let(:parent_group) { create(:group) }

        before do
          create_list(:group_badge, 2, group: project_group)
          project_group.update(parent: parent_group)
        end

        it 'returns the project and the project nested groups badges' do
          expect(project.badges.count).to eq 5
        end
      end
    end
  end

  context 'with cross project merge requests' do
    let(:user) { create(:user) }
    let(:target_project) { create(:project, :repository) }
    let(:project) { fork_project(target_project, nil, repository: true) }
    let!(:local_merge_request) do
      create(
        :merge_request,
        target_project: project,
        target_branch: 'target-branch',
        source_project: project,
        source_branch: 'awesome-feature-1',
        allow_collaboration: true
      )
    end
    let!(:merge_request) do
      create(
        :merge_request,
        target_project: target_project,
        target_branch: 'target-branch',
        source_project: project,
        source_branch: 'awesome-feature-1',
        allow_collaboration: true
      )
    end

    before do
      target_project.add_developer(user)
    end

    describe '#merge_requests_allowing_push_to_user' do
      it 'returns open merge requests for which the user has developer access to the target project' do
        expect(project.merge_requests_allowing_push_to_user(user)).to include(merge_request)
      end

      it 'does not include closed merge requests' do
        merge_request.close

        expect(project.merge_requests_allowing_push_to_user(user)).to be_empty
      end

      it 'does not include merge requests for guest users' do
        guest = create(:user)
        target_project.add_guest(guest)

        expect(project.merge_requests_allowing_push_to_user(guest)).to be_empty
      end

      it 'does not include the merge request for other users' do
        other_user = create(:user)

        expect(project.merge_requests_allowing_push_to_user(other_user)).to be_empty
      end

      it 'is empty when no user is passed' do
        expect(project.merge_requests_allowing_push_to_user(nil)).to be_empty
      end
    end

    describe '#any_branch_allows_collaboration?' do
      it 'allows access when there are merge requests open allowing collaboration' do
        expect(project.any_branch_allows_collaboration?(user))
          .to be_truthy
      end

      it 'does not allow access when there are no merge requests open allowing collaboration' do
        merge_request.close!

        expect(project.any_branch_allows_collaboration?(user))
          .to be_falsey
      end
    end

    describe '#branch_allows_collaboration?' do
      it 'allows access if the user can merge the merge request' do
        expect(project.branch_allows_collaboration?(user, 'awesome-feature-1'))
          .to be_truthy
      end

      it 'does not allow guest users access' do
        guest = create(:user)
        target_project.add_guest(guest)

        expect(project.branch_allows_collaboration?(guest, 'awesome-feature-1'))
          .to be_falsy
      end

      it 'does not allow access to branches for which the merge request was closed' do
        create(:merge_request, :closed,
               target_project: target_project,
               target_branch: 'target-branch',
               source_project: project,
               source_branch: 'rejected-feature-1',
               allow_collaboration: true)

        expect(project.branch_allows_collaboration?(user, 'rejected-feature-1'))
          .to be_falsy
      end

      it 'does not allow access if the user cannot merge the merge request' do
        create(:protected_branch, :maintainers_can_push, project: target_project, name: 'target-branch')

        expect(project.branch_allows_collaboration?(user, 'awesome-feature-1'))
          .to be_falsy
      end

      context 'when the requeststore is active', :request_store do
        it 'only queries per project across instances' do
          control = ActiveRecord::QueryRecorder.new { project.branch_allows_collaboration?(user, 'awesome-feature-1') }

          expect { 2.times { described_class.find(project.id).branch_allows_collaboration?(user, 'awesome-feature-1') } }
            .not_to exceed_query_limit(control).with_threshold(2)
        end
      end
    end
  end

  describe '#external_authorization_classification_label' do
    it 'falls back to the default when none is configured' do
      enable_external_authorization_service_check

      expect(build(:project).external_authorization_classification_label)
        .to eq('default_label')
    end

    it 'returns the classification label if it was configured on the project' do
      enable_external_authorization_service_check

      project = build(:project,
                      external_authorization_classification_label: 'hello')

      expect(project.external_authorization_classification_label)
        .to eq('hello')
    end
  end

  describe "#pages_https_only?" do
    subject { build(:project) }

    context "when HTTPS pages are disabled" do
      it { is_expected.not_to be_pages_https_only }
    end

    context "when HTTPS pages are enabled", :https_pages_enabled do
      it { is_expected.to be_pages_https_only }
    end
  end

  describe "#pages_https_only? validation", :https_pages_enabled do
    subject(:project) do
      # set-up dirty object:
      create(:project, pages_https_only: false).tap do |p|
        p.pages_https_only = true
      end
    end

    context "when no domains are associated" do
      it { is_expected.to be_valid }
    end

    context "when domains including keys and certificates are associated" do
      before do
        allow(project)
          .to receive(:pages_domains)
          .and_return([instance_double(PagesDomain, https?: true)])
      end

      it { is_expected.to be_valid }
    end

    context "when domains including no keys or certificates are associated" do
      before do
        allow(project)
          .to receive(:pages_domains)
          .and_return([instance_double(PagesDomain, https?: false)])
      end

      it { is_expected.not_to be_valid }
    end
  end

  describe '#toggle_ci_cd_settings!' do
    it 'toggles the value on #settings' do
      project = create(:project, group_runners_enabled: false)

      expect(project.group_runners_enabled).to be false

      project.toggle_ci_cd_settings!(:group_runners_enabled)

      expect(project.group_runners_enabled).to be true
    end
  end

  describe '#gitlab_deploy_token' do
    let(:project) { create(:project) }

    subject { project.gitlab_deploy_token }

    context 'when there is a gitlab deploy token associated' do
      let!(:deploy_token) { create(:deploy_token, :gitlab_deploy_token, projects: [project]) }

      it { is_expected.to eq(deploy_token) }
    end

    context 'when there is no a gitlab deploy token associated' do
      it { is_expected.to be_nil }
    end

    context 'when there is a gitlab deploy token associated but is has been revoked' do
      let!(:deploy_token) { create(:deploy_token, :gitlab_deploy_token, :revoked, projects: [project]) }
      it { is_expected.to be_nil }
    end

    context 'when there is a gitlab deploy token associated but it is expired' do
      let!(:deploy_token) { create(:deploy_token, :gitlab_deploy_token, :expired, projects: [project]) }

      it { is_expected.to be_nil }
    end

    context 'when there is a deploy token associated with a different name' do
      let!(:deploy_token) { create(:deploy_token, projects: [project]) }

      it { is_expected.to be_nil }
    end

    context 'when there is a deploy token associated to a different project' do
      let(:project_2) { create(:project) }
      let!(:deploy_token) { create(:deploy_token, projects: [project_2]) }

      it { is_expected.to be_nil }
    end
  end

  context 'with uploads' do
    it_behaves_like 'model with uploads', true do
      let(:model_object) { create(:project, :with_avatar) }
      let(:upload_attribute) { :avatar }
      let(:uploader_class) { AttachmentUploader }
    end
  end

  context '#commits_by' do
    let(:project) { create(:project, :repository) }
    let(:commits) { project.repository.commits('HEAD', limit: 3).commits }
    let(:commit_shas) { commits.map(&:id) }

    it 'retrieves several commits from the repository by oid' do
      expect(project.commits_by(oids: commit_shas)).to eq commits
    end
  end

  context '#members_among' do
    let(:users) { create_list(:user, 3) }
    set(:group) { create(:group) }
    set(:project) { create(:project, namespace: group) }

    before do
      project.add_guest(users.first)
      project.group.add_maintainer(users.last)
    end

    context 'when users is an Array' do
      it 'returns project members among the users' do
        expect(project.members_among(users)).to eq([users.first, users.last])
      end

      it 'maintains input order' do
        expect(project.members_among(users.reverse)).to eq([users.last, users.first])
      end

      it 'returns empty array if users is empty' do
        result = project.members_among([])

        expect(result).to be_empty
      end
    end

    context 'when users is a relation' do
      it 'returns project members among the users' do
        result = project.members_among(User.where(id: users.map(&:id)))

        expect(result).to be_a(ActiveRecord::Relation)
        expect(result).to eq([users.first, users.last])
      end

      it 'returns empty relation if users is empty' do
        result = project.members_among(User.none)

        expect(result).to be_a(ActiveRecord::Relation)
        expect(result).to be_empty
      end
    end
  end

  describe "#find_or_initialize_services" do
    subject { build(:project) }

    it 'returns only enabled services' do
      allow(Service).to receive(:available_services_names).and_return(%w(prometheus pushover))
      allow(subject).to receive(:disabled_services).and_return(%w(prometheus))

      services = subject.find_or_initialize_services

      expect(services.count).to eq 1
      expect(services).to include(PushoverService)
    end
  end

  describe "#find_or_initialize_service" do
    subject { build(:project) }

    it 'avoids N+1 database queries' do
      allow(Service).to receive(:available_services_names).and_return(%w(prometheus pushover))

      control_count = ActiveRecord::QueryRecorder.new { subject.find_or_initialize_service('prometheus') }.count

      allow(Service).to receive(:available_services_names).and_call_original

      expect { subject.find_or_initialize_service('prometheus') }.not_to exceed_query_limit(control_count)
    end

    it 'returns nil if service is disabled' do
      allow(subject).to receive(:disabled_services).and_return(%w(prometheus))

      expect(subject.find_or_initialize_service('prometheus')).to be_nil
    end
  end

  describe '.find_without_deleted' do
    it 'returns nil if the project is about to be removed' do
      project = create(:project, pending_delete: true)

      expect(described_class.find_without_deleted(project.id)).to be_nil
    end

    it 'returns a project when it is not about to be removed' do
      project = create(:project)

      expect(described_class.find_without_deleted(project.id)).to eq(project)
    end
  end

  describe '.for_group' do
    it 'returns the projects for a given group' do
      group = create(:group)
      project = create(:project, namespace: group)

      expect(described_class.for_group(group)).to eq([project])
    end
  end

  describe '.deployments' do
    subject { project.deployments }

    let(:project) { create(:project) }

    before do
      allow_any_instance_of(Deployment).to receive(:create_ref)
    end

    context 'when there is a deployment record with created status' do
      let(:deployment) { create(:deployment, :created, project: project) }

      it 'does not return the record' do
        is_expected.to be_empty
      end
    end

    context 'when there is a deployment record with running status' do
      let(:deployment) { create(:deployment, :running, project: project) }

      it 'does not return the record' do
        is_expected.to be_empty
      end
    end

    context 'when there is a deployment record with success status' do
      let(:deployment) { create(:deployment, :success, project: project) }

      it 'returns the record' do
        is_expected.to eq([deployment])
      end
    end
  end

  describe '#snippets_visible?' do
    it 'returns true when a logged in user can read snippets' do
      project = create(:project, :public)
      user = create(:user)

      expect(project.snippets_visible?(user)).to eq(true)
    end

    it 'returns true when an anonymous user can read snippets' do
      project = create(:project, :public)

      expect(project.snippets_visible?).to eq(true)
    end

    it 'returns false when a user can not read snippets' do
      project = create(:project, :private)
      user = create(:user)

      expect(project.snippets_visible?(user)).to eq(false)
    end
  end

  describe '#all_clusters' do
    let(:project) { create(:project) }
    let(:cluster) { create(:cluster, cluster_type: :project_type, projects: [project]) }

    subject { project.all_clusters }

    it 'returns project level cluster' do
      expect(subject).to eq([cluster])
    end

    context 'project belongs to a group' do
      let(:group_cluster) { create(:cluster, :group) }
      let(:group) { group_cluster.group }
      let(:project) { create(:project, group: group) }

      it 'returns clusters for groups of this project' do
        expect(subject).to contain_exactly(cluster, group_cluster)
      end
    end
  end

  describe '#object_pool_params' do
    let(:project) { create(:project, :repository, :public) }

    subject { project.object_pool_params }

    before do
      stub_application_setting(hashed_storage_enabled: true)
    end

    context 'when the objects cannot be pooled' do
      let(:project) { create(:project, :repository, :private) }

      it { is_expected.to be_empty }
    end

    context 'when a pool is created' do
      it 'returns that pool repository' do
        expect(subject).not_to be_empty
        expect(subject[:pool_repository]).to be_persisted
      end
    end
  end

  describe '#git_objects_poolable?' do
    subject { project }

    context 'when the feature flag is turned off' do
      before do
        stub_feature_flags(object_pools: false)
      end

      let(:project) { create(:project, :repository, :public) }

      it { is_expected.not_to be_git_objects_poolable }
    end

    context 'when the feature flag is enabled' do
      context 'when not using hashed storage' do
        let(:project) { create(:project, :legacy_storage, :public, :repository) }

        it { is_expected.not_to be_git_objects_poolable }
      end

      context 'when the project is not public' do
        let(:project) { create(:project, :private) }

        it { is_expected.not_to be_git_objects_poolable }
      end

      context 'when objects are poolable' do
        let(:project) { create(:project, :repository, :public) }

        before do
          stub_application_setting(hashed_storage_enabled: true)
        end

        it { is_expected.to be_git_objects_poolable }
      end
    end
  end

  describe '#leave_pool_repository' do
    let(:pool) { create(:pool_repository) }
    let(:project) { create(:project, :repository, pool_repository: pool) }

    it 'removes the membership' do
      project.leave_pool_repository

      expect(pool.member_projects.reload).not_to include(project)
    end
  end

  describe '#check_personal_projects_limit' do
    context 'when creating a project for a group' do
      it 'does nothing' do
        creator = build(:user)
        project = build(:project, namespace: build(:group), creator: creator)

        allow(creator)
          .to receive(:can_create_project?)
          .and_return(false)

        project.check_personal_projects_limit

        expect(project.errors).to be_empty
      end
    end

    context 'when the user is not allowed to create a personal project' do
      let(:user) { build(:user) }
      let(:project) { build(:project, creator: user) }

      before do
        allow(user)
          .to receive(:can_create_project?)
          .and_return(false)
      end

      context 'when the project limit is zero' do
        it 'adds a validation error' do
          allow(user)
            .to receive(:projects_limit)
            .and_return(0)

          project.check_personal_projects_limit

          expect(project.errors[:limit_reached].first)
            .to match(/Personal project creation is not allowed/)
        end
      end

      context 'when the project limit is greater than zero' do
        it 'adds a validation error' do
          allow(user)
            .to receive(:projects_limit)
            .and_return(5)

          project.check_personal_projects_limit

          expect(project.errors[:limit_reached].first)
            .to match(/Your project limit is 5 projects/)
        end
      end
    end

    context 'when the user is allowed to create personal projects' do
      it 'does nothing' do
        user = build(:user)
        project = build(:project, creator: user)

        allow(user)
          .to receive(:can_create_project?)
          .and_return(true)

        project.check_personal_projects_limit

        expect(project.errors).to be_empty
      end
    end
  end

  describe '#has_pool_repsitory?' do
    it 'returns false when it does not have a pool repository' do
      subject = create(:project, :repository)

      expect(subject.has_pool_repository?).to be false
    end

    it 'returns true when it has a pool repository' do
      pool    = create(:pool_repository, :ready)
      subject = create(:project, :repository, pool_repository: pool)

      expect(subject.has_pool_repository?).to be true
    end
  end

  def rugged_config
    rugged_repo(project.repository).config
  end

  def create_pipeline(project, status = 'success')
    create(:ci_pipeline, project: project,
                         sha: project.commit.sha,
                         ref: project.default_branch,
                         status: status)
  end

  def create_build(new_pipeline = pipeline, name = 'test')
    create(:ci_build, :success, :artifacts,
           pipeline: new_pipeline,
           status: new_pipeline.status,
           name: name)
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integration do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe "Associations" do
    it { is_expected.to belong_to(:project).inverse_of(:integrations) }
    it { is_expected.to belong_to(:group).inverse_of(:integrations) }
    it { is_expected.to have_one(:service_hook).inverse_of(:integration).with_foreign_key(:service_id) }
    it { is_expected.to have_one(:issue_tracker_data).autosave(true).inverse_of(:integration).with_foreign_key(:service_id).class_name('Integrations::IssueTrackerData') }
    it { is_expected.to have_one(:jira_tracker_data).autosave(true).inverse_of(:integration).with_foreign_key(:service_id).class_name('Integrations::JiraTrackerData') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_exclusion_of(:type).in_array(described_class::BASE_CLASSES) }

    where(:project_id, :group_id, :instance, :valid) do
      1    | nil  | false  | true
      nil  | 1    | false  | true
      nil  | nil  | true   | true
      nil  | nil  | false  | false
      1    | 1    | false  | false
      1    | nil  | false  | true
      1    | nil  | true   | false
      nil  | 1    | false  | true
      nil  | 1    | true   | false
    end

    with_them do
      it 'validates the integration' do
        expect(build(:integration, project_id: project_id, group_id: group_id, instance: instance).valid?).to eq(valid)
      end
    end

    context 'with existing integrations' do
      before_all do
        create(:integration, :instance)
        create(:integration, project: project)
        create(:integration, group: group, project: nil)
      end

      it 'allows only one instance integration per type' do
        expect(build(:integration, :instance)).to be_invalid
      end

      it 'allows only one project integration per type' do
        expect(build(:integration, project: project)).to be_invalid
      end

      it 'allows only one group integration per type' do
        expect(build(:integration, group: group, project: nil)).to be_invalid
      end
    end
  end

  describe 'Scopes' do
    describe '.third_party_wikis' do
      let!(:integration1) { create(:jira_integration) }
      let!(:integration2) { create(:redmine_integration) }
      let!(:integration3) { create(:confluence_integration) }
      let!(:integration4) { create(:shimo_integration) }

      it 'returns the right group integration' do
        expect(described_class.third_party_wikis).to contain_exactly(integration3, integration4)
      end
    end

    describe '.with_default_settings' do
      it 'returns the correct integrations' do
        instance_integration = create(:integration, :instance)
        inheriting_integration = create(:integration, inherit_from_id: instance_integration.id)

        expect(described_class.with_default_settings).to match_array([inheriting_integration])
      end
    end

    describe '.with_custom_settings' do
      it 'returns the correct integrations' do
        instance_integration = create(:integration, :instance)
        create(:integration, inherit_from_id: instance_integration.id)

        expect(described_class.with_custom_settings).to match_array([instance_integration])
      end
    end

    describe '.by_type' do
      let!(:integration1) { create(:jira_integration) }
      let!(:integration2) { create(:jira_integration) }
      let!(:integration3) { create(:redmine_integration) }

      subject { described_class.by_type(type) }

      context 'when type is "Integrations::JiraService"' do
        let(:type) { 'Integrations::Jira' }

        it { is_expected.to match_array([integration1, integration2]) }
      end

      context 'when type is "Integrations::Redmine"' do
        let(:type) { 'Integrations::Redmine' }

        it { is_expected.to match_array([integration3]) }
      end
    end

    describe '.for_group' do
      let!(:integration1) { create(:jira_integration, project_id: nil, group_id: group.id) }
      let!(:integration2) { create(:jira_integration) }

      it 'returns the right group integration' do
        expect(described_class.for_group(group)).to contain_exactly(integration1)
      end
    end

    shared_examples 'hook scope' do |hook_type|
      describe ".#{hook_type}_hooks" do
        it "includes services where #{hook_type}_events is true" do
          create(:integration, active: true, "#{hook_type}_events": true)

          expect(described_class.send("#{hook_type}_hooks").count).to eq 1
        end

        it "excludes services where #{hook_type}_events is false" do
          create(:integration, active: true, "#{hook_type}_events": false)

          expect(described_class.send("#{hook_type}_hooks").count).to eq 0
        end
      end
    end

    include_examples 'hook scope', 'confidential_note'
    include_examples 'hook scope', 'alert'
    include_examples 'hook scope', 'archive_trace'
  end

  describe '#operating?' do
    it 'is false when the integration is not active' do
      expect(build(:integration).operating?).to eq(false)
    end

    it 'is false when the integration is not persisted' do
      expect(build(:integration, active: true).operating?).to eq(false)
    end

    it 'is true when the integration is active and persisted' do
      expect(create(:integration, active: true).operating?).to eq(true)
    end
  end

  describe '#testable?' do
    context 'when integration is project-level' do
      subject { build(:integration, project: project) }

      it { is_expected.to be_testable }
    end

    context 'when integration is not project-level' do
      subject { build(:integration, project: nil) }

      it { is_expected.not_to be_testable }
    end
  end

  describe '#test' do
    let(:integration) { build(:integration, project: project) }
    let(:data) { 'test' }

    it 'calls #execute' do
      expect(integration).to receive(:execute).with(data)

      integration.test(data)
    end

    it 'returns a result' do
      result = 'foo'
      allow(integration).to receive(:execute).with(data).and_return(result)

      expect(integration.test(data)).to eq(
        success: true,
        result: result
      )
    end
  end

  describe '#project_level?' do
    it 'is true when integration has a project' do
      expect(build(:integration, project: project)).to be_project_level
    end

    it 'is false when integration has no project' do
      expect(build(:integration, project: nil)).not_to be_project_level
    end
  end

  describe '#group_level?' do
    it 'is true when integration has a group' do
      expect(build(:integration, group: group)).to be_group_level
    end

    it 'is false when integration has no group' do
      expect(build(:integration, group: nil)).not_to be_group_level
    end
  end

  describe '#instance_level?' do
    it 'is true when integration has instance-level integration' do
      expect(build(:integration, :instance)).to be_instance_level
    end

    it 'is false when integration does not have instance-level integration' do
      expect(build(:integration, instance: false)).not_to be_instance_level
    end
  end

  describe '.find_or_initialize_non_project_specific_integration' do
    let!(:integration_1) { create(:jira_integration, project_id: nil, group_id: group.id) }
    let!(:integration_2) { create(:jira_integration) }

    it 'returns the right integration' do
      expect(Integration.find_or_initialize_non_project_specific_integration('jira', group_id: group))
        .to eq(integration_1)
    end

    it 'does not create a new integration' do
      expect { Integration.find_or_initialize_non_project_specific_integration('redmine', group_id: group) }
        .not_to change(Integration, :count)
    end
  end

  describe '.find_or_initialize_all_non_project_specific' do
    shared_examples 'integration instances' do
      it 'returns the available integration instances' do
        expect(Integration.find_or_initialize_all_non_project_specific(Integration.for_instance).map(&:to_param))
          .to match_array(Integration.available_integration_names(include_project_specific: false))
      end

      it 'does not create integration instances' do
        expect { Integration.find_or_initialize_all_non_project_specific(Integration.for_instance) }
          .not_to change(Integration, :count)
      end
    end

    it_behaves_like 'integration instances'

    context 'with all existing instances' do
      def integration_hash(type)
        Integration.new(instance: true, type: type).to_database_hash
      end

      before do
        attrs = Integration.available_integration_types(include_project_specific: false).map do
          integration_hash(_1)
        end

        Integration.insert_all(attrs)
      end

      it_behaves_like 'integration instances'

      context 'with a previous existing integration (:mock_ci) and a new integration (:asana)' do
        before do
          Integration.insert(integration_hash(:mock_ci))
          Integration.delete_by(**integration_hash(:asana))
        end

        it_behaves_like 'integration instances'
      end
    end

    context 'with a few existing instances' do
      before do
        create(:jira_integration, :instance)
      end

      it_behaves_like 'integration instances'
    end
  end

  describe '#inheritable?' do
    it 'is true for an instance integration' do
      expect(create(:integration, :instance)).to be_inheritable
    end

    it 'is true for a group integration' do
      expect(create(:integration, :group)).to be_inheritable
    end

    it 'is false for a project integration' do
      expect(create(:integration)).not_to be_inheritable
    end
  end

  describe '.build_from_integration' do
    context 'when integration is invalid' do
      let(:invalid_integration) do
        build(:prometheus_integration, :instance, active: true, properties: {})
          .tap { |integration| integration.save!(validate: false) }
      end

      it 'sets integration to inactive' do
        integration = described_class.build_from_integration(invalid_integration, project_id: project.id)

        expect(integration).to be_valid
        expect(integration.active).to be false
      end
    end

    context 'when integration is an instance-level integration' do
      let(:instance_integration) { create(:jira_integration, :instance) }

      it 'sets inherit_from_id from integration' do
        integration = described_class.build_from_integration(instance_integration, project_id: project.id)

        expect(integration.inherit_from_id).to eq(instance_integration.id)
      end
    end

    context 'when integration is a group-level integration' do
      let(:group_integration) { create(:jira_integration, :group, group: group) }

      it 'sets inherit_from_id from integration' do
        integration = described_class.build_from_integration(group_integration, project_id: project.id)

        expect(integration.inherit_from_id).to eq(group_integration.id)
      end
    end

    describe 'build issue tracker from an integration' do
      let(:url) { 'http://jira.example.com' }
      let(:api_url) { 'http://api-jira.example.com' }
      let(:username) { 'jira-username' }
      let(:password) { 'jira-password' }
      let(:data_params) do
        {
          url: url, api_url: api_url,
          username: username, password: password
        }
      end

      shared_examples 'integration creation from an integration' do
        it 'creates a correct integration for a project integration' do
          new_integration = described_class.build_from_integration(integration, project_id: project.id)

          expect(new_integration).to be_active
          expect(new_integration.url).to eq(url)
          expect(new_integration.api_url).to eq(api_url)
          expect(new_integration.username).to eq(username)
          expect(new_integration.password).to eq(password)
          expect(new_integration.instance).to eq(false)
          expect(new_integration.project).to eq(project)
          expect(new_integration.group).to eq(nil)
        end

        it 'creates a correct integration for a group integration' do
          new_integration = described_class.build_from_integration(integration, group_id: group.id)

          expect(new_integration).to be_active
          expect(new_integration.url).to eq(url)
          expect(new_integration.api_url).to eq(api_url)
          expect(new_integration.username).to eq(username)
          expect(new_integration.password).to eq(password)
          expect(new_integration.instance).to eq(false)
          expect(new_integration.project).to eq(nil)
          expect(new_integration.group).to eq(group)
        end
      end

      # this  will be removed as part of https://gitlab.com/gitlab-org/gitlab/issues/29404
      context 'when data is stored in properties' do
        let(:properties) { data_params }
        let!(:integration) do
          create(:jira_integration, :without_properties_callback, properties: properties.merge(additional: 'something'))
        end

        it_behaves_like 'integration creation from an integration'
      end

      context 'when data are stored in separated fields' do
        let(:integration) do
          create(:jira_integration, data_params.merge(properties: {}))
        end

        it_behaves_like 'integration creation from an integration'
      end

      context 'when data are stored in both properties and separated fields' do
        let(:properties) { data_params }
        let(:integration) do
          create(:jira_integration, :without_properties_callback, active: true, properties: properties).tap do |integration|
            create(:jira_tracker_data, data_params.merge(integration: integration))
          end
        end

        it_behaves_like 'integration creation from an integration'
      end
    end
  end

  describe '.default_integration' do
    context 'with an instance-level integration' do
      let_it_be(:instance_integration) { create(:jira_integration, :instance) }

      it 'returns the instance integration' do
        expect(described_class.default_integration('Integrations::Jira', project)).to eq(instance_integration)
      end

      it 'returns nil for nonexistent integration type' do
        expect(described_class.default_integration('Integrations::Hipchat', project)).to eq(nil)
      end

      context 'with a group integration' do
        let(:integration_name) { 'Integrations::Jira' }

        let_it_be(:group_integration) { create(:jira_integration, group_id: group.id, project_id: nil) }

        it 'returns the group integration for a project' do
          expect(described_class.default_integration(integration_name, project)).to eq(group_integration)
        end

        it 'returns the instance integration for a group' do
          expect(described_class.default_integration(integration_name, group)).to eq(instance_integration)
        end

        context 'with a subgroup' do
          let_it_be(:subgroup) { create(:group, parent: group) }

          let!(:project) { create(:project, group: subgroup) }

          it 'returns the closest group integration for a project' do
            expect(described_class.default_integration(integration_name, project)).to eq(group_integration)
          end

          it 'returns the closest group integration for a subgroup' do
            expect(described_class.default_integration(integration_name, subgroup)).to eq(group_integration)
          end

          context 'having a integration with custom settings' do
            let!(:subgroup_integration) { create(:jira_integration, group_id: subgroup.id, project_id: nil) }

            it 'returns the closest group integration for a project' do
              expect(described_class.default_integration(integration_name, project)).to eq(subgroup_integration)
            end
          end

          context 'having a integration inheriting settings' do
            let!(:subgroup_integration) { create(:jira_integration, group_id: subgroup.id, project_id: nil, inherit_from_id: group_integration.id) }

            it 'returns the closest group integration which does not inherit from its parent for a project' do
              expect(described_class.default_integration(integration_name, project)).to eq(group_integration)
            end
          end
        end
      end
    end
  end

  describe '.create_from_active_default_integrations' do
    context 'with an active instance-level integration' do
      let!(:instance_integration) { create(:prometheus_integration, :instance, api_url: 'https://prometheus.instance.com/') }

      it 'creates an integration from the instance-level integration' do
        described_class.create_from_active_default_integrations(project, :project_id)

        expect(project.reload.integrations.size).to eq(1)
        expect(project.reload.integrations.first.api_url).to eq(instance_integration.api_url)
        expect(project.reload.integrations.first.inherit_from_id).to eq(instance_integration.id)
      end

      context 'passing a group' do
        it 'creates an integration from the instance-level integration' do
          described_class.create_from_active_default_integrations(group, :group_id)

          expect(group.reload.integrations.size).to eq(1)
          expect(group.reload.integrations.first.api_url).to eq(instance_integration.api_url)
          expect(group.reload.integrations.first.inherit_from_id).to eq(instance_integration.id)
        end
      end

      context 'with an active group-level integration' do
        let!(:group_integration) { create(:prometheus_integration, :group, group: group, api_url: 'https://prometheus.group.com/') }

        it 'creates an integration from the group-level integration' do
          described_class.create_from_active_default_integrations(project, :project_id)

          expect(project.reload.integrations.size).to eq(1)
          expect(project.reload.integrations.first.api_url).to eq(group_integration.api_url)
          expect(project.reload.integrations.first.inherit_from_id).to eq(group_integration.id)
        end

        context 'there are multiple inheritable integrations, and a duplicate' do
          let!(:group_integration_2) { create(:jenkins_integration, :group, group: group) }
          let!(:group_integration_3) { create(:datadog_integration, :instance) }
          let!(:duplicate) { create(:jenkins_integration, project: project) }

          it 'returns the number of successfully created integrations' do
            expect(described_class.create_from_active_default_integrations(project, :project_id)).to eq 2

            expect(project.reload.integrations.size).to eq(3)
          end
        end

        context 'passing a group' do
          let!(:subgroup) { create(:group, parent: group) }

          it 'creates an integration from the group-level integration' do
            described_class.create_from_active_default_integrations(subgroup, :group_id)

            expect(subgroup.reload.integrations.size).to eq(1)
            expect(subgroup.reload.integrations.first.api_url).to eq(group_integration.api_url)
            expect(subgroup.reload.integrations.first.inherit_from_id).to eq(group_integration.id)
          end
        end

        context 'with an active subgroup' do
          let!(:subgroup_integration) { create(:prometheus_integration, :group, group: subgroup, api_url: 'https://prometheus.subgroup.com/') }
          let!(:subgroup) { create(:group, parent: group) }
          let(:project) { create(:project, group: subgroup) }

          it 'creates an integration from the subgroup-level integration' do
            described_class.create_from_active_default_integrations(project, :project_id)

            expect(project.reload.integrations.size).to eq(1)
            expect(project.reload.integrations.first.api_url).to eq(subgroup_integration.api_url)
            expect(project.reload.integrations.first.inherit_from_id).to eq(subgroup_integration.id)
          end

          context 'passing a group' do
            let!(:sub_subgroup) { create(:group, parent: subgroup) }

            context 'traversal queries' do
              shared_examples 'correct ancestor order' do
                it 'creates an integration from the subgroup-level integration' do
                  described_class.create_from_active_default_integrations(sub_subgroup, :group_id)

                  sub_subgroup.reload

                  expect(sub_subgroup.integrations.size).to eq(1)
                  expect(sub_subgroup.integrations.first.api_url).to eq(subgroup_integration.api_url)
                  expect(sub_subgroup.integrations.first.inherit_from_id).to eq(subgroup_integration.id)
                end

                context 'having an integration inheriting settings' do
                  let!(:subgroup_integration) { create(:prometheus_integration, :group, group: subgroup, inherit_from_id: group_integration.id, api_url: 'https://prometheus.subgroup.com/') }

                  it 'creates an integration from the group-level integration' do
                    described_class.create_from_active_default_integrations(sub_subgroup, :group_id)

                    sub_subgroup.reload

                    expect(sub_subgroup.integrations.size).to eq(1)
                    expect(sub_subgroup.integrations.first.api_url).to eq(group_integration.api_url)
                    expect(sub_subgroup.integrations.first.inherit_from_id).to eq(group_integration.id)
                  end
                end
              end

              context 'recursive' do
                before do
                  stub_feature_flags(use_traversal_ids: false)
                end

                include_examples 'correct ancestor order'
              end

              context 'linear' do
                before do
                  stub_feature_flags(use_traversal_ids: true)

                  sub_subgroup.reload # make sure traversal_ids are reloaded
                end

                include_examples 'correct ancestor order'
              end
            end
          end
        end
      end
    end
  end

  describe '.inherited_descendants_from_self_or_ancestors_from' do
    let_it_be(:subgroup1) { create(:group, parent: group) }
    let_it_be(:subgroup2) { create(:group, parent: group) }
    let_it_be(:project1) { create(:project, group: subgroup1) }
    let_it_be(:project2) { create(:project, group: subgroup2) }
    let_it_be(:group_integration) { create(:prometheus_integration, :group, group: group) }
    let_it_be(:subgroup_integration1) { create(:prometheus_integration, :group, group: subgroup1, inherit_from_id: group_integration.id) }
    let_it_be(:subgroup_integration2) { create(:prometheus_integration, :group, group: subgroup2) }
    let_it_be(:project_integration1) { create(:prometheus_integration, project: project1, inherit_from_id: group_integration.id) }
    let_it_be(:project_integration2) { create(:prometheus_integration, project: project2, inherit_from_id: subgroup_integration2.id) }

    it 'returns the groups and projects inheriting from integration ancestors', :aggregate_failures do
      expect(described_class.inherited_descendants_from_self_or_ancestors_from(group_integration)).to eq([subgroup_integration1, project_integration1])
      expect(described_class.inherited_descendants_from_self_or_ancestors_from(subgroup_integration2)).to eq([project_integration2])
    end
  end

  describe '.integration_name_to_type' do
    it 'handles a simple case' do
      expect(described_class.integration_name_to_type(:asana)).to eq 'Integrations::Asana'
    end

    it 'raises an error if the name is unknown' do
      expect { described_class.integration_name_to_type('foo') }
        .to raise_exception(described_class::UnknownType, /foo/)
    end

    it 'handles all available_integration_names' do
      types = described_class.available_integration_names.map { described_class.integration_name_to_type(_1) }

      expect(types).to all(start_with('Integrations::'))
    end
  end

  describe '.integration_name_to_model' do
    it 'raises an error if integration name is invalid' do
      expect { described_class.integration_name_to_model('foo') }.to raise_exception(described_class::UnknownType, /foo/)
    end
  end

  describe "{property}_changed?" do
    let(:integration) do
      Integrations::Bamboo.create!(
        project: project,
        properties: {
          bamboo_url: 'http://gitlab.com',
          username: 'mic',
          password: "password"
        }
      )
    end

    it "returns false when the property has not been assigned a new value" do
      integration.username = "key_changed"
      expect(integration.bamboo_url_changed?).to be_falsy
    end

    it "returns true when the property has been assigned a different value" do
      integration.bamboo_url = "http://example.com"
      expect(integration.bamboo_url_changed?).to be_truthy
    end

    it "returns true when the property has been assigned a different value twice" do
      integration.bamboo_url = "http://example.com"
      integration.bamboo_url = "http://example.com"
      expect(integration.bamboo_url_changed?).to be_truthy
    end

    it "returns false when the property has been re-assigned the same value" do
      integration.bamboo_url = 'http://gitlab.com'
      expect(integration.bamboo_url_changed?).to be_falsy
    end

    it "returns false when the property has been assigned a new value then saved" do
      integration.bamboo_url = 'http://example.com'
      integration.save!
      expect(integration.bamboo_url_changed?).to be_falsy
    end
  end

  describe '#properties=' do
    let(:integration_type) do
      Class.new(described_class) do
        field :foo
        field :bar
      end
    end

    it 'supports indifferent access' do
      integration = integration_type.new

      integration.properties = { foo: 1, 'bar' => 2 }

      expect(integration).to have_attributes(foo: 1, bar: 2)
    end
  end

  describe '#properties' do
    it 'is not mutable' do
      integration = described_class.new

      integration.properties = { foo: 1, bar: 2 }

      expect { integration.properties[:foo] = 3 }.to raise_error(FrozenError)
    end
  end

  describe "{property}_touched?" do
    let(:integration) do
      Integrations::Bamboo.create!(
        project: project,
        properties: {
          bamboo_url: 'http://gitlab.com',
          username: 'mic',
          password: "password"
        }
      )
    end

    it "returns false when the property has not been assigned a new value" do
      integration.username = "key_changed"
      expect(integration.bamboo_url_touched?).to be_falsy
    end

    it "returns true when the property has been assigned a different value" do
      integration.bamboo_url = "http://example.com"
      expect(integration.bamboo_url_touched?).to be_truthy
    end

    it "returns true when the property has been assigned a different value twice" do
      integration.bamboo_url = "http://example.com"
      integration.bamboo_url = "http://example.com"
      expect(integration.bamboo_url_touched?).to be_truthy
    end

    it "returns true when the property has been re-assigned the same value" do
      integration.bamboo_url = 'http://gitlab.com'
      expect(integration.bamboo_url_touched?).to be_truthy
    end

    it "returns false when the property has been assigned a new value then saved" do
      integration.bamboo_url = 'http://example.com'
      integration.save!
      expect(integration.bamboo_url_changed?).to be_falsy
    end
  end

  describe "{property}_was" do
    let(:integration) do
      Integrations::Bamboo.create!(
        project: project,
        properties: {
          bamboo_url: 'http://gitlab.com',
          username: 'mic',
          password: "password"
        }
      )
    end

    it "returns nil when the property has not been assigned a new value" do
      integration.username = "key_changed"
      expect(integration.bamboo_url_was).to be_nil
    end

    it "returns the previous value when the property has been assigned a different value" do
      integration.bamboo_url = "http://example.com"
      expect(integration.bamboo_url_was).to eq('http://gitlab.com')
    end

    it "returns initial value when the property has been re-assigned the same value" do
      integration.bamboo_url = 'http://gitlab.com'
      expect(integration.bamboo_url_was).to eq('http://gitlab.com')
    end

    it "returns initial value when the property has been assigned multiple values" do
      integration.bamboo_url = "http://example.com"
      integration.bamboo_url = "http://example.org"
      expect(integration.bamboo_url_was).to eq('http://gitlab.com')
    end

    it "returns nil when the property has been assigned a new value then saved" do
      integration.bamboo_url = 'http://example.com'
      integration.save!
      expect(integration.bamboo_url_was).to be_nil
    end
  end

  describe 'initialize integration with no properties' do
    let(:integration) do
      Integrations::Bugzilla.create!(
        project: project,
        project_url: 'http://gitlab.example.com'
      )
    end

    it 'does not raise error' do
      expect { integration }.not_to raise_error
    end

    it 'sets data correctly' do
      expect(integration.data_fields.project_url).to eq('http://gitlab.example.com')
    end
  end

  describe 'field definitions' do
    shared_examples '#fields' do
      it 'does not return the same array' do
        integration = fake_integration.new

        expect(integration.fields).not_to be(integration.fields)
      end
    end

    shared_examples '#api_field_names' do
      it 'filters out secret fields' do
        safe_fields = %w[some_safe_field safe_field url trojan_gift api_only_field]

        expect(fake_integration.new).to have_attributes(
          api_field_names: match_array(safe_fields)
        )
      end
    end

    shared_examples '#form_fields' do
      it 'filters out API only fields' do
        expect(fake_integration.new.form_fields.pluck(:name)).not_to include('api_only_field')
      end
    end

    context 'when the class overrides #fields' do
      let(:fake_integration) do
        Class.new(Integration) do
          def fields
            [
              { name: 'token', type: 'password' },
              { name: 'api_token', type: 'password' },
              { name: 'token_api', type: 'password' },
              { name: 'safe_token', type: 'password' },
              { name: 'key', type: 'password' },
              { name: 'api_key', type: 'password' },
              { name: 'password', type: 'password' },
              { name: 'password_field', type: 'password' },
              { name: 'some_safe_field' },
              { name: 'safe_field' },
              { name: 'url' },
              { name: 'trojan_horse', type: 'password' },
              { name: 'trojan_gift', type: 'text' },
              { name: 'api_only_field', api_only: true }
            ].shuffle
          end
        end
      end

      it_behaves_like '#fields'
      it_behaves_like '#api_field_names'
      it_behaves_like '#form_fields'
    end

    context 'when the class uses the field DSL' do
      let(:fake_integration) do
        Class.new(described_class) do
          field :token, type: 'password'
          field :api_token, type: 'password'
          field :token_api, type: 'password'
          field :safe_token, type: 'password'
          field :key, type: 'password'
          field :api_key, type: 'password'
          field :password, type: 'password'
          field :password_field, type: 'password'
          field :some_safe_field
          field :safe_field
          field :url
          field :trojan_horse, type: 'password'
          field :trojan_gift, type: 'text'
          field :api_only_field, api_only: true
        end
      end

      it_behaves_like '#fields'
      it_behaves_like '#api_field_names'
      it_behaves_like '#form_fields'
    end
  end

  context 'logging' do
    let(:integration) { build(:integration, project: project) }
    let(:test_message) { "test message" }
    let(:arguments) do
      {
        integration_class: integration.class.name,
        integration_id: integration.id,
        project_path: project.full_path,
        project_id: project.id,
        message: test_message,
        additional_argument: 'some argument'
      }
    end

    it 'logs info messages using json logger' do
      expect(Gitlab::IntegrationsLogger).to receive(:info).with(arguments)

      integration.log_info(test_message, additional_argument: 'some argument')
    end

    it 'logs error messages using json logger' do
      expect(Gitlab::IntegrationsLogger).to receive(:error).with(arguments)

      integration.log_error(test_message, additional_argument: 'some argument')
    end

    context 'when project is nil' do
      let(:project) { nil }
      let(:arguments) do
        {
          integration_class: integration.class.name,
          integration_id: integration.id,
          project_path: nil,
          project_id: nil,
          message: test_message,
          additional_argument: 'some argument'
        }
      end

      it 'logs info messages using json logger' do
        expect(Gitlab::IntegrationsLogger).to receive(:info).with(arguments)

        integration.log_info(test_message, additional_argument: 'some argument')
      end
    end

    context 'logging exceptions' do
      let(:error) { RuntimeError.new('exception message') }
      let(:arguments) do
        super().merge(
          'exception.class' => 'RuntimeError',
          'exception.message' => 'exception message'
        )
      end

      it 'logs exceptions using json logger' do
        expect(Gitlab::IntegrationsLogger).to receive(:error).with(arguments.merge(message: 'exception message'))

        integration.log_exception(error, additional_argument: 'some argument')
      end

      it 'logs exceptions using json logger with a custom message' do
        expect(Gitlab::IntegrationsLogger).to receive(:error).with(arguments.merge(message: 'custom message'))

        integration.log_exception(error, message: 'custom message', additional_argument: 'some argument')
      end
    end
  end

  describe '.available_integration_names' do
    subject { described_class.available_integration_names }

    before do
      allow(described_class).to receive(:integration_names).and_return(%w(foo))
      allow(described_class).to receive(:project_specific_integration_names).and_return(['bar'])
      allow(described_class).to receive(:dev_integration_names).and_return(['baz'])
    end

    it { is_expected.to include('foo', 'bar', 'baz') }

    context 'when `include_project_specific` is false' do
      subject { described_class.available_integration_names(include_project_specific: false) }

      it { is_expected.to include('foo', 'baz') }
      it { is_expected.not_to include('bar') }
    end

    context 'when `include_dev` is false' do
      subject { described_class.available_integration_names(include_dev: false) }

      it { is_expected.to include('foo', 'bar') }
      it { is_expected.not_to include('baz') }
    end
  end

  describe '.project_specific_integration_names' do
    specify do
      expect(described_class.project_specific_integration_names)
        .to include(*described_class::PROJECT_SPECIFIC_INTEGRATION_NAMES)
    end
  end

  describe '#secret_fields' do
    it 'returns all fields with type `password`' do
      allow(subject).to receive(:fields).and_return([
        { name: 'password', type: 'password' },
        { name: 'secret', type: 'password' },
        { name: 'public', type: 'text' }
      ])

      expect(subject.secret_fields).to match_array(%w[password secret])
    end

    it 'returns an empty array if no secret fields exist' do
      expect(subject.secret_fields).to eq([])
    end
  end

  describe '#to_database_hash' do
    let(:properties) { { foo: 1, bar: true } }
    let(:db_props) { properties.stringify_keys }
    let(:record) { create(:integration, :instance, properties: properties) }

    it 'does not include the properties key' do
      hash = record.to_database_hash

      expect(hash).not_to have_key('properties')
    end

    it 'does not include certain attributes' do
      hash = record.to_database_hash

      expect(hash.keys).not_to include('id', 'instance', 'project_id', 'group_id', 'created_at', 'updated_at')
    end

    it 'saves correctly using insert_all' do
      hash = record.to_database_hash
      hash[:project_id] = project.id

      expect do
        described_class.insert_all([hash])
      end.to change(described_class, :count).by(1)

      expect(described_class.last).to have_attributes(properties: db_props)
    end

    it 'decrypts encrypted properties correctly' do
      hash = record.to_database_hash

      expect(hash).to include('encrypted_properties' => be_present, 'encrypted_properties_iv' => be_present)
      expect(hash['encrypted_properties']).not_to eq(record.encrypted_properties)
      expect(hash['encrypted_properties_iv']).not_to eq(record.encrypted_properties_iv)

      decrypted = described_class.decrypt(:properties,
                                          hash['encrypted_properties'],
                                          { iv: hash['encrypted_properties_iv'] })

      expect(decrypted).to eq db_props
    end

    context 'when the properties are empty' do
      let(:properties) { {} }

      it 'is part of the to_database_hash' do
        hash = record.to_database_hash

        expect(hash).to include('encrypted_properties' => be_nil, 'encrypted_properties_iv' => be_nil)
      end

      it 'saves correctly using insert_all' do
        hash = record.to_database_hash
        hash[:project_id] = project

        expect do
          described_class.insert_all([hash])
        end.to change(described_class, :count).by(1)

        expect(described_class.last).not_to eq record
        expect(described_class.last).to have_attributes(properties: db_props)
      end
    end
  end

  describe 'field DSL' do
    let(:integration_type) do
      Class.new(described_class) do
        field :foo
        field :foo_p, storage: :properties
        field :foo_dt, storage: :data_fields

        field :bar, type: 'password'
        field :password

        field :with_help, help: -> { 'help' }
        field :select, type: 'select'
        field :boolean, type: 'checkbox'
      end
    end

    before do
      allow(integration).to receive(:data_fields).and_return(data_fields)
    end

    let(:integration) { integration_type.new }
    let(:data_fields) { Struct.new(:foo_dt).new }

    it 'checks the value of storage' do
      expect do
        Class.new(described_class) { field(:foo, storage: 'bar') }
      end.to raise_error(ArgumentError, /Unknown field storage/)
    end

    it 'provides prop_accessors' do
      integration.foo = 1
      expect(integration.foo).to eq 1
      expect(integration.properties['foo']).to eq 1
      expect(integration).to be_foo_changed

      integration.foo_p = 2
      expect(integration.foo_p).to eq 2
      expect(integration.properties['foo_p']).to eq 2
      expect(integration).to be_foo_p_changed
    end

    it 'provides boolean accessors for checkbox fields' do
      expect(integration).to respond_to(:boolean)
      expect(integration).to respond_to(:boolean?)

      expect(integration).not_to respond_to(:foo?)
      expect(integration).not_to respond_to(:bar?)
      expect(integration).not_to respond_to(:password?)
      expect(integration).not_to respond_to(:select?)
    end

    it 'provides data fields' do
      integration.foo_dt = 3
      expect(integration.foo_dt).to eq 3
      expect(data_fields.foo_dt).to eq 3
      expect(integration).to be_foo_dt_changed
    end

    it 'registers fields in the fields list' do
      expect(integration.fields.pluck(:name)).to match_array %w[
        foo foo_p foo_dt bar password with_help select boolean
      ]

      expect(integration.api_field_names).to match_array %w[
        foo foo_p foo_dt with_help select boolean
      ]
    end

    specify 'fields have expected attributes' do
      expect(integration.fields).to include(
        have_attributes(name: 'foo', type: 'text'),
        have_attributes(name: 'foo_p', type: 'text'),
        have_attributes(name: 'foo_dt', type: 'text'),
        have_attributes(name: 'bar', type: 'password'),
        have_attributes(name: 'password', type: 'password'),
        have_attributes(name: 'with_help', help: 'help'),
        have_attributes(name: 'select', type: 'select'),
        have_attributes(name: 'boolean', type: 'checkbox')
      )
    end
  end

  describe 'boolean_accessor' do
    let(:klass) do
      Class.new(Integration) do
        prop_accessor :test_value
        boolean_accessor :test_value
      end
    end

    let(:integration) { klass.new(test_value: input) }

    where(:input, :method_result, :predicate_method_result) do
      true     | true  | true
      false    | false | false
      1        | true  | true
      0        | false | false
      '1'      | true  | true
      '0'      | false | false
      'true'   | true  | true
      'false'  | false | false
      'foobar' | nil   | false
      ''       | nil   | false
      nil      | nil   | false
      'on'     | true  | true
      'off'    | false | false
      'yes'    | true  | true
      'no'     | false | false
      'n'      | false | false
      'y'      | true  | true
      't'      | true  | true
      'f'      | false | false
    end

    with_them do
      it 'has the correct value' do
        expect(integration).to have_attributes(
          test_value: be(method_result),
          test_value?: be(predicate_method_result)
        )

        # Make sure the original value is stored correctly
        expect(integration.send(:test_value_before_type_cast)).to eq(input)
        expect(integration.properties).to include('test_value' => input)
      end

      context 'when using data fields' do
        let(:klass) do
          Class.new(Integration) do
            field :project_url, storage: :data_fields, type: 'checkbox'

            def data_fields
              issue_tracker_data || self.build_issue_tracker_data
            end
          end
        end

        let(:integration) { klass.new(project_url: input) }

        it 'has the correct value' do
          expect(integration).to have_attributes(
            project_url: be(method_result),
            project_url?: be(predicate_method_result)
          )

          # Make sure the original value is stored correctly
          expect(integration.send(:project_url_before_type_cast)).to eq(input == false ? 'false' : input)
          expect(integration.properties).not_to include('project_url')
        end
      end
    end

    it 'returns values when initialized without input' do
      integration = klass.new

      expect(integration).to have_attributes(
        test_value: be(nil),
        test_value?: be(false)
      )
    end

    context 'when getter is not defined' do
      let(:input) { true }
      let(:klass) do
        Class.new(Integration) do
          boolean_accessor :test_value
        end
      end

      it 'defines a prop_accessor' do
        expect(integration).to have_attributes(
          test_value: true,
          test_value?: true
        )

        expect(integration.properties['test_value']).to be(true)
      end
    end
  end

  describe '#attributes' do
    it 'does not include properties' do
      expect(create(:integration).attributes).not_to have_key('properties')
    end

    it 'can be used in assign_attributes without nullifying properties' do
      record = create(:integration, :instance, properties: { url: generate(:url) })

      attrs = record.attributes

      expect { record.assign_attributes(attrs) }.not_to change(record, :properties)
    end
  end

  describe '#dup' do
    let(:original) { create(:integration, properties: { one: 1, two: 2, three: 3 }) }

    it 'results in distinct ciphertexts, but identical properties' do
      copy = original.dup

      expect(copy).to have_attributes(properties: eq(original.properties))

      expect(copy).not_to have_attributes(
        encrypted_properties: eq(original.encrypted_properties)
      )
    end

    context 'when the model supports data-fields' do
      let(:original) { create(:jira_integration, username: generate(:username), url: generate(:url)) }

      it 'creates distinct but identical data-fields' do
        copy = original.dup

        expect(copy).to have_attributes(
          username: original.username,
          url: original.url
        )

        expect(copy.data_fields).not_to eq(original.data_fields)
      end
    end
  end

  describe '#async_execute' do
    let(:integration) { described_class.new(id: 123) }
    let(:data) { { object_kind: 'push' } }
    let(:supported_events) { %w[push] }

    subject(:async_execute) { integration.async_execute(data) }

    before do
      allow(integration).to receive(:supported_events).and_return(supported_events)
    end

    it 'queues a Integrations::ExecuteWorker' do
      expect(Integrations::ExecuteWorker).to receive(:perform_async).with(integration.id, data)

      async_execute
    end

    context 'when the event is not supported' do
      let(:supported_events) { %w[issue] }

      it 'does not queue a worker' do
        expect(Integrations::ExecuteWorker).not_to receive(:perform_async)

        async_execute
      end
    end
  end
end

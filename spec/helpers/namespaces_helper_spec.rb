# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NamespacesHelper do
  let!(:admin) { create(:admin) }
  let!(:admin_project_creation_level) { nil }
  let!(:admin_group) do
    create(:group,
           :private,
           project_creation_level: admin_project_creation_level)
  end

  let!(:user) { create(:user) }
  let!(:user_project_creation_level) { nil }
  let!(:user_group) do
    create(:group,
           :private,
           project_creation_level: user_project_creation_level)
  end

  let!(:subgroup1) do
    create(:group,
           :private,
           parent: admin_group,
           project_creation_level: nil)
  end

  let!(:subgroup2) do
    create(:group,
           :private,
           parent: admin_group,
           project_creation_level: ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS)
  end

  let!(:subgroup3) do
    create(:group,
           :private,
           parent: admin_group,
           project_creation_level: ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS)
  end

  before do
    admin_group.add_owner(admin)
    user_group.add_owner(user)
  end

  describe '#namespaces_as_json' do
    let(:result) { helper.namespaces_as_json(user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'returns the user\'s groups' do
      json_data = Gitlab::Json.parse(result)

      expect(result).to include('group')
      expect(json_data['group']).to include(
        "id" => user_group.id,
        "name" => user_group.name,
        "display_path" => user_group.full_path,
        "human_name" => user_group.human_name
      )
    end

    it 'returns the user\'s namespace' do
      user_namespace = user.namespace
      json_data = Gitlab::Json.parse(result)

      expect(result).to include('user')
      expect(json_data['user']).to include(
        "id" => user_namespace.id,
        "name" => user_namespace.name,
        "display_path" => user_namespace.full_path,
        "human_name" => user_namespace.human_name
      )
    end
  end

  describe '#namespaces_options' do
    context 'when admin mode is enabled', :enable_admin_mode do
      it 'returns groups without being a member for admin' do
        allow(helper).to receive(:current_user).and_return(admin)

        options = helper.namespaces_options(user_group.id, display_path: true, extra_group: user_group.id)

        expect(options).to include(admin_group.name)
        expect(options).to include(user_group.name)
      end
    end

    context 'when admin mode is disabled' do
      it 'returns only allowed namespaces for admin' do
        allow(helper).to receive(:current_user).and_return(admin)

        options = helper.namespaces_options(user_group.id, display_path: true, extra_group: user_group.id)

        expect(options).to include(admin_group.name)
        expect(options).not_to include(user_group.name)
      end
    end

    it 'returns only allowed namespaces for user' do
      allow(helper).to receive(:current_user).and_return(user)

      options = helper.namespaces_options

      expect(options).not_to include(admin_group.name)
      expect(options).to include(user_group.name)
      expect(options).to include(user.name)
    end

    it 'avoids duplicate groups when extra_group is used' do
      allow(helper).to receive(:current_user).and_return(admin)

      options = helper.namespaces_options(user_group.id, display_path: true, extra_group: build(:group, name: admin_group.name))

      expect(options.scan("data-name=\"#{admin_group.name}\"").count).to eq(1)
      expect(options).to include(admin_group.name)
    end

    context 'when admin mode is disabled' do
      it 'selects existing group' do
        allow(helper).to receive(:current_user).and_return(admin)
        user_group.add_owner(admin)

        options = helper.namespaces_options(:extra_group, display_path: true, extra_group: user_group)

        expect(options).to include("selected=\"selected\" value=\"#{user_group.id}\"")
        expect(options).to include(admin_group.name)
      end
    end

    it 'selects the new group by default' do
      # Ensure we don't select a group with the same name
      create(:group, name: 'new-group', path: 'another-path')

      allow(helper).to receive(:current_user).and_return(user)

      options = helper.namespaces_options(:extra_group, display_path: true, extra_group: build(:group, name: 'new-group', path: 'new-group'))

      expect(options).to include(user_group.name)
      expect(options).not_to include(admin_group.name)
      expect(options).to include("selected=\"selected\" value=\"-1\"")
    end

    it 'falls back to current user selection' do
      allow(helper).to receive(:current_user).and_return(user)

      options = helper.namespaces_options(:extra_group, display_path: true, extra_group: build(:group, name: admin_group.name))

      expect(options).to include(user_group.name)
      expect(options).not_to include(admin_group.name)
      expect(options).to include("selected=\"selected\" value=\"#{user.namespace.id}\"")
    end

    it 'returns only groups if groups_only option is true' do
      allow(helper).to receive(:current_user).and_return(user)

      options = helper.namespaces_options(nil, groups_only: true)

      expect(options).not_to include(user.name)
      expect(options).to include(user_group.name)
    end

    context 'when nested groups are available' do
      it 'includes groups nested in groups the user can administer' do
        allow(helper).to receive(:current_user).and_return(user)
        child_group = create(:group, :private, parent: user_group)

        options = helper.namespaces_options

        expect(options).to include(child_group.name)
      end

      it 'orders the groups correctly' do
        allow(helper).to receive(:current_user).and_return(user)
        child_group = create(:group, :private, parent: user_group)
        other_child = create(:group, :private, parent: user_group)
        sub_child = create(:group, :private, parent: child_group)

        expect(helper).to receive(:options_for_group)
                            .with([user_group, child_group, sub_child, other_child], anything)
                            .and_call_original
        allow(helper).to receive(:options_for_group).and_call_original

        helper.namespaces_options
      end
    end
  end

  describe '#cascading_namespace_settings_popover_data' do
    attribute = :delayed_project_removal

    subject do
      helper.cascading_namespace_settings_popover_data(
        attribute,
        subgroup1,
        -> (locked_ancestor) { edit_group_path(locked_ancestor, anchor: 'js-permissions-settings') }
      )
    end

    context 'when locked by an application setting' do
      before do
        allow(subgroup1.namespace_settings).to receive("#{attribute}_locked_by_application_setting?").and_return(true)
        allow(subgroup1.namespace_settings).to receive("#{attribute}_locked_by_ancestor?").and_return(false)
      end

      it 'returns expected hash' do
        expect(subject).to match({
          popover_data: {
            locked_by_application_setting: true,
            locked_by_ancestor: false
          }.to_json,
          testid: 'cascading-settings-lock-icon'
        })
      end
    end

    context 'when locked by an ancestor namespace' do
      before do
        allow(subgroup1.namespace_settings).to receive("#{attribute}_locked_by_application_setting?").and_return(false)
        allow(subgroup1.namespace_settings).to receive("#{attribute}_locked_by_ancestor?").and_return(true)
        allow(subgroup1.namespace_settings).to receive("#{attribute}_locked_ancestor").and_return(admin_group.namespace_settings)
      end

      it 'returns expected hash' do
        expect(subject).to match({
          popover_data: {
            locked_by_application_setting: false,
            locked_by_ancestor: true,
            ancestor_namespace: {
              full_name: admin_group.full_name,
              path: edit_group_path(admin_group, anchor: 'js-permissions-settings')
            }
          }.to_json,
          testid: 'cascading-settings-lock-icon'
        })
      end
    end
  end

  describe '#cascading_namespace_setting_locked?' do
    let(:attribute) { :delayed_project_removal }

    context 'when `group` argument is `nil`' do
      it 'returns `false`' do
        expect(helper.cascading_namespace_setting_locked?(attribute, nil)).to eq(false)
      end
    end

    context 'when `*_locked?` method does not exist' do
      it 'returns `false`' do
        expect(helper.cascading_namespace_setting_locked?(:attribute_that_does_not_exist, admin_group)).to eq(false)
      end
    end

    context 'when `*_locked?` method does exist' do
      before do
        allow(admin_group.namespace_settings).to receive(:delayed_project_removal_locked?).and_return(true)
      end

      it 'calls corresponding `*_locked?` method' do
        helper.cascading_namespace_setting_locked?(attribute, admin_group, include_self: true)

        expect(admin_group.namespace_settings).to have_received(:delayed_project_removal_locked?).with(include_self: true)
      end
    end
  end

  describe '#pipeline_usage_quota_app_data' do
    it 'returns a hash with necessary data for the frontend' do
      expect(helper.pipeline_usage_quota_app_data(user_group)).to eql({
        namespace_actual_plan_name: user_group.actual_plan_name,
        namespace_path: user_group.full_path,
        namespace_id: user_group.id,
        page_size: Kaminari.config.default_per_page
      })
    end
  end
end

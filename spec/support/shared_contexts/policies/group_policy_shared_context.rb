# frozen_string_literal: true

RSpec.shared_context 'GroupPolicy context' do
  let_it_be(:guest) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group, refind: true) { create(:group, :private, :owner_subgroup_creation_only) }

  let(:guest_permissions) do
    %i[
      read_label read_group upload_file read_namespace read_group_activity
      read_group_issues read_group_boards read_group_labels read_group_milestones
      read_group_merge_requests
   ]
  end
  let(:read_group_permissions) { %i[read_label read_list read_milestone] }
  let(:reporter_permissions) { %i[admin_label read_container_image] }
  let(:developer_permissions) { [:admin_milestone] }
  let(:maintainer_permissions) do
    %i[
      create_projects
      read_cluster create_cluster update_cluster admin_cluster add_cluster
    ]
  end
  let(:owner_permissions) do
    [
      :admin_group,
      :admin_namespace,
      :admin_group_member,
      :change_visibility_level,
      :set_note_created_at,
      :create_subgroup,
      :read_statistics
    ].compact
  end

  before_all do
    group.add_guest(guest)
    group.add_reporter(reporter)
    group.add_developer(developer)
    group.add_maintainer(maintainer)
    group.add_owner(owner)
  end

  subject { described_class.new(current_user, group) }
end

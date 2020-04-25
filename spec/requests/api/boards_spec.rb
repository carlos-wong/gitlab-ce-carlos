# frozen_string_literal: true

require 'spec_helper'

describe API::Boards do
  let_it_be(:user) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:board_parent, reload: true) { create(:project, :public, creator_id: user.id, namespace: user.namespace ) }

  let_it_be(:dev_label) do
    create(:label, title: 'Development', color: '#FFAABB', project: board_parent)
  end

  let_it_be(:test_label) do
    create(:label, title: 'Testing', color: '#FFAACC', project: board_parent)
  end

  let_it_be(:ux_label) do
    create(:label, title: 'UX', color: '#FF0000', project: board_parent)
  end

  let_it_be(:dev_list) do
    create(:list, label: dev_label, position: 1)
  end

  let_it_be(:test_list) do
    create(:list, label: test_label, position: 2)
  end

  let_it_be(:milestone) { create(:milestone, project: board_parent) }
  let_it_be(:board_label) { create(:label, project: board_parent) }
  let_it_be(:board) { create(:board, project: board_parent, lists: [dev_list, test_list]) }

  it_behaves_like 'group and project boards', "/projects/:id/boards"

  describe "POST /projects/:id/boards/lists" do
    let(:url) { "/projects/#{board_parent.id}/boards/#{board.id}/lists" }

    it 'creates a new issue board list for group labels' do
      group = create(:group)
      group_label = create(:group_label, group: group)
      board_parent.update(group: group)

      post api(url, user), params: { label_id: group_label.id }

      expect(response).to have_gitlab_http_status(201)
      expect(json_response['label']['name']).to eq(group_label.title)
      expect(json_response['position']).to eq(3)
    end

    it 'creates a new board list for ancestor group labels' do
      group = create(:group)
      sub_group = create(:group, parent: group)
      group_label = create(:group_label, group: group)
      board_parent.update(group: sub_group)
      group.add_developer(user)
      sub_group.add_developer(user)

      post api(url, user), params: { label_id: group_label.id }

      expect(response).to have_gitlab_http_status(201)
      expect(json_response['label']['name']).to eq(group_label.title)
    end
  end

  describe "POST /groups/:id/boards/lists" do
    let_it_be(:group) { create(:group) }
    let_it_be(:board_parent) { create(:group, parent: group ) }
    let(:url) { "/groups/#{board_parent.id}/boards/#{board.id}/lists" }

    let_it_be(:board) { create(:board, group: board_parent) }

    it 'creates a new board list for ancestor group labels' do
      group.add_developer(user)
      group_label = create(:group_label, group: group)

      post api(url, user), params: { label_id: group_label.id }

      expect(response).to have_gitlab_http_status(201)
      expect(json_response['label']['name']).to eq(group_label.title)
    end
  end
end

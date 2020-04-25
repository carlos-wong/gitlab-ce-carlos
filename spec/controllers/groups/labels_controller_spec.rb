# frozen_string_literal: true

require 'spec_helper'

describe Groups::LabelsController do
  let_it_be(:group) { create(:group) }
  let_it_be(:user)  { create(:user) }
  let_it_be(:project) { create(:project, namespace: group) }

  before do
    group.add_owner(user)

    sign_in(user)
  end

  describe 'GET #index' do
    let_it_be(:label_1) { create(:label, project: project, title: 'label_1') }
    let_it_be(:group_label_1) { create(:group_label, group: group, title: 'group_label_1') }

    it 'returns group and project labels by default' do
      get :index, params: { group_id: group }, format: :json

      label_ids = json_response.map {|label| label['title']}
      expect(label_ids).to match_array([label_1.title, group_label_1.title])
    end

    context 'with ancestor group' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:subgroup_label_1) { create(:group_label, group: subgroup, title: 'subgroup_label_1') }

      before do
        subgroup.add_owner(user)
      end

      it 'returns ancestor group labels' do
        get :index, params: { group_id: subgroup, include_ancestor_groups: true, only_group_labels: true }, format: :json

        label_ids = json_response.map {|label| label['title']}
        expect(label_ids).to match_array([group_label_1.title, subgroup_label_1.title])
      end
    end

    context 'external authorization' do
      subject { get :index, params: { group_id: group.to_param } }

      it_behaves_like 'disabled when using an external authorization service'
    end
  end

  describe 'POST #toggle_subscription' do
    it 'allows user to toggle subscription on group labels' do
      label = create(:group_label, group: group)

      post :toggle_subscription, params: { group_id: group.to_param, id: label.to_param }

      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end

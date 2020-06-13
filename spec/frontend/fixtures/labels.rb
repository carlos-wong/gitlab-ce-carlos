# frozen_string_literal: true

require 'spec_helper'

describe 'Labels (JavaScript fixtures)' do
  include JavaScriptFixturesHelpers

  let(:admin) { create(:admin) }
  let(:group) { create(:group, name: 'frontend-fixtures-group' )}
  let(:project) { create(:project_empty_repo, namespace: group, path: 'labels-project') }

  let!(:project_label_bug) { create(:label, project: project, title: 'bug', color: '#FF0000') }
  let!(:project_label_enhancement) { create(:label, project: project, title: 'enhancement', color: '#00FF00') }
  let!(:project_label_feature) { create(:label, project: project, title: 'feature', color: '#0000FF') }

  let!(:group_label_roses) { create(:group_label, group: group, title: 'roses', color: '#FF0000') }
  let!(:groub_label_space) { create(:group_label, group: group, title: 'some space', color: '#FFFFFF') }
  let!(:groub_label_violets) { create(:group_label, group: group, title: 'violets', color: '#0000FF') }

  before(:all) do
    clean_frontend_fixtures('labels/')
  end

  after do
    remove_repository(project)
  end

  describe Groups::LabelsController, '(JavaScript fixtures)', type: :controller do
    render_views

    before do
      sign_in(admin)
    end

    it 'labels/group_labels.json' do
      get :index, params: {
        group_id: group
      }, format: 'json'

      expect(response).to be_successful
    end
  end

  describe API::Helpers::LabelHelpers, type: :request do
    include JavaScriptFixturesHelpers
    include ApiHelpers

    let(:user) { create(:user) }

    before do
      group.add_owner(user)
    end

    it 'api/group_labels.json' do
      get api("/groups/#{group.id}/labels", user)

      expect(response).to be_successful
    end
  end

  describe Projects::LabelsController, '(JavaScript fixtures)', type: :controller do
    render_views

    before do
      sign_in(admin)
    end

    it 'labels/project_labels.json' do
      get :index, params: {
        namespace_id: group,
        project_id: project
      }, format: 'json'

      expect(response).to be_successful
    end
  end
end

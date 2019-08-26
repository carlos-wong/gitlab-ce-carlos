# frozen_string_literal: true

require 'spec_helper'

describe 'Project Activity RSS' do
  let(:project) { create(:project, :public) }
  let(:user) { project.owner }
  let(:path) { activity_project_path(project) }

  before do
    create(:issue, project: project)
  end

  context 'when signed in' do
    before do
      sign_in(project.owner)
      visit path
    end

    it_behaves_like "it has an RSS button with current_user's feed token"
  end

  context 'when signed out' do
    before do
      visit path
    end

    it_behaves_like "it has an RSS button without a feed token"
  end
end

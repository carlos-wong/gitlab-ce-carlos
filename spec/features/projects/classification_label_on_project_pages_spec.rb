# frozen_string_literal: true

require 'spec_helper'

describe 'Classification label on project pages' do
  let(:project) do
    create(:project, external_authorization_classification_label: 'authorized label')
  end
  let(:user) { create(:user) }

  before do
    stub_application_setting(external_authorization_service_enabled: true)
    project.add_maintainer(user)
    sign_in(user)
  end

  it 'shows the classification label on the project page' do
    visit project_path(project)

    expect(page).to have_content('authorized label')
  end
end

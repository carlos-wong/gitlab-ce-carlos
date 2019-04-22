require 'spec_helper'

describe Projects::BlobController, '(JavaScript fixtures)', type: :controller do
  include JavaScriptFixturesHelpers

  let(:admin) { create(:admin) }
  let(:namespace) { create(:namespace, name: 'frontend-fixtures' )}
  let(:project) { create(:project, :repository, namespace: namespace, path: 'branches-project') }

  render_views

  before(:all) do
    clean_frontend_fixtures('blob/')
  end

  before do
    sign_in(admin)
    allow(SecureRandom).to receive(:hex).and_return('securerandomhex:thereisnospoon')
  end

  after do
    remove_repository(project)
  end

  it 'blob/show.html' do |example|
    get(:show, params: {
      namespace_id: project.namespace,
      project_id: project,
      id: 'add-ipython-files/files/ipython/basic.ipynb'
    })

    expect(response).to be_success
    store_frontend_fixture(response, example.description)
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe 'Raw files', '(JavaScript fixtures)' do
  include JavaScriptFixturesHelpers

  let(:namespace) { create(:namespace, name: 'frontend-fixtures' )}
  let(:project) { create(:project, :repository, namespace: namespace, path: 'raw-project') }
  let(:response) { @blob.data.force_encoding('UTF-8') }

  before(:all) do
    clean_frontend_fixtures('blob/balsamiq/')
    clean_frontend_fixtures('blob/notebook/')
    clean_frontend_fixtures('blob/pdf/')
  end

  after do
    remove_repository(project)
  end

  it 'blob/balsamiq/test.bmpr' do
    @blob = project.repository.blob_at('b89b56d79', 'files/images/balsamiq.bmpr')
  end

  it 'blob/notebook/basic.json' do
    @blob = project.repository.blob_at('6d85bb69', 'files/ipython/basic.ipynb')
  end

  it 'blob/notebook/worksheets.json' do
    @blob = project.repository.blob_at('6d85bb69', 'files/ipython/worksheets.ipynb')
  end

  it 'blob/notebook/math.json' do
    @blob = project.repository.blob_at('93ee732', 'files/ipython/math.ipynb')
  end

  it 'blob/pdf/test.pdf' do
    @blob = project.repository.blob_at('e774ebd33', 'files/pdf/test.pdf')
  end
end

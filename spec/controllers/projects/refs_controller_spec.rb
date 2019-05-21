# frozen_string_literal: true

require 'spec_helper'

describe Projects::RefsController do
  let(:project) { create(:project, :repository) }
  let(:user)    { create(:user) }

  before do
    sign_in(user)
    project.add_developer(user)
  end

  describe 'GET #logs_tree' do
    def default_get(format = :html)
      get :logs_tree,
          params: {
            namespace_id: project.namespace.to_param,
            project_id: project,
            id: 'master',
            path: 'foo/bar/baz.html'
          },
          format: format
    end

    def xhr_get(format = :html)
      get :logs_tree, params: {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: 'master',
        path: 'foo/bar/baz.html',
        format: format
      }, xhr: true
    end

    it 'never throws MissingTemplate' do
      expect { default_get }.not_to raise_error
      expect { xhr_get(:json) }.not_to raise_error
      expect { xhr_get }.not_to raise_error
    end

    it 'renders 404 for non-JS requests' do
      xhr_get

      expect(response).to be_not_found
    end

    it 'renders JS' do
      expect(::Gitlab::GitalyClient).to receive(:allow_ref_name_caching).and_call_original

      xhr_get(:js)
      expect(response).to be_success
    end

    it 'renders JSON' do
      expect(::Gitlab::GitalyClient).to receive(:allow_ref_name_caching).and_call_original

      xhr_get(:json)

      expect(response).to be_success
      expect(json_response).to be_kind_of(Array)
    end
  end
end

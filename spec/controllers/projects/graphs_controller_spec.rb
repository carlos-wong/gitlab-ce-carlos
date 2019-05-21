# frozen_string_literal: true

require 'spec_helper'

describe Projects::GraphsController do
  let(:project) { create(:project, :repository) }
  let(:user)    { create(:user) }

  before do
    sign_in(user)
    project.add_maintainer(user)
  end

  describe 'GET languages' do
    it "redirects_to action charts" do
      get(:commits, params: { namespace_id: project.namespace.path, project_id: project.path, id: 'master' })

      expect(response).to redirect_to action: :charts
    end
  end

  describe 'GET commits' do
    it "redirects_to action charts" do
      get(:commits, params: { namespace_id: project.namespace.path, project_id: project.path, id: 'master' })

      expect(response).to redirect_to action: :charts
    end
  end

  describe 'charts' do
    context 'when languages were previously detected' do
      let(:project) { create(:project, :repository, detected_repository_languages: true) }
      let!(:repository_language) { create(:repository_language, project: project) }

      it 'sets the languages properly' do
        get(:charts, params: { namespace_id: project.namespace.path, project_id: project.path, id: 'master' })

        expect(assigns[:languages]).to eq(
          [value: repository_language.share,
           label: repository_language.name,
           color: repository_language.color,
           highlight: repository_language.color])
      end
    end
  end
end

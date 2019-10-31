# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "projects/artifacts/_artifact.html.haml" do
  let(:project) { create(:project) }

  describe 'delete button' do
    before do
      create(:ci_build, :artifacts, project: project)

      allow(view).to receive(:current_user).and_return(user)
      assign(:project, project)
    end

    context 'with admin' do
      let(:user) { build(:admin) }

      it 'has a delete button' do
        render_partial

        expect(rendered).to have_link('Delete artifacts', href: project_artifact_path(project, project.job_artifacts.first))
      end
    end

    context 'with owner' do
      let(:user) { create(:user) }
      let(:project) { build(:project, namespace: user.namespace) }

      it 'has a delete button' do
        render_partial

        expect(rendered).to have_link('Delete artifacts', href: project_artifact_path(project, project.job_artifacts.first))
      end
    end

    context 'with master' do
      let(:user) { create(:user) }

      it 'has a delete button' do
        allow_any_instance_of(ProjectTeam).to receive(:max_member_access).and_return(Gitlab::Access::MASTER)
        render_partial

        expect(rendered).to have_link('Delete artifacts', href: project_artifact_path(project, project.job_artifacts.first))
      end
    end

    context 'with developer' do
      let(:user) { build(:user) }

      it 'has no delete button' do
        project.add_developer(user)
        render_partial

        expect(rendered).not_to have_link('Delete artifacts')
      end
    end

    context 'with reporter' do
      let(:user) { build(:user) }

      it 'has no delete button' do
        project.add_reporter(user)
        render_partial

        expect(rendered).not_to have_link('Delete artifacts')
      end
    end
  end

  def render_partial
    render partial: 'projects/artifacts/artifact', collection: project.job_artifacts, as: :artifact
  end
end

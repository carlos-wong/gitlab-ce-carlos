# frozen_string_literal: true

require 'spec_helper'

describe Projects::RunnersController do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:runner) { create(:ci_runner, :project, projects: [project]) }

  let(:params) do
    {
      namespace_id: project.namespace,
      project_id: project,
      id: runner
    }
  end

  before do
    sign_in(user)
    project.add_maintainer(user)
  end

  describe '#update' do
    it 'updates the runner and ticks the queue' do
      new_desc = runner.description.swapcase

      expect do
        post :update, params: params.merge(runner: { description: new_desc } )
      end.to change { runner.ensure_runner_queue_value }

      runner.reload

      expect(response).to have_gitlab_http_status(:found)
      expect(runner.description).to eq(new_desc)
    end
  end

  describe '#destroy' do
    it 'destroys the runner' do
      delete :destroy, params: params

      expect(response).to have_gitlab_http_status(:found)
      expect(Ci::Runner.find_by(id: runner.id)).to be_nil
    end
  end

  describe '#resume' do
    it 'marks the runner as active and ticks the queue' do
      runner.update(active: false)

      expect do
        post :resume, params: params
      end.to change { runner.ensure_runner_queue_value }

      runner.reload

      expect(response).to have_gitlab_http_status(:found)
      expect(runner.active).to eq(true)
    end
  end

  describe '#pause' do
    it 'marks the runner as inactive and ticks the queue' do
      runner.update(active: true)

      expect do
        post :pause, params: params
      end.to change { runner.ensure_runner_queue_value }

      runner.reload

      expect(response).to have_gitlab_http_status(:found)
      expect(runner.active).to eq(false)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe Admin::RunnersController do
  let_it_be(:runner) { create(:ci_runner) }

  before do
    sign_in(create(:admin))
  end

  describe '#index' do
    render_views

    it 'lists all runners' do
      get :index

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'avoids N+1 queries', :request_store do
      get :index

      control_count = ActiveRecord::QueryRecorder.new { get :index }.count

      create_list(:ci_runner, 5, :tagged_only)

      # There is still an N+1 query for `runner.builds.count`
      # We also need to add 1 because it takes 2 queries to preload tags
      expect { get :index }.not_to exceed_query_limit(control_count + 6)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to have_content('tag1')
      expect(response.body).to have_content('tag2')
    end
  end

  describe '#show' do
    render_views

    let_it_be(:project) { create(:project) }
    let_it_be(:project_two) { create(:project) }

    before_all do
      create(:ci_build, runner: runner, project: project)
      create(:ci_build, runner: runner, project: project_two)
    end

    it 'shows a particular runner' do
      get :show, params: { id: runner.id }

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'shows 404 for unknown runner' do
      get :show, params: { id: 0 }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'avoids N+1 queries', :request_store do
      get :show, params: { id: runner.id }

      control_count = ActiveRecord::QueryRecorder.new { get :show, params: { id: runner.id } }.count

      new_project = create(:project)
      create(:ci_build, runner: runner, project: new_project)

      # There is one additional query looking up subject.group in ProjectPolicy for the
      # needs_new_sso_session permission
      expect { get :show, params: { id: runner.id } }.not_to exceed_query_limit(control_count + 1)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe '#update' do
    it 'updates the runner and ticks the queue' do
      new_desc = runner.description.swapcase

      expect do
        post :update, params: { id: runner.id, runner: { description: new_desc } }
      end.to change { runner.ensure_runner_queue_value }

      runner.reload

      expect(response).to have_gitlab_http_status(:found)
      expect(runner.description).to eq(new_desc)
    end
  end

  describe '#destroy' do
    it 'destroys the runner' do
      delete :destroy, params: { id: runner.id }

      expect(response).to have_gitlab_http_status(:found)
      expect(Ci::Runner.find_by(id: runner.id)).to be_nil
    end
  end

  describe '#resume' do
    it 'marks the runner as active and ticks the queue' do
      runner.update(active: false)

      expect do
        post :resume, params: { id: runner.id }
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
        post :pause, params: { id: runner.id }
      end.to change { runner.ensure_runner_queue_value }

      runner.reload

      expect(response).to have_gitlab_http_status(:found)
      expect(runner.active).to eq(false)
    end
  end
end

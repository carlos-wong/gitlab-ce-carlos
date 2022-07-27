# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Query.project.jobs' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:user) { create(:user) }

  let(:pipeline) do
    create(:ci_pipeline, project: project, user: user)
  end

  let(:query) do
    <<~QUERY
    {
      project(fullPath: "#{project.full_path}") {
        jobs {
          nodes {
            name
            previousStageJobsAndNeeds {
              nodes {
                name
              }
            }
          }
        }
      }
    }
    QUERY
  end

  it 'does not generate N+1 queries', :request_store, :use_sql_query_cache do
    build_stage = create(:ci_stage, position: 1, name: 'build', project: project, pipeline: pipeline)
    test_stage = create(:ci_stage, position: 2, name: 'test', project: project, pipeline: pipeline)
    create(:ci_build, pipeline: pipeline, stage_idx: build_stage.position, name: 'docker 1 2', stage: build_stage)
    create(:ci_build, pipeline: pipeline, stage_idx: build_stage.position, name: 'docker 2 2', stage: build_stage)
    create(:ci_build, pipeline: pipeline, stage_idx: test_stage.position, name: 'rspec 1 2', stage: test_stage)
    test_job = create(:ci_build, pipeline: pipeline, stage_idx: test_stage.position, name: 'rspec 2 2', stage: test_stage)
    create(:ci_build_need, build: test_job, name: 'docker 1 2')

    post_graphql(query, current_user: user)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(query, current_user: user)
    end

    create(:ci_build, name: 'test-a', stage: test_stage, stage_idx: test_stage.position, pipeline: pipeline)
    test_b_job = create(:ci_build, name: 'test-b', stage: test_stage, stage_idx: test_stage.position, pipeline: pipeline)
    create(:ci_build_need, build: test_b_job, name: 'docker 2 2')

    expect do
      post_graphql(query, current_user: user)
    end.not_to exceed_all_query_limit(control)
  end
end

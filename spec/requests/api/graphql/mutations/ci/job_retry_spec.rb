# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JobRetry' do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: user) }

  let(:job) { create(:ci_build, :success, pipeline: pipeline, name: 'build') }

  let(:mutation) do
    variables = {
      id: job.to_global_id.to_s
    }
    graphql_mutation(:job_retry, variables,
                     <<-QL
                       errors
                       job {
                         id
                       }
                     QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:job_retry) }

  before_all do
    project.add_maintainer(user)
  end

  it 'returns an error if the user is not allowed to retry the job' do
    post_graphql_mutation(mutation, current_user: create(:user))

    expect(graphql_errors).not_to be_empty
  end

  it 'retries a job' do
    post_graphql_mutation(mutation, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    new_job_id = GitlabSchema.object_from_id(mutation_response['job']['id']).sync.id

    new_job = ::Ci::Build.find(new_job_id)
    expect(new_job).not_to be_retried
  end

  context 'when the job is not retryable' do
    let(:job) { create(:ci_build, :retried, pipeline: pipeline) }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(mutation_response['job']).to be(nil)
      expect(mutation_response['errors']).to match_array(['Job cannot be retried'])
    end
  end
end

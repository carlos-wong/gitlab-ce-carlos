# frozen_string_literal: true

require 'spec_helper'

describe 'Deleting Sidekiq jobs', :clean_gitlab_redis_queues do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }

  let(:variables) { { user: admin.username, queue_name: 'authorized_projects' } }
  let(:mutation) { graphql_mutation(:admin_sidekiq_queues_delete_jobs, variables) }

  def mutation_response
    graphql_mutation_response(:admin_sidekiq_queues_delete_jobs)
  end

  context 'when the user is not an admin' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns top-level errors',
                    errors: ['You must be an admin to use this mutation']
  end

  context 'when the user is an admin' do
    let(:current_user) { admin }

    context 'valid request' do
      around do |example|
        Sidekiq::Queue.new('authorized_projects').clear
        Sidekiq::Testing.disable!(&example)
        Sidekiq::Queue.new('authorized_projects').clear
      end

      def add_job(user, args)
        Sidekiq::Client.push(
          'class' => 'AuthorizedProjectsWorker',
          'queue' => 'authorized_projects',
          'args' => args,
          'meta.user' => user.username
        )
      end

      it 'returns info about the deleted jobs' do
        add_job(admin, [1])
        add_job(admin, [2])
        add_job(create(:user), [3])

        post_graphql_mutation(mutation, current_user: admin)

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['result']).to eq('completed' => true,
                                                  'deletedJobs' => 2,
                                                  'queueSize' => 1)
      end
    end

    context 'when no required params are provided' do
      let(:variables) { { queue_name: 'authorized_projects' } }

      it_behaves_like 'a mutation that returns errors in the response',
                      errors: ['No metadata provided']
    end

    context 'when the queue does not exist' do
      let(:variables) { { user: admin.username, queue_name: 'authorized_projects_2' } }

      it_behaves_like 'a mutation that returns top-level errors',
                      errors: ['Queue authorized_projects_2 not found']
    end
  end
end

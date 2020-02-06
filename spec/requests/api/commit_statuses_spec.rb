# frozen_string_literal: true

require 'spec_helper'

describe API::CommitStatuses do
  let!(:project) { create(:project, :repository) }
  let(:commit) { project.repository.commit }
  let(:guest) { create_user(:guest) }
  let(:reporter) { create_user(:reporter) }
  let(:developer) { create_user(:developer) }
  let(:sha) { commit.id }

  describe "GET /projects/:id/repository/commits/:sha/statuses" do
    let(:get_url) { "/projects/#{project.id}/repository/commits/#{sha}/statuses" }

    context 'ci commit exists' do
      let!(:master) { project.ci_pipelines.create(source: :push, sha: commit.id, ref: 'master', protected: false) }
      let!(:develop) { project.ci_pipelines.create(source: :push, sha: commit.id, ref: 'develop', protected: false) }

      context "reporter user" do
        let(:statuses_id) { json_response.map { |status| status['id'] } }

        def create_status(commit, opts = {})
          create(:commit_status, { pipeline: commit, ref: commit.ref }.merge(opts))
        end

        let!(:status1) { create_status(master, status: 'running', retried: true) }
        let!(:status2) { create_status(master, name: 'coverage', status: 'pending', retried: true) }
        let!(:status3) { create_status(develop, status: 'running', allow_failure: true) }
        let!(:status4) { create_status(master, name: 'coverage', status: 'success') }
        let!(:status5) { create_status(develop, name: 'coverage', status: 'success') }
        let!(:status6) { create_status(master, status: 'success') }

        context 'latest commit statuses' do
          before do
            get api(get_url, reporter)
          end

          it 'returns latest commit statuses' do
            expect(response).to have_gitlab_http_status(200)

            expect(response).to include_pagination_headers
            expect(json_response).to be_an Array
            expect(statuses_id).to contain_exactly(status3.id, status4.id, status5.id, status6.id)
            json_response.sort_by! { |status| status['id'] }
            expect(json_response.map { |status| status['allow_failure'] }).to eq([true, false, false, false])
          end
        end

        context 'all commit statuses' do
          before do
            get api(get_url, reporter), params: { all: 1 }
          end

          it 'returns all commit statuses' do
            expect(response).to have_gitlab_http_status(200)
            expect(response).to include_pagination_headers
            expect(json_response).to be_an Array
            expect(statuses_id).to contain_exactly(status1.id, status2.id,
                                                   status3.id, status4.id,
                                                   status5.id, status6.id)
          end
        end

        context 'latest commit statuses for specific ref' do
          before do
            get api(get_url, reporter), params: { ref: 'develop' }
          end

          it 'returns latest commit statuses for specific ref' do
            expect(response).to have_gitlab_http_status(200)
            expect(response).to include_pagination_headers
            expect(json_response).to be_an Array
            expect(statuses_id).to contain_exactly(status3.id, status5.id)
          end
        end

        context 'latest commit statues for specific name' do
          before do
            get api(get_url, reporter), params: { name: 'coverage' }
          end

          it 'return latest commit statuses for specific name' do
            expect(response).to have_gitlab_http_status(200)
            expect(response).to include_pagination_headers
            expect(json_response).to be_an Array
            expect(statuses_id).to contain_exactly(status4.id, status5.id)
          end
        end
      end
    end

    context 'ci commit does not exist' do
      before do
        get api(get_url, reporter)
      end

      it 'returns empty array' do
        expect(response.status).to eq 200
        expect(json_response).to be_an Array
        expect(json_response).to be_empty
      end
    end

    context "guest user" do
      before do
        get api(get_url, guest)
      end

      it "does not return project commits" do
        expect(response).to have_gitlab_http_status(403)
      end
    end

    context "unauthorized user" do
      before do
        get api(get_url)
      end

      it "does not return project commits" do
        expect(response).to have_gitlab_http_status(401)
      end
    end
  end

  describe 'POST /projects/:id/statuses/:sha' do
    let(:post_url) { "/projects/#{project.id}/statuses/#{sha}" }

    context 'developer user' do
      context 'uses only required parameters' do
        %w[pending running success failed canceled].each do |status|
          context "for #{status}" do
            context 'when pipeline for sha does not exists' do
              it 'creates commit status' do
                post api(post_url, developer), params: { state: status }

                expect(response).to have_gitlab_http_status(201)
                expect(json_response['sha']).to eq(commit.id)
                expect(json_response['status']).to eq(status)
                expect(json_response['name']).to eq('default')
                expect(json_response['ref']).not_to be_empty
                expect(json_response['target_url']).to be_nil
                expect(json_response['description']).to be_nil

                if status == 'failed'
                  expect(CommitStatus.find(json_response['id'])).to be_api_failure
                end
              end
            end
          end
        end

        context 'when pipeline already exists for the specified sha' do
          let!(:pipeline) { create(:ci_pipeline, project: project, sha: sha, ref: 'ref') }
          let(:params) { { state: 'pending' } }

          shared_examples_for 'creates a commit status for the existing pipeline' do
            it do
              expect do
                post api(post_url, developer), params: params
              end.not_to change { Ci::Pipeline.count }

              job = pipeline.statuses.find_by_name(json_response['name'])

              expect(response).to have_gitlab_http_status(201)
              expect(job.status).to eq('pending')
              expect(job.stage_idx).to eq(GenericCommitStatus::EXTERNAL_STAGE_IDX)
            end
          end

          it_behaves_like 'creates a commit status for the existing pipeline'

          context 'with pipeline for merge request' do
            let!(:merge_request) { create(:merge_request, :with_detached_merge_request_pipeline, source_project: project) }
            let!(:pipeline) { merge_request.all_pipelines.last }
            let(:sha) { pipeline.sha }

            it_behaves_like 'creates a commit status for the existing pipeline'
          end
        end
      end

      context 'transitions status from pending' do
        before do
          post api(post_url, developer), params: { state: 'pending' }
        end

        %w[running success failed canceled].each do |status|
          it "to #{status}" do
            expect { post api(post_url, developer), params: { state: status } }.not_to change { CommitStatus.count }

            expect(response).to have_gitlab_http_status(201)
            expect(json_response['status']).to eq(status)
          end
        end
      end

      context 'with all optional parameters' do
        context 'when creating a commit status' do
          subject do
            post api(post_url, developer), params: {
              state: 'success',
              context: 'coverage',
              ref: 'master',
              description: 'test',
              coverage: 80.0,
              target_url: 'http://gitlab.com/status'
            }
          end

          it 'creates commit status' do
            subject

            expect(response).to have_gitlab_http_status(201)
            expect(json_response['sha']).to eq(commit.id)
            expect(json_response['status']).to eq('success')
            expect(json_response['name']).to eq('coverage')
            expect(json_response['ref']).to eq('master')
            expect(json_response['coverage']).to eq(80.0)
            expect(json_response['description']).to eq('test')
            expect(json_response['target_url']).to eq('http://gitlab.com/status')
          end

          context 'when merge request exists for given branch' do
            let!(:merge_request) { create(:merge_request, source_project: project, source_branch: 'master', target_branch: 'develop') }

            it 'sets head pipeline' do
              subject

              expect(response).to have_gitlab_http_status(201)
              expect(merge_request.reload.head_pipeline).not_to be_nil
            end
          end
        end

        context 'when updatig a commit status' do
          before do
            post api(post_url, developer), params: {
              state: 'running',
              context: 'coverage',
              ref: 'master',
              description: 'coverage test',
              coverage: 0.0,
              target_url: 'http://gitlab.com/status'
            }

            post api(post_url, developer), params: {
              state: 'success',
              name: 'coverage',
              ref: 'master',
              description: 'new description',
              coverage: 90.0
            }
          end

          it 'updates a commit status' do
            expect(response).to have_gitlab_http_status(201)
            expect(json_response['sha']).to eq(commit.id)
            expect(json_response['status']).to eq('success')
            expect(json_response['name']).to eq('coverage')
            expect(json_response['ref']).to eq('master')
            expect(json_response['coverage']).to eq(90.0)
            expect(json_response['description']).to eq('new description')
            expect(json_response['target_url']).to eq('http://gitlab.com/status')
          end

          it 'does not create a new commit status' do
            expect(CommitStatus.count).to eq 1
          end
        end

        context 'when a pipeline id is specified' do
          let!(:first_pipeline) { project.ci_pipelines.create(source: :push, sha: commit.id, ref: 'master', status: 'created') }
          let!(:other_pipeline) { project.ci_pipelines.create(source: :push, sha: commit.id, ref: 'master', status: 'created') }

          subject do
            post api(post_url, developer), params: {
              pipeline_id: other_pipeline.id,
              state: 'success',
              ref: 'master'
            }
          end

          it 'update the correct pipeline', :sidekiq_might_not_need_inline do
            subject

            expect(first_pipeline.reload.status).to eq('created')
            expect(other_pipeline.reload.status).to eq('success')
          end
        end
      end

      context 'when retrying a commit status' do
        before do
          post api(post_url, developer),
            params: { state: 'failed', name: 'test', ref: 'master' }

          post api(post_url, developer),
            params: { state: 'success', name: 'test', ref: 'master' }
        end

        it 'correctly posts a new commit status' do
          expect(response).to have_gitlab_http_status(201)
          expect(json_response['sha']).to eq(commit.id)
          expect(json_response['status']).to eq('success')
        end

        it 'retries a commit status', :sidekiq_might_not_need_inline do
          expect(CommitStatus.count).to eq 2
          expect(CommitStatus.first).to be_retried
          expect(CommitStatus.last.pipeline).to be_success
        end
      end

      context 'when status is invalid' do
        before do
          post api(post_url, developer), params: { state: 'invalid' }
        end

        it 'does not create commit status' do
          expect(response).to have_gitlab_http_status(400)
        end
      end

      context 'when request without a state made' do
        before do
          post api(post_url, developer)
        end

        it 'does not create commit status' do
          expect(response).to have_gitlab_http_status(400)
        end
      end

      context 'when updating a protected ref' do
        before do
          create(:protected_branch, project: project, name: 'master')
          post api(post_url, user), params: { state: 'running', ref: 'master' }
        end

        context 'with user as developer' do
          let(:user) { developer }

          it 'does not create commit status' do
            expect(response).to have_gitlab_http_status(403)
          end
        end

        context 'with user as maintainer' do
          let(:user) { create_user(:maintainer) }

          it 'creates commit status' do
            expect(response).to have_gitlab_http_status(201)
          end
        end
      end

      context 'when commit SHA is invalid' do
        let(:sha) { 'invalid_sha' }

        before do
          post api(post_url, developer), params: { state: 'running' }
        end

        it 'returns not found error' do
          expect(response).to have_gitlab_http_status(404)
        end
      end

      context 'when target URL is an invalid address' do
        before do
          post api(post_url, developer), params: {
                                           state: 'pending',
                                           target_url: 'invalid url'
                                         }
        end

        it 'responds with bad request status and validation errors' do
          expect(response).to have_gitlab_http_status(400)
          expect(json_response['message']['target_url'])
            .to include 'is blocked: Only allowed schemes are http, https'
        end
      end

      context 'when target URL is an unsupported scheme' do
        before do
          post api(post_url, developer), params: {
                                           state: 'pending',
                                           target_url: 'git://example.com'
                                         }
        end

        it 'responds with bad request status and validation errors' do
          expect(response).to have_gitlab_http_status(400)
          expect(json_response['message']['target_url'])
              .to include 'is blocked: Only allowed schemes are http, https'
        end
      end

      context 'when trying to update a status of a different type' do
        let!(:pipeline) { create(:ci_pipeline, project: project, sha: sha, ref: 'ref') }
        let!(:ci_build) { create(:ci_build, pipeline: pipeline, name: 'test-job') }
        let(:params) { { state: 'pending', name: 'test-job' } }

        before do
          post api(post_url, developer), params: params
        end

        it 'responds with bad request status and validation errors' do
          expect(response).to have_gitlab_http_status(400)
          expect(json_response['message']['name'])
              .to include 'has already been taken'
        end
      end
    end

    context 'reporter user' do
      before do
        post api(post_url, reporter), params: { state: 'running' }
      end

      it 'does not create commit status' do
        expect(response).to have_gitlab_http_status(403)
      end
    end

    context 'guest user' do
      before do
        post api(post_url, guest), params: { state: 'running' }
      end

      it 'does not create commit status' do
        expect(response).to have_gitlab_http_status(403)
      end
    end

    context 'unauthorized user' do
      before do
        post api(post_url)
      end

      it 'does not create commit status' do
        expect(response).to have_gitlab_http_status(401)
      end
    end
  end

  def create_user(access_level_trait)
    user = create(:user)
    create(:project_member, access_level_trait, user: user, project: project)
    user
  end
end

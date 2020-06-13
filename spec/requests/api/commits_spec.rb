# frozen_string_literal: true

require 'spec_helper'
require 'mime/types'

describe API::Commits do
  include ProjectForksHelper

  let(:user) { create(:user) }
  let(:guest) { create(:user).tap { |u| project.add_guest(u) } }
  let(:developer) { create(:user).tap { |u| project.add_developer(u) } }
  let(:project) { create(:project, :repository, creator: user, path: 'my.project') }
  let(:branch_with_dot) { project.repository.find_branch('ends-with.json') }
  let(:branch_with_slash) { project.repository.find_branch('improve/awesome') }
  let(:project_id) { project.id }
  let(:current_user) { nil }

  before do
    project.add_maintainer(user)
  end

  describe 'GET /projects/:id/repository/commits' do
    let(:route) { "/projects/#{project_id}/repository/commits" }

    shared_examples_for 'project commits' do |schema: 'public_api/v4/commits'|
      it "returns project commits" do
        commit = project.repository.commit

        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema(schema)
        expect(json_response.first['id']).to eq(commit.id)
        expect(json_response.first['committer_name']).to eq(commit.committer_name)
        expect(json_response.first['committer_email']).to eq(commit.committer_email)
      end

      it 'include correct pagination headers' do
        commit_count = project.repository.count_commits(ref: 'master').to_s

        get api(route, current_user)

        expect(response).to include_pagination_headers
        expect(response.headers['X-Total']).to eq(commit_count)
        expect(response.headers['X-Page']).to eql('1')
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'project commits'
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'project commits'

      context "since optional parameter" do
        it "returns project commits since provided parameter" do
          commits = project.repository.commits("master", limit: 2)
          after = commits.second.created_at

          get api("/projects/#{project_id}/repository/commits?since=#{after.utc.iso8601}", user)

          expect(json_response.size).to eq 2
          expect(json_response.first["id"]).to eq(commits.first.id)
          expect(json_response.second["id"]).to eq(commits.second.id)
        end

        it 'include correct pagination headers' do
          commits = project.repository.commits("master", limit: 2)
          after = commits.second.created_at
          commit_count = project.repository.count_commits(ref: 'master', after: after).to_s

          get api("/projects/#{project_id}/repository/commits?since=#{after.utc.iso8601}", user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(commit_count)
          expect(response.headers['X-Page']).to eql('1')
        end
      end

      context "until optional parameter" do
        it "returns project commits until provided parameter" do
          commits = project.repository.commits("master", limit: 20)
          before = commits.second.created_at

          get api("/projects/#{project_id}/repository/commits?until=#{before.utc.iso8601}", user)

          if commits.size == 20
            expect(json_response.size).to eq(20)
          else
            expect(json_response.size).to eq(commits.size - 1)
          end

          expect(json_response.first["id"]).to eq(commits.second.id)
          expect(json_response.second["id"]).to eq(commits.third.id)
        end

        it 'include correct pagination headers' do
          commits = project.repository.commits("master", limit: 2)
          before = commits.second.created_at
          commit_count = project.repository.count_commits(ref: 'master', before: before).to_s

          get api("/projects/#{project_id}/repository/commits?until=#{before.utc.iso8601}", user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(commit_count)
          expect(response.headers['X-Page']).to eql('1')
        end
      end

      context "invalid xmlschema date parameters" do
        it "returns an invalid parameter error message" do
          get api("/projects/#{project_id}/repository/commits?since=invalid-date", user)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('since is invalid')
        end
      end

      context "with empty ref_name parameter" do
        let(:route) { "/projects/#{project_id}/repository/commits?ref_name=" }

        it_behaves_like 'project commits'
      end

      context "path optional parameter" do
        it "returns project commits matching provided path parameter" do
          path = 'files/ruby/popen.rb'
          commit_count = project.repository.count_commits(ref: 'master', path: path).to_s

          get api("/projects/#{project_id}/repository/commits?path=#{path}", user)

          expect(json_response.size).to eq(3)
          expect(json_response.first["id"]).to eq("570e7b2abdd848b95f2f578043fc23bd6f6fd24d")
          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(commit_count)
        end

        it 'include correct pagination headers' do
          path = 'files/ruby/popen.rb'
          commit_count = project.repository.count_commits(ref: 'master', path: path).to_s

          get api("/projects/#{project_id}/repository/commits?path=#{path}", user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(commit_count)
          expect(response.headers['X-Page']).to eql('1')
        end
      end

      context 'all optional parameter' do
        it 'returns all project commits' do
          commit_count = project.repository.count_commits(all: true)

          get api("/projects/#{project_id}/repository/commits?all=true", user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(commit_count.to_s)
          expect(response.headers['X-Page']).to eql('1')
        end
      end

      context 'first_parent optional parameter' do
        it 'returns all first_parent commits' do
          commit_count = project.repository.count_commits(ref: SeedRepo::Commit::ID, first_parent: true)

          get api("/projects/#{project_id}/repository/commits", user), params: { ref_name: SeedRepo::Commit::ID, first_parent: 'true' }

          expect(response).to include_pagination_headers
          expect(commit_count).to eq(12)
          expect(response.headers['X-Total']).to eq(commit_count.to_s)
        end
      end

      context 'with_stats optional parameter' do
        let(:project) { create(:project, :public, :repository) }

        it_behaves_like 'project commits', schema: 'public_api/v4/commits_with_stats' do
          let(:route) { "/projects/#{project_id}/repository/commits?with_stats=true" }

          it 'include commits details' do
            commit = project.repository.commit
            get api(route, current_user)

            expect(json_response.first['stats']['additions']).to eq(commit.stats.additions)
            expect(json_response.first['stats']['deletions']).to eq(commit.stats.deletions)
            expect(json_response.first['stats']['total']).to eq(commit.stats.total)
          end
        end
      end

      context 'with pagination params' do
        let(:page) { 1 }
        let(:per_page) { 5 }
        let(:ref_name) { 'master' }
        let!(:request) do
          get api("/projects/#{project_id}/repository/commits?page=#{page}&per_page=#{per_page}&ref_name=#{ref_name}", user)
        end

        it 'returns correct headers' do
          commit_count = project.repository.count_commits(ref: ref_name).to_s

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(commit_count)
          expect(response.headers['X-Page']).to eq('1')
          expect(response.headers['Link']).to match(/page=1&per_page=5/)
          expect(response.headers['Link']).to match(/page=2&per_page=5/)
        end

        context 'viewing the first page' do
          it 'returns the first 5 commits' do
            commit = project.repository.commit

            expect(json_response.size).to eq(per_page)
            expect(json_response.first['id']).to eq(commit.id)
            expect(response.headers['X-Page']).to eq('1')
          end
        end

        context 'viewing the third page' do
          let(:page) { 3 }

          it 'returns the third 5 commits' do
            commit = project.repository.commits('HEAD', limit: per_page, offset: (page - 1) * per_page).first

            expect(json_response.size).to eq(per_page)
            expect(json_response.first['id']).to eq(commit.id)
            expect(response.headers['X-Page']).to eq('3')
          end
        end
      end

      context 'with order parameter' do
        let(:route) { "/projects/#{project_id}/repository/commits?ref_name=0031876&per_page=6&order=#{order}" }

        context 'set to topo' do
          let(:order) { 'topo' }

          # git log --graph -n 6 --pretty=format:"%h" --topo-order 0031876
          # *   0031876
          # |\
          # | * 48ca272
          # | * 335bc94
          # * | bf6e164
          # * | 9d526f8
          # |/
          # * 1039376
          it 'returns project commits ordered by topo order' do
            commits = project.repository.commits("0031876", limit: 6, order: 'topo')

            get api(route, current_user)

            expect(json_response.size).to eq(6)
            expect(json_response.map { |entry| entry["id"] }).to eq(commits.map(&:id))
          end
        end

        context 'set to default' do
          let(:order) { 'default' }

          # git log --graph -n 6 --pretty=format:"%h" --date-order 0031876
          # *   0031876
          # |\
          # * | bf6e164
          # | * 48ca272
          # * | 9d526f8
          # | * 335bc94
          # |/
          # * 1039376
          it 'returns project commits ordered by default order' do
            commits = project.repository.commits("0031876", limit: 6, order: 'default')

            get api(route, current_user)

            expect(json_response.size).to eq(6)
            expect(json_response.map { |entry| entry["id"] }).to eq(commits.map(&:id))
          end
        end

        context 'set to an invalid parameter' do
          let(:order) { 'invalid' }

          it_behaves_like '400 response' do
            let(:request) { get api(route, current_user) }
          end
        end
      end
    end
  end

  describe "POST /projects/:id/repository/commits" do
    let!(:url) { "/projects/#{project_id}/repository/commits" }

    it 'returns a 403 unauthorized for user without permissions' do
      post api(url, guest)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns a 400 bad request if no params are given' do
      post api(url, user)

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    describe 'create' do
      let(:message) { 'Created a new file with a very very looooooooooooooooooooooooooooooooooooooooooooooong commit message' }
      let(:invalid_c_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'create',
              file_path: 'files/ruby/popen.rb',
              content: 'puts 8'
            }
          ]
        }
      end
      let(:valid_c_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'create',
              file_path: 'foo/bar/baz.txt',
              content: 'puts 8'
            }
          ]
        }
      end
      let(:valid_utf8_c_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'create',
              file_path: 'foo/bar/baz.txt',
              content: 'puts 🦊'
            }
          ]
        }
      end

      it 'does not increment the usage counters using access token authentication' do
        expect(::Gitlab::UsageDataCounters::WebIdeCounter).not_to receive(:increment_commits_count)

        post api(url, user), params: valid_c_params
      end

      it 'a new file in project repo' do
        post api(url, user), params: valid_c_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
        expect(json_response['committer_name']).to eq(user.name)
        expect(json_response['committer_email']).to eq(user.email)
      end

      it 'a new file with utf8 chars in project repo' do
        post api(url, user), params: valid_utf8_c_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
        expect(json_response['committer_name']).to eq(user.name)
        expect(json_response['committer_email']).to eq(user.email)
      end

      it 'returns a 400 bad request if file exists' do
        post api(url, user), params: invalid_c_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'with project path containing a dot in URL' do
        let(:url) { "/projects/#{CGI.escape(project.full_path)}/repository/commits" }

        it 'a new file in project repo' do
          post api(url, user), params: valid_c_params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when committing to a new branch' do
        def last_commit_id(project, branch_name)
          project.repository.find_branch(branch_name)&.dereferenced_target&.id
        end

        before do
          valid_c_params[:start_branch] = 'master'
          valid_c_params[:branch] = 'patch'
        end

        context 'when the API user is a guest' do
          let(:public_project) { create(:project, :public, :repository) }
          let(:url) { "/projects/#{public_project.id}/repository/commits" }
          let(:guest) { create(:user).tap { |u| public_project.add_guest(u) } }

          it 'returns a 403' do
            post api(url, guest), params: valid_c_params

            expect(response).to have_gitlab_http_status(:forbidden)
          end

          context 'when start_project is provided' do
            context 'when posting to a forked project the user owns' do
              let(:forked_project) { fork_project(public_project, guest, namespace: guest.namespace, repository: true) }
              let(:url) { "/projects/#{forked_project.id}/repository/commits" }

              context 'identified by Integer (id)' do
                before do
                  valid_c_params[:start_project] = public_project.id
                end

                it 'adds a new commit to forked_project and returns a 201', :sidekiq_might_not_need_inline do
                  expect_request_with_status(201) { post api(url, guest), params: valid_c_params }
                    .to change { last_commit_id(forked_project, valid_c_params[:branch]) }
                    .and not_change { last_commit_id(public_project, valid_c_params[:start_branch]) }
                end
              end

              context 'identified by String (full_path)' do
                before do
                  valid_c_params[:start_project] = public_project.full_path
                end

                it 'adds a new commit to forked_project and returns a 201', :sidekiq_might_not_need_inline do
                  expect_request_with_status(201) { post api(url, guest), params: valid_c_params }
                    .to change { last_commit_id(forked_project, valid_c_params[:branch]) }
                    .and not_change { last_commit_id(public_project, valid_c_params[:start_branch]) }
                end
              end

              context 'when branch already exists', :sidekiq_might_not_need_inline do
                before do
                  valid_c_params.delete(:start_branch)
                  valid_c_params[:branch] = 'master'
                  valid_c_params[:start_project] = public_project.id
                end

                it 'returns a 400' do
                  post api(url, guest), params: valid_c_params

                  expect(response).to have_gitlab_http_status(:bad_request)
                  expect(json_response['message']).to eq("A branch called 'master' already exists. Switch to that branch in order to make changes")
                end

                context 'when force is set to true' do
                  before do
                    valid_c_params[:force] = true
                  end

                  it 'adds a new commit to forked_project and returns a 201' do
                    expect_request_with_status(201) { post api(url, guest), params: valid_c_params }
                      .to change { last_commit_id(forked_project, valid_c_params[:branch]) }
                      .and not_change { last_commit_id(public_project, valid_c_params[:branch]) }
                  end
                end
              end

              context 'when start_sha is also provided' do
                let(:forked_project) { fork_project(public_project, guest, namespace: guest.namespace, repository: false) }
                let(:start_sha) { public_project.repository.commit.parent.sha }

                before do
                  # initialize an empty repository to force fetching from the original project
                  forked_project.repository.create_if_not_exists

                  valid_c_params[:start_project] = public_project.id
                  valid_c_params[:start_sha] = start_sha
                  valid_c_params.delete(:start_branch)
                end

                it 'fetches the start_sha from the original project to use as parent commit and returns a 201' do
                  expect_request_with_status(201) { post api(url, guest), params: valid_c_params }
                    .to change { last_commit_id(forked_project, valid_c_params[:branch]) }
                    .and not_change { last_commit_id(forked_project, 'master') }

                  last_commit = forked_project.repository.find_branch(valid_c_params[:branch]).dereferenced_target
                  expect(last_commit.parent_id).to eq(start_sha)
                end
              end
            end

            context 'when the target project is not part of the fork network of start_project' do
              let(:unrelated_project) { create(:project, :public, :repository, creator: guest) }
              let(:url) { "/projects/#{unrelated_project.id}/repository/commits" }

              before do
                valid_c_params[:start_branch] = 'master'
                valid_c_params[:branch] = 'patch'
                valid_c_params[:start_project] = public_project.id
              end

              it 'returns a 403' do
                post api(url, guest), params: valid_c_params

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end
          end

          context 'when posting to a forked project the user does not have write access' do
            let(:forked_project) { fork_project(public_project, user, namespace: user.namespace, repository: true) }
            let(:url) { "/projects/#{forked_project.id}/repository/commits" }

            before do
              valid_c_params[:start_branch] = 'master'
              valid_c_params[:branch] = 'patch'
              valid_c_params[:start_project] = public_project.id
            end

            it 'returns a 403' do
              post api(url, guest), params: valid_c_params

              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end

        context 'when start_sha is provided' do
          let(:start_sha) { project.repository.commit.parent.sha }

          before do
            valid_c_params[:start_sha] = start_sha
            valid_c_params.delete(:start_branch)
          end

          it 'returns a 400 if start_branch is also provided' do
            valid_c_params[:start_branch] = 'master'
            post api(url, user), params: valid_c_params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq('start_branch, start_sha are mutually exclusive')
          end

          it 'returns a 400 if branch already exists' do
            valid_c_params[:branch] = 'master'
            post api(url, user), params: valid_c_params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq("A branch called 'master' already exists. Switch to that branch in order to make changes")
          end

          it 'returns a 400 if start_sha does not exist' do
            valid_c_params[:start_sha] = '1' * 40
            post api(url, user), params: valid_c_params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq("Cannot find start_sha '#{valid_c_params[:start_sha]}'")
          end

          it 'returns a 400 if start_sha is not a full SHA' do
            valid_c_params[:start_sha] = start_sha.slice(0, 7)
            post api(url, user), params: valid_c_params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq("Invalid start_sha '#{valid_c_params[:start_sha]}'")
          end

          it 'uses the start_sha as parent commit and returns a 201' do
            expect_request_with_status(201) { post api(url, user), params: valid_c_params }
              .to change { last_commit_id(project, valid_c_params[:branch]) }
              .and not_change { last_commit_id(project, 'master') }

            last_commit = project.repository.find_branch(valid_c_params[:branch]).dereferenced_target
            expect(last_commit.parent_id).to eq(start_sha)
          end

          context 'when force is set to true and branch already exists' do
            before do
              valid_c_params[:force] = true
              valid_c_params[:branch] = 'master'
            end

            it 'uses the start_sha as parent commit and returns a 201' do
              expect_request_with_status(201) { post api(url, user), params: valid_c_params }
                .to change { last_commit_id(project, valid_c_params[:branch]) }

              last_commit = project.repository.find_branch(valid_c_params[:branch]).dereferenced_target
              expect(last_commit.parent_id).to eq(start_sha)
            end
          end
        end
      end
    end

    describe 'delete' do
      let(:message) { 'Deleted file' }
      let(:invalid_d_params) do
        {
          branch: 'markdown',
          commit_message: message,
          actions: [
            {
              action: 'delete',
              file_path: 'doc/api/projects.md'
            }
          ]
        }
      end
      let(:valid_d_params) do
        {
          branch: 'markdown',
          commit_message: message,
          actions: [
            {
              action: 'delete',
              file_path: 'doc/api/users.md'
            }
          ]
        }
      end

      it 'an existing file in project repo' do
        post api(url, user), params: valid_d_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
      end

      it 'returns a 400 bad request if file does not exist' do
        post api(url, user), params: invalid_d_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    describe 'move' do
      let(:message) { 'Moved file' }
      let(:invalid_m_params) do
        {
          branch: 'feature',
          commit_message: message,
          actions: [
            {
              action: 'move',
              file_path: 'CHANGELOG',
              previous_path: 'VERSION',
              content: '6.7.0.pre'
            }
          ]
        }
      end
      let(:valid_m_params) do
        {
          branch: 'feature',
          commit_message: message,
          actions: [
            {
              action: 'move',
              file_path: 'VERSION.txt',
              previous_path: 'VERSION',
              content: '6.7.0.pre'
            }
          ]
        }
      end

      it 'an existing file in project repo' do
        post api(url, user), params: valid_m_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
      end

      it 'returns a 400 bad request if file does not exist' do
        post api(url, user), params: invalid_m_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    describe 'update' do
      let(:message) { 'Updated file' }
      let(:invalid_u_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'update',
              file_path: 'foo/bar.baz',
              content: 'puts 8'
            }
          ]
        }
      end
      let(:valid_u_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'update',
              file_path: 'files/ruby/popen.rb',
              content: 'puts 8'
            }
          ]
        }
      end

      it 'an existing file in project repo' do
        post api(url, user), params: valid_u_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
      end

      it 'returns a 400 bad request if file does not exist' do
        post api(url, user), params: invalid_u_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    describe 'chmod' do
      let(:message) { 'Chmod +x file' }
      let(:file_path) { 'files/ruby/popen.rb' }
      let(:execute_filemode) { true }
      let(:params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'chmod',
              file_path: file_path,
              execute_filemode: execute_filemode
            }
          ]
        }
      end

      it 'responds with success' do
        post api(url, user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
      end

      context 'when execute_filemode is false' do
        let(:execute_filemode) { false }

        it 'responds with success' do
          post api(url, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq(message)
        end
      end

      context "when the file doesn't exists" do
        let(:file_path) { 'foo/bar.baz' }

        it "responds with 400" do
          post api(url, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq("A file with this name doesn't exist")
        end
      end
    end

    describe 'multiple operations' do
      let(:message) { 'Multiple actions' }
      let(:invalid_mo_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'create',
              file_path: 'files/ruby/popen.rb',
              content: 'puts 8'
            },
            {
              action: 'delete',
              file_path: 'doc/api/projects.md'
            },
            {
              action: 'move',
              file_path: 'CHANGELOG',
              previous_path: 'VERSION',
              content: '6.7.0.pre'
            },
            {
              action: 'update',
              file_path: 'foo/bar.baz',
              content: 'puts 8'
            },
            {
              action: 'chmod',
              file_path: 'files/ruby/popen.rb',
              execute_filemode: true
            }
          ]
        }
      end
      let(:valid_mo_params) do
        {
          branch: 'master',
          commit_message: message,
          actions: [
            {
              action: 'create',
              file_path: 'foo/bar/baz.txt',
              content: 'puts 8'
            },
            {
              action: 'delete',
              file_path: 'Gemfile.zip'
            },
            {
              action: 'move',
              file_path: 'VERSION.txt',
              previous_path: 'VERSION',
              content: '6.7.0.pre'
            },
            {
              action: 'update',
              file_path: 'files/ruby/popen.rb',
              content: 'puts 8'
            },
            {
              action: 'chmod',
              file_path: 'files/ruby/popen.rb',
              execute_filemode: true
            }
          ]
        }
      end

      it 'are committed as one in project repo' do
        post api(url, user), params: valid_mo_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq(message)
      end

      it 'includes the commit stats' do
        post api(url, user), params: valid_mo_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include 'stats'
      end

      it "doesn't include the commit stats when stats is false" do
        post api(url, user), params: valid_mo_params.merge(stats: false)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).not_to include 'stats'
      end

      it 'return a 400 bad request if there are any issues' do
        post api(url, user), params: invalid_mo_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when committing into a fork as a maintainer' do
      include_context 'merge request allowing collaboration'

      let(:project_id) { forked_project.id }

      def push_params(branch_name)
        {
          branch: branch_name,
          commit_message: 'Hello world',
          actions: [
            {
              action: 'create',
              file_path: 'foo/bar/baz.txt',
              content: 'puts 8'
            }
          ]
        }
      end

      it 'allows pushing to the source branch of the merge request', :sidekiq_might_not_need_inline do
        post api(url, user), params: push_params('feature')

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'denies pushing to another branch' do
        post api(url, user), params: push_params('other-branch')

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /projects/:id/repository/commits/:sha/refs' do
    let(:project) { create(:project, :public, :repository) }
    let(:tag) { project.repository.find_tag('v1.1.0') }
    let(:commit_id) { tag.dereferenced_target.id }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}/refs" }

    context 'when ref does not exist' do
      let(:commit_id) { 'unknown' }

      it_behaves_like '404 response' do
        let(:request) { get api(route, current_user) }
        let(:message) { '404 Commit Not Found' }
      end
    end

    context 'when repository is disabled' do
      include_context 'disabled repository'

      it_behaves_like '404 response' do
        let(:request) { get api(route, current_user) }
      end
    end

    context 'for a valid commit' do
      it 'returns all refs with no scope' do
        get api(route, current_user), params: { per_page: 100 }

        refs = project.repository.branch_names_contains(commit_id).map {|name| ['branch', name]}
        refs.concat(project.repository.tag_names_contains(commit_id).map {|name| ['tag', name]})

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.map { |r| [r['type'], r['name']] }.compact).to eq(refs)
      end

      it 'returns all refs' do
        get api(route, current_user), params: { type: 'all', per_page: 100 }

        refs = project.repository.branch_names_contains(commit_id).map {|name| ['branch', name]}
        refs.concat(project.repository.tag_names_contains(commit_id).map {|name| ['tag', name]})

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.map { |r| [r['type'], r['name']] }.compact).to eq(refs)
      end

      it 'returns the branch refs' do
        get api(route, current_user), params: { type: 'branch', per_page: 100 }

        refs = project.repository.branch_names_contains(commit_id).map {|name| ['branch', name]}

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.map { |r| [r['type'], r['name']] }.compact).to eq(refs)
      end

      it 'returns the tag refs' do
        get api(route, current_user), params: { type: 'tag', per_page: 100 }

        refs = project.repository.tag_names_contains(commit_id).map {|name| ['tag', name]}

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.map { |r| [r['type'], r['name']] }.compact).to eq(refs)
      end
    end
  end

  describe 'GET /projects/:id/repository/commits/:sha' do
    let(:commit) { project.repository.commit }
    let(:commit_id) { commit.id }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}" }

    shared_examples_for 'ref commit' do
      it 'returns the ref last commit' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/commit/detail')
        expect(json_response['id']).to eq(commit.id)
        expect(json_response['short_id']).to eq(commit.short_id)
        expect(json_response['title']).to eq(commit.title)
        expect(json_response['message']).to eq(commit.safe_message)
        expect(json_response['author_name']).to eq(commit.author_name)
        expect(json_response['author_email']).to eq(commit.author_email)
        expect(json_response['authored_date']).to eq(commit.authored_date.iso8601(3))
        expect(json_response['committer_name']).to eq(commit.committer_name)
        expect(json_response['committer_email']).to eq(commit.committer_email)
        expect(json_response['committed_date']).to eq(commit.committed_date.iso8601(3))
        expect(json_response['parent_ids']).to eq(commit.parent_ids)
        expect(json_response['stats']['additions']).to eq(commit.stats.additions)
        expect(json_response['stats']['deletions']).to eq(commit.stats.deletions)
        expect(json_response['stats']['total']).to eq(commit.stats.total)
        expect(json_response['status']).to be_nil
        expect(json_response['last_pipeline']).to be_nil
      end

      context 'when ref does not exist' do
        let(:commit_id) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
          let(:message) { '404 Commit Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
        end
      end
    end

    shared_examples_for 'ref with pipeline' do
      let!(:pipeline) do
        project
          .ci_pipelines
          .create!(source: :push, ref: 'master', sha: commit.sha, protected: false)
      end

      it 'includes status as "created" and a last_pipeline object' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/commit/detail')
        expect(json_response['status']).to eq('created')
        expect(json_response['last_pipeline']['id']).to eq(pipeline.id)
        expect(json_response['last_pipeline']['ref']).to eq(pipeline.ref)
        expect(json_response['last_pipeline']['sha']).to eq(pipeline.sha)
        expect(json_response['last_pipeline']['status']).to eq(pipeline.status)
      end

      context 'when pipeline succeeds' do
        before do
          pipeline.update!(status: 'success')
        end

        it 'includes a "success" status' do
          get api(route, current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/commit/detail')
          expect(json_response['status']).to eq('success')
        end
      end
    end

    shared_examples_for 'ref with unaccessible pipeline' do
      let!(:pipeline) do
        project
          .ci_pipelines
          .create!(source: :push, ref: 'master', sha: commit.sha, protected: false)
      end

      it 'does not include last_pipeline' do
        get api(route, current_user)

        expect(response).to match_response_schema('public_api/v4/commit/detail')
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['last_pipeline']).to be_nil
      end
    end

    context 'when stat param' do
      let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}" }

      it 'is not present return stats by default' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include 'stats'
      end

      it "is false it does not include stats" do
        get api(route, user), params: { stats: false }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to include 'stats'
      end

      it "is true it includes stats" do
        get api(route, user), params: { stats: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include 'stats'
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'ref commit'
      it_behaves_like 'ref with pipeline'

      context 'with private builds' do
        before do
          project.project_feature.update!(builds_access_level: ProjectFeature::PRIVATE)
        end

        it_behaves_like 'ref with unaccessible pipeline'
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'ref commit'
      it_behaves_like 'ref with pipeline'

      context 'when builds are disabled' do
        before do
          project
            .project_feature
            .update!(builds_access_level: ProjectFeature::DISABLED)
        end

        it_behaves_like 'ref with unaccessible pipeline'
      end

      context 'when branch contains a dot' do
        let(:commit) { project.repository.commit(branch_with_dot.name) }
        let(:commit_id) { branch_with_dot.name }

        it_behaves_like 'ref commit'
      end

      context 'when branch contains a slash' do
        let(:commit_id) { branch_with_slash.name }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'when branch contains an escaped slash' do
        let(:commit) { project.repository.commit(branch_with_slash.name) }
        let(:commit_id) { CGI.escape(branch_with_slash.name) }

        it_behaves_like 'ref commit'
      end

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'ref commit'

        context 'when branch contains a dot' do
          let(:commit) { project.repository.commit(branch_with_dot.name) }
          let(:commit_id) { branch_with_dot.name }

          it_behaves_like 'ref commit'
        end
      end
    end

    context 'when authenticated', 'as a developer' do
      let(:current_user) { developer }

      it_behaves_like 'ref commit'
      it_behaves_like 'ref with pipeline'

      context 'with private builds' do
        before do
          project.project_feature.update!(builds_access_level: ProjectFeature::PRIVATE)
        end

        it_behaves_like 'ref with pipeline'
      end
    end

    context 'when authenticated', 'as a guest' do
      let(:current_user) { guest }

      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
        let(:message) { '403 Forbidden' }
      end
    end

    context 'when authenticated', 'as a non member' do
      let(:current_user) { create(:user) }

      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
        let(:message) { '403 Forbidden' }
      end
    end

    context 'when authenticated', 'as non_member and project is public' do
      let(:current_user) { create(:user) }
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'ref with pipeline'

      context 'with private builds' do
        before do
          project.project_feature.update!(builds_access_level: ProjectFeature::PRIVATE)
        end

        it_behaves_like 'ref with unaccessible pipeline'
      end
    end
  end

  describe 'GET /projects/:id/repository/commits/:sha/diff' do
    let(:commit) { project.repository.commit }
    let(:commit_id) { commit.id }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}/diff" }

    shared_examples_for 'ref diff' do
      it 'returns the diff of the selected commit' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response.size).to be >= 1
        expect(json_response.first.keys).to include 'diff'
      end

      context 'when hard limits are lower than the number of files' do
        before do
          allow(Commit).to receive(:max_diff_options).and_return(max_files: 1)
        end

        it 'respects the limit' do
          get api(route, current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response.size).to be <= 1
        end
      end

      context 'when ref does not exist' do
        let(:commit_id) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
          let(:message) { '404 Commit Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'ref diff'
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'ref diff'

      context 'when branch contains a dot' do
        let(:commit_id) { branch_with_dot.name }

        it_behaves_like 'ref diff'
      end

      context 'when branch contains a slash' do
        let(:commit_id) { branch_with_slash.name }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'when branch contains an escaped slash' do
        let(:commit_id) { CGI.escape(branch_with_slash.name) }

        it_behaves_like 'ref diff'
      end

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'ref diff'

        context 'when branch contains a dot' do
          let(:commit_id) { branch_with_dot.name }

          it_behaves_like 'ref diff'
        end
      end

      context 'when binary diff are treated as text' do
        let(:commit_id) { TestEnv::BRANCH_SHA['add-pdf-text-binary'] }

        it_behaves_like 'ref diff'
      end
    end
  end

  describe 'GET /projects/:id/repository/commits/:sha/comments' do
    let(:commit) { project.repository.commit }
    let(:commit_id) { commit.id }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}/comments" }

    shared_examples_for 'ref comments' do
      context 'when ref exists' do
        before do
          create(:note_on_commit, author: user, project: project, commit_id: commit.id, note: 'a comment on a commit')
          create(:note_on_commit, author: user, project: project, commit_id: commit.id, note: 'another comment on a commit')
        end

        it 'returns the diff of the selected commit' do
          get api(route, current_user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/commit_notes')
          expect(json_response.size).to eq(2)
          expect(json_response.first['note']).to eq('a comment on a commit')
          expect(json_response.first['author']['id']).to eq(user.id)
        end
      end

      context 'when ref does not exist' do
        let(:commit_id) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
          let(:message) { '404 Commit Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'ref comments'
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'ref comments'

      context 'when branch contains a dot' do
        let(:commit) { project.repository.commit(branch_with_dot.name) }
        let(:commit_id) { branch_with_dot.name }

        it_behaves_like 'ref comments'
      end

      context 'when branch contains a slash' do
        let(:commit) { project.repository.commit(branch_with_slash.name) }
        let(:commit_id) { branch_with_slash.name }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'when branch contains an escaped slash' do
        let(:commit) { project.repository.commit(branch_with_slash.name) }
        let(:commit_id) { CGI.escape(branch_with_slash.name) }

        it_behaves_like 'ref comments'
      end

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'ref comments'

        context 'when branch contains a dot' do
          let(:commit) { project.repository.commit(branch_with_dot.name) }
          let(:commit_id) { branch_with_dot.name }

          it_behaves_like 'ref comments'
        end
      end
    end

    context 'when the commit is present on two projects' do
      let(:forked_project) { create(:project, :repository, creator: guest, namespace: guest.namespace) }
      let!(:forked_project_note) { create(:note_on_commit, author: guest, project: forked_project, commit_id: forked_project.repository.commit.id, note: 'a comment on a commit for fork') }
      let(:project_id) { forked_project.id }
      let(:commit_id) { forked_project.repository.commit.id }

      it 'returns the comments for the target project' do
        get api(route, guest)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/commit_notes')
        expect(json_response.size).to eq(1)
        expect(json_response.first['note']).to eq('a comment on a commit for fork')
        expect(json_response.first['author']['id']).to eq(guest.id)
      end
    end
  end

  describe 'POST :id/repository/commits/:sha/cherry_pick' do
    let(:commit) { project.commit('7d3b0f7cff5f37573aea97cebfd5692ea1689924') }
    let(:commit_id) { commit.id }
    let(:branch) { 'master' }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}/cherry_pick" }

    shared_examples_for 'ref cherry-pick' do
      context 'when ref exists' do
        it 'cherry-picks the ref commit' do
          post api(route, current_user), params: { branch: branch }

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/commit/basic')
          expect(json_response['title']).to eq(commit.title)
          expect(json_response['message']).to eq(commit.cherry_pick_message(user))
          expect(json_response['author_name']).to eq(commit.author_name)
          expect(json_response['committer_name']).to eq(user.name)
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: 'master' } }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like '403 response' do
        let(:request) { post api(route), params: { branch: 'master' } }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { post api(route), params: { branch: 'master' } }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as an owner' do
      let(:current_user) { user }

      it_behaves_like 'ref cherry-pick'

      context 'when ref does not exist' do
        let(:commit_id) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: 'master' } }
          let(:message) { '404 Commit Not Found' }
        end
      end

      context 'when branch is missing' do
        it_behaves_like '400 response' do
          let(:request) { post api(route, current_user) }
        end
      end

      context 'when branch is empty' do
        ['', ' '].each do |branch|
          it_behaves_like '400 response' do
            let(:request) { post api(route, current_user), params: { branch: branch } }
          end
        end
      end

      context 'when branch does not exist' do
        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: 'foo' } }
          let(:message) { '404 Branch Not Found' }
        end
      end

      context 'when commit is already included in the target branch' do
        it_behaves_like '400 response' do
          let(:request) { post api(route, current_user), params: { branch: 'markdown' } }
        end

        it 'includes an error_code in the response' do
          post api(route, current_user), params: { branch: 'markdown' }

          expect(json_response['error_code']).to eq 'empty'
        end
      end

      context 'when ref contains a dot' do
        let(:commit) { project.repository.commit(branch_with_dot.name) }
        let(:commit_id) { branch_with_dot.name }

        it_behaves_like 'ref cherry-pick'
      end

      context 'when ref contains a slash' do
        let(:commit_id) { branch_with_slash.name }

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: 'master' } }
        end
      end

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'ref cherry-pick'

        context 'when ref contains a dot' do
          let(:commit) { project.repository.commit(branch_with_dot.name) }
          let(:commit_id) { branch_with_dot.name }

          it_behaves_like 'ref cherry-pick'
        end
      end
    end

    context 'when authenticated', 'as a developer' do
      let(:current_user) { guest }

      before do
        project.add_developer(guest)
      end

      context 'when branch is protected' do
        before do
          create(:protected_branch, project: project, name: 'feature')
        end

        it 'returns 400 if you are not allowed to push to the target branch' do
          post api(route, current_user), params: { branch: 'feature' }

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to match(/You are not allowed to push into this branch/)
        end
      end
    end

    context 'when cherry picking to a fork as a maintainer' do
      include_context 'merge request allowing collaboration'

      let(:project_id) { forked_project.id }

      it 'allows access from a maintainer that to the source branch', :sidekiq_might_not_need_inline do
        post api(route, user), params: { branch: 'feature' }

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'denies cherry picking to another branch' do
        post api(route, user), params: { branch: 'master' }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST :id/repository/commits/:sha/revert' do
    let(:commit_id) { 'b83d6e391c22777fca1ed3012fce84f633d7fed0' }
    let(:commit)    { project.commit(commit_id) }
    let(:branch)    { 'master' }
    let(:route)     { "/projects/#{project_id}/repository/commits/#{commit_id}/revert" }

    shared_examples_for 'ref revert' do
      context 'when ref exists' do
        it 'reverts the ref commit' do
          post api(route, current_user), params: { branch: branch }

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/commit/basic')

          expect(json_response['message']).to eq(commit.revert_message(user))
          expect(json_response['author_name']).to eq(user.name)
          expect(json_response['committer_name']).to eq(user.name)
          expect(json_response['parent_ids']).to contain_exactly(commit_id)
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: branch } }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like '403 response' do
        let(:request) { post api(route), params: { branch: branch } }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { post api(route), params: { branch: branch } }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as an owner' do
      let(:current_user) { user }

      it_behaves_like 'ref revert'

      context 'when ref does not exist' do
        let(:commit_id) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: branch } }
          let(:message) { '404 Commit Not Found' }
        end
      end

      context 'when branch is missing' do
        it_behaves_like '400 response' do
          let(:request) { post api(route, current_user) }
        end
      end

      context 'when branch is empty' do
        ['', ' '].each do |branch|
          it_behaves_like '400 response' do
            let(:request) { post api(route, current_user), params: { branch: branch } }
          end
        end
      end

      context 'when branch does not exist' do
        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { branch: 'foo' } }
          let(:message) { '404 Branch Not Found' }
        end
      end

      context 'when ref contains a dot' do
        let(:commit_id) { branch_with_dot.name }
        let(:commit) { project.repository.commit(commit_id) }

        it_behaves_like '400 response' do
          let(:request) { post api(route, current_user) }
        end
      end

      context 'when commit is already reverted in the target branch' do
        it 'includes an error_code in the response' do
          # First one actually reverts
          post api(route, current_user), params: { branch: 'markdown' }

          # Second one is redundant and should be empty
          post api(route, current_user), params: { branch: 'markdown' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error_code']).to eq 'empty'
        end
      end
    end

    context 'when authenticated', 'as a developer' do
      let(:current_user) { user }

      before do
        project.add_developer(user)
      end

      context 'when branch is protected' do
        before do
          create(:protected_branch, project: project, name: 'feature')
        end

        it 'returns 400 if you are not allowed to push to the target branch' do
          post api(route, current_user), params: { branch: 'feature' }

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to match(/You are not allowed to push into this branch/)
        end
      end
    end
  end

  describe 'POST /projects/:id/repository/commits/:sha/comments' do
    let(:commit) { project.repository.commit }
    let(:commit_id) { commit.id }
    let(:note) { 'My comment' }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}/comments" }

    shared_examples_for 'ref new comment' do
      context 'when ref exists' do
        it 'creates the comment' do
          post api(route, current_user), params: { note: note }

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/commit_note')
          expect(json_response['note']).to eq('My comment')
          expect(json_response['path']).to be_nil
          expect(json_response['line']).to be_nil
          expect(json_response['line_type']).to be_nil
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { note: 'My comment' } }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like '400 response' do
        let(:request) { post api(route), params: { note: 'My comment' } }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { post api(route), params: { note: 'My comment' } }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as an owner' do
      let(:current_user) { user }

      it_behaves_like 'ref new comment'

      it 'returns the inline comment' do
        post api(route, current_user), params: { note: 'My comment', path: project.repository.commit.raw_diffs.first.new_path, line: 1, line_type: 'new' }

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/commit_note')
        expect(json_response['note']).to eq('My comment')
        expect(json_response['path']).to eq(project.repository.commit.raw_diffs.first.new_path)
        expect(json_response['line']).to eq(1)
        expect(json_response['line_type']).to eq('new')
      end

      context 'when ref does not exist' do
        let(:commit_id) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { note: 'My comment' } }
          let(:message) { '404 Commit Not Found' }
        end
      end

      it 'returns 400 if note is missing' do
        post api(route, current_user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'when ref contains a dot' do
        let(:commit_id) { branch_with_dot.name }

        it_behaves_like 'ref new comment'
      end

      context 'when ref contains a slash' do
        let(:commit_id) { branch_with_slash.name }

        it_behaves_like '404 response' do
          let(:request) { post api(route, current_user), params: { note: 'My comment' } }
        end
      end

      context 'when ref contains an escaped slash' do
        let(:commit_id) { CGI.escape(branch_with_slash.name) }

        it_behaves_like 'ref new comment'
      end

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'ref new comment'

        context 'when ref contains a dot' do
          let(:commit_id) { branch_with_dot.name }

          it_behaves_like 'ref new comment'
        end
      end
    end
  end

  describe 'GET /projects/:id/repository/commits/:sha/merge_requests' do
    let(:project) { create(:project, :repository, :private) }
    let(:merged_mr) { create(:merge_request, source_project: project, source_branch: 'master', target_branch: 'feature') }
    let(:commit) { merged_mr.merge_request_diff.commits.last }

    it 'returns the correct merge request' do
      get api("/projects/#{project.id}/repository/commits/#{commit.id}/merge_requests", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to include_pagination_headers
      expect(json_response.length).to eq(1)
      expect(json_response[0]['id']).to eq(merged_mr.id)
    end

    it 'returns 403 for an unauthorized user' do
      project.add_guest(user)

      get api("/projects/#{project.id}/repository/commits/#{commit.id}/merge_requests", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'responds 404 when the commit does not exist' do
      get api("/projects/#{project.id}/repository/commits/a7d26f00c35b/merge_requests", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'public project' do
      let(:project) { create(:project, :repository, :public, :merge_requests_private) }
      let(:non_member) { create(:user) }

      it 'responds 403 when only members are allowed to read merge requests' do
        get api("/projects/#{project.id}/repository/commits/#{commit.id}/merge_requests", non_member)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /projects/:id/repository/commits/:sha/signature' do
    let!(:project) { create(:project, :repository, :public) }
    let(:project_id) { project.id }
    let(:commit_id) { project.repository.commit.id }
    let(:route) { "/projects/#{project_id}/repository/commits/#{commit_id}/signature" }

    context 'when commit does not exist' do
      let(:commit_id) { 'unknown' }

      it_behaves_like '404 response' do
        let(:request) { get api(route, current_user) }
        let(:message) { '404 Commit Not Found' }
      end
    end

    context 'unsigned commit' do
      it_behaves_like '404 response' do
        let(:request) { get api(route, current_user) }
        let(:message) { '404 GPG Signature Not Found'}
      end
    end

    context 'signed commit' do
      let(:commit) { project.repository.commit(GpgHelpers::SIGNED_COMMIT_SHA) }
      let(:commit_id) { commit.id }

      it 'returns correct JSON' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['gpg_key_id']).to eq(commit.signature.gpg_key_id)
        expect(json_response['gpg_key_subkey_id']).to eq(commit.signature.gpg_key_subkey_id)
        expect(json_response['gpg_key_primary_keyid']).to eq(commit.signature.gpg_key_primary_keyid)
        expect(json_response['verification_status']).to eq(commit.signature.verification_status)
      end
    end
  end
end

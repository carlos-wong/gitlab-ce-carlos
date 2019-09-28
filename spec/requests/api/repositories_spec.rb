require 'spec_helper'
require 'mime/types'

describe API::Repositories do
  include RepoHelpers
  include WorkhorseHelpers

  let(:user) { create(:user) }
  let(:guest) { create(:user).tap { |u| create(:project_member, :guest, user: u, project: project) } }
  let!(:project) { create(:project, :repository, creator: user) }
  let!(:maintainer) { create(:project_member, :maintainer, user: user, project: project) }

  describe "GET /projects/:id/repository/tree" do
    let(:route) { "/projects/#{project.id}/repository/tree" }

    shared_examples_for 'repository tree' do
      it 'returns the repository tree' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array

        first_commit = json_response.first
        expect(first_commit['name']).to eq('bar')
        expect(first_commit['type']).to eq('tree')
        expect(first_commit['mode']).to eq('040000')
      end

      context 'when ref does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api("#{route}?ref=foo", current_user) }
          let(:message) { '404 Tree Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'with recursive=1' do
        it 'returns recursive project paths tree' do
          get api("#{route}?recursive=1", current_user)

          expect(response.status).to eq(200)
          expect(json_response).to be_an Array
          expect(response).to include_pagination_headers
          expect(json_response[4]['name']).to eq('html')
          expect(json_response[4]['path']).to eq('files/html')
          expect(json_response[4]['type']).to eq('tree')
          expect(json_response[4]['mode']).to eq('040000')
        end

        context 'when repository is disabled' do
          include_context 'disabled repository'

          it_behaves_like '403 response' do
            let(:request) { get api(route, current_user) }
          end
        end

        context 'when ref does not exist' do
          it_behaves_like '404 response' do
            let(:request) { get api("#{route}?recursive=1&ref=foo", current_user) }
            let(:message) { '404 Tree Not Found' }
          end
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository tree' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository tree' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end
  end

  describe "GET /projects/:id/repository/blobs/:sha" do
    let(:route) { "/projects/#{project.id}/repository/blobs/#{sample_blob.oid}" }

    shared_examples_for 'repository blob' do
      it 'returns blob attributes as json' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['size']).to eq(111)
        expect(json_response['encoding']).to eq("base64")
        expect(Base64.decode64(json_response['content']).lines.first).to eq("class Commit\n")
        expect(json_response['sha']).to eq(sample_blob.oid)
      end

      context 'when sha does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api(route.sub(sample_blob.oid, '123456'), current_user) }
          let(:message) { '404 Blob Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository blob' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository blob' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end
  end

  describe "GET /projects/:id/repository/blobs/:sha/raw" do
    let(:route) { "/projects/#{project.id}/repository/blobs/#{sample_blob.oid}/raw" }

    shared_examples_for 'repository raw blob' do
      it 'returns the repository raw blob' do
        expect(Gitlab::Workhorse).to receive(:send_git_blob)

        get api(route, current_user)

        expect(response).to have_gitlab_http_status(200)
        expect(headers[Gitlab::Workhorse::DETECT_HEADER]).to eq "true"
      end

      it 'sets inline content disposition by default' do
        get api(route, current_user)

        expect(headers['Content-Disposition']).to eq 'inline'
      end

      context 'when sha does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api(route.sub(sample_blob.oid, '123456'), current_user) }
          let(:message) { '404 Blob Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository raw blob' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository raw blob' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end
  end

  describe "GET /projects/:id/repository/archive(.:format)?:sha" do
    let(:route) { "/projects/#{project.id}/repository/archive" }

    shared_examples_for 'repository archive' do
      it 'returns the repository archive' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(200)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}\-[^\.]+\.tar.gz/)
      end

      it 'returns the repository archive archive.zip' do
        get api("/projects/#{project.id}/repository/archive.zip", user)

        expect(response).to have_gitlab_http_status(200)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}\-[^\.]+\.zip/)
      end

      it 'returns the repository archive archive.tar.bz2' do
        get api("/projects/#{project.id}/repository/archive.tar.bz2", user)

        expect(response).to have_gitlab_http_status(200)

        type, params = workhorse_send_data

        expect(type).to eq('git-archive')
        expect(params['ArchivePath']).to match(/#{project.path}\-[^\.]+\.tar.bz2/)
      end

      context 'when sha does not exist' do
        it_behaves_like '404 response' do
          let(:request) { get api("#{route}?sha=xxx", current_user) }
          let(:message) { '404 File Not Found' }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository archive' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository archive' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end
  end

  describe 'GET /projects/:id/repository/compare' do
    let(:route) { "/projects/#{project.id}/repository/compare" }

    shared_examples_for 'repository compare' do
      it "compares branches" do
        expect(::Gitlab::Git::Compare).to receive(:new).with(anything, anything, anything, {
          straight: false
        }).and_call_original
        get api(route, current_user), params: { from: 'master', to: 'feature' }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
      end

      it "compares branches with explicit merge-base mode" do
        expect(::Gitlab::Git::Compare).to receive(:new).with(anything, anything, anything, {
          straight: false
        }).and_call_original
        get api(route, current_user), params: { from: 'master', to: 'feature', straight: false }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
      end

      it "compares branches with explicit straight mode" do
        expect(::Gitlab::Git::Compare).to receive(:new).with(anything, anything, anything, {
          straight: true
        }).and_call_original
        get api(route, current_user), params: { from: 'master', to: 'feature', straight: true }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
      end

      it "compares tags" do
        get api(route, current_user), params: { from: 'v1.0.0', to: 'v1.1.0' }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
      end

      it "compares commits" do
        get api(route, current_user), params: { from: sample_commit.id, to: sample_commit.parent_id }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_empty
        expect(json_response['diffs']).to be_empty
        expect(json_response['compare_same_ref']).to be_falsey
      end

      it "compares commits in reverse order" do
        get api(route, current_user), params: { from: sample_commit.parent_id, to: sample_commit.id }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_present
        expect(json_response['diffs']).to be_present
      end

      it "compares same refs" do
        get api(route, current_user), params: { from: 'master', to: 'master' }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commits']).to be_empty
        expect(json_response['diffs']).to be_empty
        expect(json_response['compare_same_ref']).to be_truthy
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository compare' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository compare' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end
  end

  describe 'GET /projects/:id/repository/contributors' do
    let(:route) { "/projects/#{project.id}/repository/contributors" }

    shared_examples_for 'repository contributors' do
      it 'returns valid data' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array

        first_contributor = json_response.first
        expect(first_contributor['email']).to eq('tiagonbotelho@hotmail.com')
        expect(first_contributor['name']).to eq('tiagonbotelho')
        expect(first_contributor['commits']).to eq(1)
        expect(first_contributor['additions']).to eq(0)
        expect(first_contributor['deletions']).to eq(0)
      end

      context 'using sorting' do
        context 'by commits desc' do
          it 'returns the repository contribuors sorted by commits desc' do
            get api(route, current_user), params: { order_by: 'commits', sort: 'desc' }

            expect(response).to have_gitlab_http_status(200)
            expect(response).to match_response_schema('contributors')
            expect(json_response.first['commits']).to be > json_response.last['commits']
          end
        end

        context 'by name desc' do
          it 'returns the repository contribuors sorted by name asc case insensitive' do
            get api(route, current_user), params: { order_by: 'name', sort: 'asc' }

            expect(response).to have_gitlab_http_status(200)
            expect(response).to match_response_schema('contributors')
            expect(json_response.first['name'].downcase).to be < json_response.last['name'].downcase
          end
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'repository contributors' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'repository contributors' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end

    # Regression: https://gitlab.com/gitlab-org/gitlab-foss/issues/45363
    describe 'Links header contains working URLs when no `order_by` nor `sort` is given' do
      let(:project) { create(:project, :public, :repository) }
      let(:current_user) { nil }

      it 'returns `Link` header that includes URLs with default value for `order_by` & `sort`' do
        get api(route, current_user)

        first_link_url = response.headers['Link'].split(';').first

        expect(first_link_url).to include('order_by=commits')
        expect(first_link_url).to include('sort=asc')
      end
    end
  end

  describe 'GET :id/repository/merge_base' do
    let(:refs) do
      %w(304d257dcb821665ab5110318fc58a007bd104ed 0031876facac3f2b2702a0e53a26e89939a42209 570e7b2abdd848b95f2f578043fc23bd6f6fd24d)
    end

    subject(:request) do
      get(api("/projects/#{project.id}/repository/merge_base", current_user), params: { refs: refs })
    end

    shared_examples 'merge base' do
      it 'returns the common ancestor' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(json_response['id']).to be_present
      end
    end

    context 'when unauthenticated', 'and project is public' do
      it_behaves_like 'merge base' do
        let(:project) { create(:project, :public, :repository) }
        let(:current_user) { nil }
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:current_user) { nil }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a developer' do
      it_behaves_like 'merge base' do
        let(:current_user) { user }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:current_user) { guest }
      end
    end

    context 'when passing refs that do not exist' do
      it_behaves_like '400 response' do
        let(:refs) { %w(304d257dcb821665ab5110318fc58a007bd104ed missing) }
        let(:current_user) { user }
        let(:message) { 'Could not find ref: missing' }
      end
    end

    context 'when passing refs that do not have a merge base' do
      it_behaves_like '404 response' do
        let(:refs) { ['304d257dcb821665ab5110318fc58a007bd104ed', TestEnv::BRANCH_SHA['orphaned-branch']] }
        let(:current_user) { user }
        let(:message) { '404 Merge Base Not Found' }
      end
    end

    context 'when not enough refs are passed' do
      let(:refs) { %w(only-one) }
      let(:current_user) { user }

      it 'renders a bad request error' do
        request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Provide at least 2 refs')
      end
    end
  end
end

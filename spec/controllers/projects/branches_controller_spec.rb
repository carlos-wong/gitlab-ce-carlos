# frozen_string_literal: true

require 'spec_helper'

describe Projects::BranchesController do
  let(:project)   { create(:project, :repository) }
  let(:user)      { create(:user) }
  let(:developer) { create(:user) }

  before do
    project.add_maintainer(user)
    project.add_developer(user)

    allow(project).to receive(:branches).and_return(['master', 'foo/bar/baz'])
    allow(project).to receive(:tags).and_return(['v1.0.0', 'v2.0.0'])
    controller.instance_variable_set(:@project, project)
  end

  describe "POST create with HTML format" do
    render_views

    context "on creation of a new branch" do
      before do
        sign_in(user)

        post :create,
             params: {
               namespace_id: project.namespace,
               project_id: project,
               branch_name: branch,
               ref: ref
             }
      end

      context "valid branch name, valid source" do
        let(:branch) { "merge_branch" }
        let(:ref) { "master" }
        it 'redirects' do
          expect(subject)
            .to redirect_to("/#{project.full_path}/tree/merge_branch")
        end
      end

      context "invalid branch name, valid ref" do
        let(:branch) { "<script>alert('merge');</script>" }
        let(:ref) { "master" }
        it 'redirects' do
          expect(subject)
            .to redirect_to("/#{project.full_path}/tree/alert('merge');")
        end
      end

      context "valid branch name, invalid ref" do
        let(:branch) { "merge_branch" }
        let(:ref) { "<script>alert('ref');</script>" }
        it { is_expected.to render_template('new') }
      end

      context "invalid branch name, invalid ref" do
        let(:branch) { "<script>alert('merge');</script>" }
        let(:ref) { "<script>alert('ref');</script>" }
        it { is_expected.to render_template('new') }
      end

      context "valid branch name with encoded slashes" do
        let(:branch) { "feature%2Ftest" }
        let(:ref) { "<script>alert('ref');</script>" }
        it { is_expected.to render_template('new') }
        it { project.repository.branch_exists?('feature/test') }
      end
    end

    describe "created from the new branch button on issues" do
      let(:branch) { "1-feature-branch" }
      let(:issue) { create(:issue, project: project) }

      before do
        sign_in(user)
      end

      it 'redirects' do
        post :create,
             params: {
               namespace_id: project.namespace,
               project_id: project,
               branch_name: branch,
               issue_iid: issue.iid
             }

        expect(subject)
          .to redirect_to("/#{project.full_path}/tree/1-feature-branch")
      end

      it 'posts a system note' do
        expect(SystemNoteService).to receive(:new_issue_branch).with(issue, project, user, "1-feature-branch", branch_project: project)

        post :create,
             params: {
               namespace_id: project.namespace,
               project_id: project,
               branch_name: branch,
               issue_iid: issue.iid
             }
      end

      context 'confidential_issue_project_id is present' do
        let(:confidential_issue_project) { create(:project) }

        def create_branch_with_confidential_issue_project
          post(
            :create,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              branch_name: branch,
              confidential_issue_project_id: confidential_issue_project.id,
              issue_iid: issue.iid
            }
          )
        end

        context 'create_confidential_merge_request feature is enabled' do
          before do
            stub_feature_flags(create_confidential_merge_request: true)
          end

          context 'user cannot update issue' do
            let(:issue) { create(:issue, project: confidential_issue_project) }

            it 'does not post a system note' do
              expect(SystemNoteService).not_to receive(:new_issue_branch)

              create_branch_with_confidential_issue_project
            end
          end

          context 'user can update issue' do
            before do
              confidential_issue_project.add_reporter(user)
            end

            context 'issue is under the specified project' do
              let(:issue) { create(:issue, project: confidential_issue_project) }

              it 'posts a system note' do
                expect(SystemNoteService).to receive(:new_issue_branch).with(issue, confidential_issue_project, user, "1-feature-branch", branch_project: project)

                create_branch_with_confidential_issue_project
              end
            end

            context 'issue is not under the specified project' do
              it 'does not post a system note' do
                expect(SystemNoteService).not_to receive(:new_issue_branch)

                create_branch_with_confidential_issue_project
              end
            end
          end
        end

        context 'create_confidential_merge_request feature is disabled' do
          before do
            stub_feature_flags(create_confidential_merge_request: false)
          end

          it 'posts a system note on project' do
            expect(SystemNoteService).to receive(:new_issue_branch).with(issue, project, user, "1-feature-branch", branch_project: project)

            create_branch_with_confidential_issue_project
          end
        end
      end

      context 'repository-less project' do
        let(:project) { create :project }

        it 'redirects to newly created branch' do
          result = { status: :success, branch: double(name: branch) }

          expect_any_instance_of(CreateBranchService).to receive(:execute).and_return(result)
          expect(SystemNoteService).to receive(:new_issue_branch).and_return(true)

          post :create,
               params: {
                 namespace_id: project.namespace.to_param,
                 project_id: project.to_param,
                 branch_name: branch,
                 issue_iid: issue.iid
               }

          expect(response).to redirect_to project_tree_path(project, branch)
        end

        context 'when user configured kubernetes from CI/CD > Clusters' do
          before do
            create(:cluster, :provided_by_gcp, projects: [project])
          end

          it 'redirects to autodeploy setup page' do
            result = { status: :success, branch: double(name: branch) }

            expect_any_instance_of(CreateBranchService).to receive(:execute).and_return(result)
            expect(SystemNoteService).to receive(:new_issue_branch).and_return(true)

            post :create,
                 params: {
                   namespace_id: project.namespace.to_param,
                   project_id: project.to_param,
                   branch_name: branch,
                   issue_iid: issue.iid
                 }

            expect(response.location).to include(project_new_blob_path(project, branch))
            expect(response).to have_gitlab_http_status(302)
          end
        end

        it 'redirects to autodeploy setup page' do
          result = { status: :success, branch: double(name: branch) }

          create(:cluster, :provided_by_gcp, projects: [project])

          expect_any_instance_of(CreateBranchService).to receive(:execute).and_return(result)
          expect(SystemNoteService).to receive(:new_issue_branch).and_return(true)

          post :create,
               params: {
                namespace_id: project.namespace.to_param,
                project_id: project.to_param,
                branch_name: branch,
                issue_iid: issue.iid
               }

          expect(response.location).to include(project_new_blob_path(project, branch))
          expect(response).to have_gitlab_http_status(302)
        end
      end

      context 'when create branch service fails' do
        let(:branch) { "./invalid-branch-name" }

        it "doesn't post a system note" do
          expect(SystemNoteService).not_to receive(:new_issue_branch)

          post :create,
               params: {
                namespace_id: project.namespace,
                project_id: project,
                branch_name: branch,
                issue_iid: issue.iid
               }
        end
      end

      context 'without issue feature access' do
        before do
          project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
          project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
          project.team.truncate
        end

        it "doesn't post a system note" do
          expect(SystemNoteService).not_to receive(:new_issue_branch)

          post :create,
               params: {
                namespace_id: project.namespace,
                project_id: project,
                branch_name: branch,
                issue_iid: issue.iid
               }
        end
      end
    end
  end

  describe 'POST create with JSON format' do
    before do
      sign_in(user)
    end

    context 'with valid params' do
      it 'returns a successful 200 response' do
        create_branch name: 'my-branch', ref: 'master'

        expect(response).to have_gitlab_http_status(200)
      end

      it 'returns the created branch' do
        create_branch name: 'my-branch', ref: 'master'

        expect(response).to match_response_schema('branch')
      end
    end

    context 'with invalid params' do
      it 'returns an unprocessable entity 422 response' do
        create_branch name: "<script>alert('merge');</script>", ref: "<script>alert('ref');</script>"

        expect(response).to have_gitlab_http_status(422)
      end
    end

    def create_branch(name:, ref:)
      post :create,
           format: :json,
           params: {
             namespace_id: project.namespace.to_param,
             project_id: project.to_param,
             branch_name: name,
             ref: ref
           }
    end
  end

  describe "POST destroy with HTML format" do
    render_views

    before do
      sign_in(user)
    end

    it 'returns 303' do
      post :destroy,
           format: :html,
           params: {
             id: 'foo/bar/baz',
             namespace_id: project.namespace,
             project_id: project
           }

      expect(response).to have_gitlab_http_status(303)
    end
  end

  describe "POST destroy" do
    render_views

    before do
      sign_in(user)

      post :destroy,
           format: format,
           params: {
             id: branch,
             namespace_id: project.namespace,
             project_id: project
           }
    end

    context 'as JS' do
      let(:branch) { "feature" }
      let(:format) { :js }

      context "valid branch name, valid source" do
        let(:branch) { "feature" }

        it { expect(response).to have_gitlab_http_status(200) }
        it { expect(response.body).to be_blank }
      end

      context "valid branch name with unencoded slashes" do
        let(:branch) { "improve/awesome" }

        it { expect(response).to have_gitlab_http_status(200) }
        it { expect(response.body).to be_blank }
      end

      context "valid branch name with encoded slashes" do
        let(:branch) { "improve%2Fawesome" }

        it { expect(response).to have_gitlab_http_status(200) }
        it { expect(response.body).to be_blank }
      end

      context "invalid branch name, valid ref" do
        let(:branch) { "no-branch" }

        it { expect(response).to have_gitlab_http_status(404) }
        it { expect(response.body).to be_blank }
      end
    end

    context 'as JSON' do
      let(:branch) { "feature" }
      let(:format) { :json }

      context 'valid branch name, valid source' do
        let(:branch) { "feature" }

        it 'returns JSON response with message' do
          expect(json_response).to eql("message" => 'Branch was deleted')
        end

        it { expect(response).to have_gitlab_http_status(200) }
      end

      context 'valid branch name with unencoded slashes' do
        let(:branch) { "improve/awesome" }

        it 'returns JSON response with message' do
          expect(json_response).to eql('message' => 'Branch was deleted')
        end

        it { expect(response).to have_gitlab_http_status(200) }
      end

      context "valid branch name with encoded slashes" do
        let(:branch) { 'improve%2Fawesome' }

        it 'returns JSON response with message' do
          expect(json_response).to eql('message' => 'Branch was deleted')
        end

        it { expect(response).to have_gitlab_http_status(200) }
      end

      context 'invalid branch name, valid ref' do
        let(:branch) { 'no-branch' }

        it 'returns JSON response with message' do
          expect(json_response).to eql('message' => 'No such branch')
        end

        it { expect(response).to have_gitlab_http_status(404) }
      end
    end

    context 'as HTML' do
      let(:branch) { "feature" }
      let(:format) { :html }

      it 'redirects to branches path' do
        expect(response)
          .to redirect_to(project_branches_path(project))
      end
    end
  end

  describe "DELETE destroy_all_merged" do
    def destroy_all_merged
      delete :destroy_all_merged,
             params: {
               namespace_id: project.namespace,
               project_id: project
             }
    end

    context 'when user is allowed to push' do
      before do
        sign_in(user)
      end

      it 'redirects to branches' do
        destroy_all_merged

        expect(response).to redirect_to project_branches_path(project)
      end

      it 'starts worker to delete merged branches' do
        expect_any_instance_of(DeleteMergedBranchesService).to receive(:async_execute)

        destroy_all_merged
      end
    end

    context 'when user is not allowed to push' do
      before do
        sign_in(developer)
      end

      it 'responds with status 404' do
        destroy_all_merged

        expect(response).to have_gitlab_http_status(404)
      end
    end
  end

  describe "GET index" do
    render_views

    before do
      sign_in(user)
    end

    context 'when rendering a JSON format' do
      it 'filters branches by name' do
        get :index,
            format: :json,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              search: 'master'
            }

        expect(json_response.length).to eq 1
        expect(json_response.first).to eq 'master'
      end
    end

    # We need :request_store because Gitaly only counts the queries whenever
    # `RequestStore.active?` in GitalyClient.enforce_gitaly_request_limits
    # And the main goal of this test is making sure TooManyInvocationsError
    # was not raised whenever the cache is enabled yet cold.
    context 'when cache is enabled yet cold', :request_store do
      it 'return with a status 200' do
        get :index,
            format: :html,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              state: 'all'
            }

        expect(response).to have_gitlab_http_status(200)
      end
    end

    context 'when branch contains an invalid UTF-8 sequence' do
      before do
        project.repository.create_branch("wrong-\xE5-utf8-sequence")
      end

      it 'return with a status 200' do
        get :index,
            format: :html,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              state: 'all'
            }

        expect(response).to have_gitlab_http_status(200)
      end
    end

    context 'when deprecated sort/search/page parameters are specified' do
      it 'returns with a status 301 when sort specified' do
        get :index,
            format: :html,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              sort: 'updated_asc'
            }

        expect(response).to redirect_to project_branches_filtered_path(project, state: 'all')
      end

      it 'returns with a status 301 when search specified' do
        get :index,
            format: :html,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              search: 'feature'
            }

        expect(response).to redirect_to project_branches_filtered_path(project, state: 'all')
      end

      it 'returns with a status 301 when page specified' do
        get :index,
            format: :html,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              page: 2
            }

        expect(response).to redirect_to project_branches_filtered_path(project, state: 'all')
      end
    end
  end

  describe 'GET diverging_commit_counts' do
    before do
      sign_in(user)
    end

    it 'returns the commit counts behind and ahead of default branch' do
      get :diverging_commit_counts,
          format: :json,
          params: {
            namespace_id: project.namespace,
            project_id: project,
            names: ['fix', 'add-pdf-file', 'branch-merged']
          }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response).to eq(
        "fix" => { "behind" => 29, "ahead" => 2 },
        "branch-merged" => { "behind" => 1, "ahead" => 0 },
        "add-pdf-file" => { "behind" => 0, "ahead" => 3 }
      )
    end

    it 'returns the commits counts with no names provided' do
      allow_any_instance_of(Repository).to receive(:branch_count).and_return(Kaminari.config.default_per_page)

      get :diverging_commit_counts,
          format: :json,
          params: {
            namespace_id: project.namespace,
            project_id: project
          }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response.count).to be > 1
    end

    describe 'with many branches' do
      before do
        allow_any_instance_of(Repository).to receive(:branch_count).and_return(Kaminari.config.default_per_page + 1)
      end

      it 'returns 422 if no names are specified' do
        get :diverging_commit_counts,
            format: :json,
            params: {
              namespace_id: project.namespace,
              project_id: project
            }

        expect(response).to have_gitlab_http_status(422)
        expect(json_response['error']).to eq("Specify at least one and at most #{Kaminari.config.default_per_page} branch names")
      end

      it 'returns the list of counts' do
        get :diverging_commit_counts,
            format: :json,
            params: {
              namespace_id: project.namespace,
              project_id: project,
              names: ['fix', 'add-pdf-file', 'branch-merged']
            }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response.count).to be > 1
      end
    end
  end
end

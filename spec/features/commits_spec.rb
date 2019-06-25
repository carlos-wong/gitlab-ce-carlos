require 'spec_helper'

describe 'Commits' do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }

  describe 'CI' do
    before do
      sign_in(user)
      stub_ci_pipeline_to_return_yaml_file
    end

    let(:creator) { create(:user, developer_projects: [project]) }
    let!(:pipeline) do
      create(:ci_pipeline,
             project: project,
             user: creator,
             ref: project.default_branch,
             sha: project.commit.sha,
             status: :success,
             created_at: 5.months.ago)
    end

    context 'commit status is Generic Commit Status' do
      let!(:status) { create(:generic_commit_status, pipeline: pipeline) }

      before do
        project.add_reporter(user)
      end

      describe 'Commit builds' do
        before do
          visit pipeline_path(pipeline)
        end

        it { expect(page).to have_content pipeline.sha[0..7] }

        it 'contains generic commit status build' do
          page.within('.table-holder') do
            expect(page).to have_content "##{status.id}" # build id
            expect(page).to have_content 'generic'       # build name
          end
        end
      end
    end

    context 'commit status is Ci Build' do
      let!(:build) { create(:ci_build, pipeline: pipeline) }
      let(:artifacts_file) { fixture_file_upload('spec/fixtures/banana_sample.gif', 'image/gif') }

      context 'when logged as developer' do
        before do
          project.add_developer(user)
        end

        describe 'Project commits' do
          let!(:pipeline_from_other_branch) do
            create(:ci_pipeline,
                   project: project,
                   ref: 'fix',
                   sha: project.commit.sha,
                   status: :failed)
          end

          before do
            visit project_commits_path(project, :master)
          end

          it 'shows correct build status from default branch' do
            page.within("//li[@id='commit-#{pipeline.short_sha}']") do
              expect(page).to have_css('.ci-status-link')
              expect(page).to have_css('.ci-status-icon-success')
            end
          end
        end

        describe 'Commit builds', :js do
          before do
            project.add_developer(user)
            visit pipeline_path(pipeline)
          end

          it 'shows pipeline data' do
            expect(page).to have_content pipeline.sha[0..7]
            expect(page).to have_content pipeline.git_commit_message.gsub!(/\s+/, ' ')
            expect(page).to have_content pipeline.user.name
          end
        end

        context 'Download artifacts' do
          before do
            create(:ci_job_artifact, :archive, file: artifacts_file, job: build)
          end

          it do
            visit pipeline_path(pipeline)
            click_on 'Download artifacts'
            expect(page.response_headers['Content-Type']).to eq(artifacts_file.content_type)
          end
        end

        describe 'Cancel all builds' do
          it 'cancels commit', :js do
            visit pipeline_path(pipeline)
            click_on 'Cancel running'
            expect(page).to have_content 'canceled'
          end
        end

        describe 'Cancel build' do
          it 'cancels build', :js do
            visit pipeline_path(pipeline)
            find('.js-btn-cancel-pipeline').click
            expect(page).to have_content 'canceled'
          end
        end
      end

      context "when logged as reporter" do
        before do
          project.add_reporter(user)
          create(:ci_job_artifact, :archive, file: artifacts_file, job: build)
          visit pipeline_path(pipeline)
        end

        it 'Renders header', :js do
          expect(page).to have_content pipeline.sha[0..7]
          expect(page).to have_content pipeline.git_commit_message.gsub!(/\s+/, ' ')
          expect(page).to have_content pipeline.user.name
          expect(page).not_to have_link('Cancel running')
          expect(page).not_to have_link('Retry')
        end

        it do
          expect(page).to have_link('Download artifacts')
        end
      end

      context 'when accessing internal project with disallowed access', :js do
        before do
          project.update(
            visibility_level: Gitlab::VisibilityLevel::INTERNAL,
            public_builds: false)
          create(:ci_job_artifact, :archive, file: artifacts_file, job: build)
          visit pipeline_path(pipeline)
        end

        it do
          expect(page).to have_content pipeline.sha[0..7]
          expect(page).to have_content pipeline.git_commit_message.gsub!(/\s+/, ' ')
          expect(page).to have_content pipeline.user.name

          expect(page).not_to have_link('Cancel running')
          expect(page).not_to have_link('Retry')
        end
      end
    end

    describe '.gitlab-ci.yml not found warning' do
      before do
        project.add_reporter(user)
      end

      context 'ci builds enabled' do
        it 'does not show warning' do
          visit pipeline_path(pipeline)

          expect(page).not_to have_content '.gitlab-ci.yml not found in this commit'
        end

        it 'shows warning' do
          stub_ci_pipeline_yaml_file(nil)

          visit pipeline_path(pipeline)

          expect(page).to have_content '.gitlab-ci.yml not found in this commit'
        end
      end

      context 'ci builds disabled' do
        it 'does not show warning' do
          stub_ci_builds_disabled
          stub_ci_pipeline_yaml_file(nil)

          visit pipeline_path(pipeline)

          expect(page).not_to have_content '.gitlab-ci.yml not found in this commit'
        end
      end
    end
  end

  context 'viewing commits for a branch' do
    let(:branch_name) { 'master' }

    before do
      project.add_maintainer(user)
      sign_in(user)
      visit project_commits_path(project, branch_name)
    end

    it 'includes the committed_date for each commit' do
      commits = project.repository.commits(branch_name, limit: 40)

      commits.each do |commit|
        expect(page).to have_content("authored #{commit.authored_date.strftime("%b %d, %Y")}")
      end
    end

    it 'shows the ref switcher with the multi-file editor enabled', :js do
      set_cookie('new_repo', 'true')
      visit project_commits_path(project, branch_name)

      expect(find('.js-project-refs-dropdown')).to have_content branch_name
    end
  end
end

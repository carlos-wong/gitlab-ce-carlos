# frozen_string_literal: true
require 'spec_helper'

describe ChatMessage::PipelineMessage do
  subject { described_class.new(args) }

  let(:args) do
    {
      object_attributes: {
        id: 123,
        sha: '97de212e80737a608d939f648d959671fb0a0142',
        tag: false,
        ref: 'develop',
        status: 'success',
        detailed_status: nil,
        duration: 7210,
        finished_at: "2019-05-27 11:56:36 -0300"
      },
      project: {
        id: 234,
        name: "project_name",
        path_with_namespace: 'group/project_name',
        web_url: 'http://example.gitlab.com',
        avatar_url: 'http://example.com/project_avatar'
      },
      user: {
        id: 345,
        name: "The Hacker",
        username: "hacker",
        email: "hacker@example.gitlab.com",
        avatar_url: "http://example.com/avatar"
      },
      commit: {
        id: "abcdef"
      },
      builds: nil,
      markdown: false
    }
  end

  let(:has_yaml_errors) { false }

  before do
    test_commit = double("A test commit", committer: args[:user], title: "A test commit message")
    test_project = double("A test project", commit_by: test_commit, name: args[:project][:name], web_url: args[:project][:web_url])
    allow(test_project).to receive(:avatar_url).with(no_args).and_return("/avatar")
    allow(test_project).to receive(:avatar_url).with(only_path: false).and_return(args[:project][:avatar_url])
    allow(Project).to receive(:find) { test_project }

    test_pipeline = double("A test pipeline", has_yaml_errors?: has_yaml_errors,
                          yaml_errors: "yaml error description here")
    allow(Ci::Pipeline).to receive(:find) { test_pipeline }

    allow(Gitlab::UrlBuilder).to receive(:build).with(test_commit).and_return("http://example.com/commit")
    allow(Gitlab::UrlBuilder).to receive(:build).with(args[:user]).and_return("http://example.gitlab.com/hacker")
  end

  context 'when the fancy_pipeline_slack_notifications feature flag is disabled' do
    before do
      stub_feature_flags(fancy_pipeline_slack_notifications: false)
    end

    it 'returns an empty pretext' do
      expect(subject.pretext).to be_empty
    end

    it "returns the pipeline summary in the activity's title" do
      expect(subject.activity[:title]).to eq(
        "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
          " of branch [develop](http://example.gitlab.com/commits/develop)" \
          " by The Hacker (hacker) passed"
      )
    end

    context "when the pipeline failed" do
      before do
        args[:object_attributes][:status] = 'failed'
      end

      it "returns the summary with a 'failed' status" do
        expect(subject.activity[:title]).to eq(
          "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by The Hacker (hacker) failed"
        )
      end
    end

    context 'when no user is provided because the pipeline was triggered by the API' do
      before do
        args[:user] = nil
      end

      it "returns the summary with 'API' as the username" do
        expect(subject.activity[:title]).to eq(
          "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by API passed"
        )
      end
    end

    it "returns a link to the project in the activity's subtitle" do
      expect(subject.activity[:subtitle]).to eq("in [project_name](http://example.gitlab.com)")
    end

    it "returns the build duration in the activity's text property" do
      expect(subject.activity[:text]).to eq("in 02:00:10")
    end

    it "returns the user's avatar image URL in the activity's image property" do
      expect(subject.activity[:image]).to eq("http://example.com/avatar")
    end

    context 'when the user does not have an avatar' do
      before do
        args[:user][:avatar_url] = nil
      end

      it "returns an empty string in the activity's image property" do
        expect(subject.activity[:image]).to be_empty
      end
    end

    it "returns the pipeline summary as the attachment's text property" do
      expect(subject.attachments.first[:text]).to eq(
        "<http://example.gitlab.com|project_name>:" \
          " Pipeline <http://example.gitlab.com/pipelines/123|#123>" \
          " of branch <http://example.gitlab.com/commits/develop|develop>" \
          " by The Hacker (hacker) passed in 02:00:10"
      )
    end

    it "returns 'good' as the attachment's color property" do
      expect(subject.attachments.first[:color]).to eq('good')
    end

    context "when the pipeline failed" do
      before do
        args[:object_attributes][:status] = 'failed'
      end

      it "returns 'danger' as the attachment's color property" do
        expect(subject.attachments.first[:color]).to eq('danger')
      end
    end

    context 'when rendering markdown' do
      before do
        args[:markdown] = true
      end

      it 'returns the pipeline summary as the attachments in markdown format' do
        expect(subject.attachments).to eq(
          "[project_name](http://example.gitlab.com):" \
            " Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by The Hacker (hacker) passed in 02:00:10"
        )
      end
    end

    context 'when ref type is tag' do
      before do
        args[:object_attributes][:tag] = true
        args[:object_attributes][:ref] = 'new_tag'
      end

      it "returns the pipeline summary in the activity's title" do
        expect(subject.activity[:title]).to eq(
          "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of tag [new_tag](http://example.gitlab.com/-/tags/new_tag)" \
            " by The Hacker (hacker) passed"
        )
      end

      it "returns the pipeline summary as the attachment's text property" do
        expect(subject.attachments.first[:text]).to eq(
          "<http://example.gitlab.com|project_name>:" \
            " Pipeline <http://example.gitlab.com/pipelines/123|#123>" \
            " of tag <http://example.gitlab.com/-/tags/new_tag|new_tag>" \
            " by The Hacker (hacker) passed in 02:00:10"
        )
      end

      context 'when rendering markdown' do
        before do
          args[:markdown] = true
        end

        it 'returns the pipeline summary as the attachments in markdown format' do
          expect(subject.attachments).to eq(
            "[project_name](http://example.gitlab.com):" \
              " Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
              " of tag [new_tag](http://example.gitlab.com/-/tags/new_tag)" \
              " by The Hacker (hacker) passed in 02:00:10"
          )
        end
      end
    end
  end

  context 'when the fancy_pipeline_slack_notifications feature flag is enabled' do
    before do
      stub_feature_flags(fancy_pipeline_slack_notifications: true)
    end

    it 'returns an empty pretext' do
      expect(subject.pretext).to be_empty
    end

    it "returns the pipeline summary in the activity's title" do
      expect(subject.activity[:title]).to eq(
        "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
          " of branch [develop](http://example.gitlab.com/commits/develop)" \
          " by The Hacker (hacker) has passed"
      )
    end

    context "when the pipeline failed" do
      before do
        args[:object_attributes][:status] = 'failed'
      end

      it "returns the summary with a 'failed' status" do
        expect(subject.activity[:title]).to eq(
          "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by The Hacker (hacker) has failed"
        )
      end
    end

    context "when the pipeline passed with warnings" do
      before do
        args[:object_attributes][:detailed_status] = 'passed with warnings'
      end

      it "returns the summary with a 'passed with warnings' status" do
        expect(subject.activity[:title]).to eq(
          "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by The Hacker (hacker) has passed with warnings"
        )
      end
    end

    context 'when no user is provided because the pipeline was triggered by the API' do
      before do
        args[:user] = nil
      end

      it "returns the summary with 'API' as the username" do
        expect(subject.activity[:title]).to eq(
          "Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by API has passed"
        )
      end
    end

    it "returns a link to the project in the activity's subtitle" do
      expect(subject.activity[:subtitle]).to eq("in [project_name](http://example.gitlab.com)")
    end

    it "returns the build duration in the activity's text property" do
      expect(subject.activity[:text]).to eq("in 02:00:10")
    end

    it "returns the user's avatar image URL in the activity's image property" do
      expect(subject.activity[:image]).to eq("http://example.com/avatar")
    end

    context 'when the user does not have an avatar' do
      before do
        args[:user][:avatar_url] = nil
      end

      it "returns an empty string in the activity's image property" do
        expect(subject.activity[:image]).to be_empty
      end
    end

    it "returns the pipeline summary as the attachment's fallback property" do
      expect(subject.attachments.first[:fallback]).to eq(
        "<http://example.gitlab.com|project_name>:" \
          " Pipeline <http://example.gitlab.com/pipelines/123|#123>" \
          " of branch <http://example.gitlab.com/commits/develop|develop>" \
          " by The Hacker (hacker) has passed in 02:00:10"
      )
    end

    it "returns 'good' as the attachment's color property" do
      expect(subject.attachments.first[:color]).to eq('good')
    end

    context "when the pipeline failed" do
      before do
        args[:object_attributes][:status] = 'failed'
      end

      it "returns 'danger' as the attachment's color property" do
        expect(subject.attachments.first[:color]).to eq('danger')
      end
    end

    context "when the pipeline passed with warnings" do
      before do
        args[:object_attributes][:detailed_status] = 'passed with warnings'
      end

      it "returns 'warning' as the attachment's color property" do
        expect(subject.attachments.first[:color]).to eq('warning')
      end
    end

    it "returns the committer's name and username as the attachment's author_name property" do
      expect(subject.attachments.first[:author_name]).to eq('The Hacker (hacker)')
    end

    it "returns the committer's avatar URL as the attachment's author_icon property" do
      expect(subject.attachments.first[:author_icon]).to eq('http://example.com/avatar')
    end

    it "returns the committer's GitLab profile URL as the attachment's author_link property" do
      expect(subject.attachments.first[:author_link]).to eq('http://example.gitlab.com/hacker')
    end

    context 'when no user is provided because the pipeline was triggered by the API' do
      before do
        args[:user] = nil
      end

      it "returns the committer's name and username as the attachment's author_name property" do
        expect(subject.attachments.first[:author_name]).to eq('API')
      end

      it "returns nil as the attachment's author_icon property" do
        expect(subject.attachments.first[:author_icon]).to be_nil
      end

      it "returns nil as the attachment's author_link property" do
        expect(subject.attachments.first[:author_link]).to be_nil
      end
    end

    it "returns the pipeline ID, status, and duration as the attachment's title property" do
      expect(subject.attachments.first[:title]).to eq("Pipeline #123 has passed in 02:00:10")
    end

    it "returns the pipeline URL as the attachment's title_link property" do
      expect(subject.attachments.first[:title_link]).to eq("http://example.gitlab.com/pipelines/123")
    end

    it "returns two attachment fields" do
      expect(subject.attachments.first[:fields].count).to eq(2)
    end

    it "returns the commit message as the attachment's second field property" do
      expect(subject.attachments.first[:fields][0]).to eq({
        title: "Branch",
        value: "<http://example.gitlab.com/commits/develop|develop>",
        short: true
      })
    end

    it "returns the ref name and link as the attachment's second field property" do
      expect(subject.attachments.first[:fields][1]).to eq({
        title: "Commit",
        value: "<http://example.com/commit|A test commit message>",
        short: true
      })
    end

    context "when a job in the pipeline fails" do
      before do
        args[:builds] = [
          { id: 1, name: "rspec", status: "failed", stage: "test" },
          { id: 2, name: "karma", status: "success", stage: "test" }
        ]
      end

      it "returns four attachment fields" do
        expect(subject.attachments.first[:fields].count).to eq(4)
      end

      it "returns the stage name and link to the 'Failed jobs' tab on the pipeline's page as the attachment's third field property" do
        expect(subject.attachments.first[:fields][2]).to eq({
          title: "Failed stage",
          value: "<http://example.gitlab.com/pipelines/123/failures|test>",
          short: true
        })
      end

      it "returns the job name and link as the attachment's fourth field property" do
        expect(subject.attachments.first[:fields][3]).to eq({
          title: "Failed job",
          value: "<http://example.gitlab.com/-/jobs/1|rspec>",
          short: true
        })
      end
    end

    context "when lots of jobs across multiple stages fail" do
      before do
        args[:builds] = (1..25).map do |i|
          { id: i, name: "job-#{i}", status: "failed", stage: "stage-" + ((i % 3) + 1).to_s }
        end
      end

      it "returns the stage names and links to the 'Failed jobs' tab on the pipeline's page as the attachment's third field property" do
        expect(subject.attachments.first[:fields][2]).to eq({
          title: "Failed stages",
          value: "<http://example.gitlab.com/pipelines/123/failures|stage-2>, <http://example.gitlab.com/pipelines/123/failures|stage-1>, <http://example.gitlab.com/pipelines/123/failures|stage-3>",
          short: true
        })
      end

      it "returns the job names and links as the attachment's fourth field property" do
        expected_jobs = 25.downto(16).map do |i|
          "<http://example.gitlab.com/-/jobs/#{i}|job-#{i}>"
        end

        expected_jobs << "and <http://example.gitlab.com/pipelines/123/failures|15 more>"

        expect(subject.attachments.first[:fields][3]).to eq({
          title: "Failed jobs",
          value: expected_jobs.join(", "),
          short: true
        })
      end
    end

    context "when the CI config file contains a YAML error" do
      let(:has_yaml_errors) { true }

      it "returns three attachment fields" do
        expect(subject.attachments.first[:fields].count).to eq(3)
      end

      it "returns the YAML error deatils as the attachment's third field property" do
        expect(subject.attachments.first[:fields][2]).to eq({
          title: "Invalid CI config YAML file",
          value: "yaml error description here",
          short: false
        })
      end
    end

    it "returns the stage name and link as the attachment's second field property" do
      expect(subject.attachments.first[:fields][1]).to eq({
        title: "Commit",
        value: "<http://example.com/commit|A test commit message>",
        short: true
      })
    end

    it "returns the project's name as the attachment's footer property" do
      expect(subject.attachments.first[:footer]).to eq("project_name")
    end

    it "returns the project's avatar URL as the attachment's footer_icon property" do
      expect(subject.attachments.first[:footer_icon]).to eq("http://example.com/project_avatar")
    end

    it "returns the pipeline's timestamp as the attachment's ts property" do
      expected_ts = Time.parse(args[:object_attributes][:finished_at]).to_i
      expect(subject.attachments.first[:ts]).to eq(expected_ts)
    end

    context 'when rendering markdown' do
      before do
        args[:markdown] = true
      end

      it 'returns the pipeline summary as the attachments in markdown format' do
        expect(subject.attachments).to eq(
          "[project_name](http://example.gitlab.com):" \
            " Pipeline [#123](http://example.gitlab.com/pipelines/123)" \
            " of branch [develop](http://example.gitlab.com/commits/develop)" \
            " by The Hacker (hacker) has passed in 02:00:10"
        )
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Importer::IssueEventImporter, :clean_gitlab_redis_cache do
  let(:importer) { described_class.new(issue_event, project, client) }

  let(:project) { create(:project) }
  let(:client) { instance_double('Gitlab::GithubImport::Client') }
  let(:user) { create(:user) }
  let(:issue) { create(:issue, project: project) }

  let(:issue_event) do
    Gitlab::GithubImport::Representation::IssueEvent.from_json_hash(
      'id' => 6501124486,
      'node_id' => 'CE_lADOHK9fA85If7x0zwAAAAGDf0mG',
      'url' => 'https://api.github.com/repos/elhowm/test-import/issues/events/6501124486',
      'actor' => { 'id' => actor_id, 'login' => 'alice' },
      'event' => event_name,
      'commit_id' => '570e7b2abdd848b95f2f578043fc23bd6f6fd24d',
      'commit_url' =>
        'https://api.github.com/repos/octocat/Hello-World/commits/570e7b2abdd848b95f2f578043fc23bd6f6fd24d',
      'created_at' => '2022-04-26 18:30:53 UTC',
      'performed_via_github_app' => nil
    )
  end

  let(:actor_id) { user.id }
  let(:event_name) { 'closed' }

  shared_examples 'triggers specific event importer' do |importer_class|
    it importer_class.name do
      specific_importer = double(importer_class.name) # rubocop:disable RSpec/VerifiedDoubles

      expect(importer_class)
        .to receive(:new).with(project, user.id)
        .and_return(specific_importer)
      expect(specific_importer).to receive(:execute).with(issue_event)

      importer.execute
    end
  end

  describe '#execute' do
    before do
      allow_next_instance_of(Gitlab::GithubImport::UserFinder) do |finder|
        allow(finder).to receive(:author_id_for)
          .with(issue_event, author_key: :actor)
          .and_return(user.id, true)
      end

      issue_event.attributes[:issue_db_id] = issue.id
    end

    context "when it's closed issue event" do
      let(:event_name) { 'closed' }

      it_behaves_like 'triggers specific event importer',
                      Gitlab::GithubImport::Importer::Events::Closed
    end

    context "when it's reopened issue event" do
      let(:event_name) { 'reopened' }

      it_behaves_like 'triggers specific event importer',
                      Gitlab::GithubImport::Importer::Events::Reopened
    end

    context "when it's labeled issue event" do
      let(:event_name) { 'labeled' }

      it_behaves_like 'triggers specific event importer',
                      Gitlab::GithubImport::Importer::Events::ChangedLabel
    end

    context "when it's unlabeled issue event" do
      let(:event_name) { 'unlabeled' }

      it_behaves_like 'triggers specific event importer',
                      Gitlab::GithubImport::Importer::Events::ChangedLabel
    end

    context "when it's renamed issue event" do
      let(:event_name) { 'renamed' }

      it_behaves_like 'triggers specific event importer',
                      Gitlab::GithubImport::Importer::Events::Renamed
    end

    context "when it's cross-referenced issue event" do
      let(:event_name) { 'cross-referenced' }

      it_behaves_like 'triggers specific event importer',
                      Gitlab::GithubImport::Importer::Events::CrossReferenced
    end

    context "when it's unknown issue event" do
      let(:event_name) { 'fake' }

      it 'logs warning and skips' do
        expect(Gitlab::GithubImport::Logger).to receive(:debug)
          .with(
            message: 'UNSUPPORTED_EVENT_TYPE',
            event_type: issue_event.event,
            event_github_id: issue_event.id
          )

        importer.execute
      end
    end
  end
end

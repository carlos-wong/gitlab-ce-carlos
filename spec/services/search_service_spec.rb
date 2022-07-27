# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchService do
  let_it_be(:user) { create(:user) }

  let_it_be(:accessible_group) { create(:group, :private) }
  let_it_be(:inaccessible_group) { create(:group, :private) }
  let_it_be(:group_member) { create(:group_member, group: accessible_group, user: user) }

  let_it_be(:accessible_project) { create(:project, :repository, :private, name: 'accessible_project') }
  let_it_be(:note) { create(:note_on_issue, project: accessible_project) }

  let_it_be(:inaccessible_project) { create(:project, :repository, :private, name: 'inaccessible_project') }

  let(:snippet) { create(:snippet, author: user) }
  let(:group_project) { create(:project, group: accessible_group, name: 'group_project') }
  let(:public_project) { create(:project, :public, name: 'public_project') }

  let(:page) { 1 }
  let(:per_page) { described_class::DEFAULT_PER_PAGE }
  let(:valid_search) { "what is love?" }

  subject(:search_service) { described_class.new(user, search: search, scope: scope, page: page, per_page: per_page) }

  before do
    accessible_project.add_maintainer(user)
  end

  describe '#project' do
    context 'when the project is accessible' do
      it 'returns the project' do
        project = described_class.new(user, project_id: accessible_project.id, search: valid_search).project

        expect(project).to eq accessible_project
      end

      it 'returns the project for guests' do
        search_project = create :project
        search_project.add_guest(user)

        project = described_class.new(user, project_id: search_project.id, search: valid_search).project

        expect(project).to eq search_project
      end
    end

    context 'when the project is not accessible' do
      it 'returns nil' do
        project = described_class.new(user, project_id: inaccessible_project.id, search: valid_search).project

        expect(project).to be_nil
      end
    end

    context 'when there is no project_id' do
      it 'returns nil' do
        project = described_class.new(user, search: valid_search).project

        expect(project).to be_nil
      end
    end
  end

  describe '#group' do
    context 'when the group is accessible' do
      it 'returns the group' do
        group = described_class.new(user, group_id: accessible_group.id, search: valid_search).group

        expect(group).to eq accessible_group
      end
    end

    context 'when the group is not accessible' do
      it 'returns nil' do
        group = described_class.new(user, group_id: inaccessible_group.id, search: valid_search).group

        expect(group).to be_nil
      end
    end

    context 'when there is no group_id' do
      it 'returns nil' do
        group = described_class.new(user, search: valid_search).group

        expect(group).to be_nil
      end
    end
  end

  describe '#show_snippets?' do
    context 'when :snippets is \'true\'' do
      it 'returns true' do
        show_snippets = described_class.new(user, snippets: 'true').show_snippets?

        expect(show_snippets).to be_truthy
      end
    end

    context 'when :snippets is not \'true\'' do
      it 'returns false' do
        show_snippets = described_class.new(user, snippets: 'tru').show_snippets?

        expect(show_snippets).to be_falsey
      end
    end

    context 'when :snippets is missing' do
      it 'returns false' do
        show_snippets = described_class.new(user).show_snippets?

        expect(show_snippets).to be_falsey
      end
    end
  end

  describe '#scope' do
    context 'with accessible project_id' do
      context 'and allowed scope' do
        it 'returns the specified scope' do
          scope = described_class.new(user, project_id: accessible_project.id, scope: 'notes', search: valid_search).scope

          expect(scope).to eq 'notes'
        end
      end

      context 'and disallowed scope' do
        it 'returns the default scope' do
          scope = described_class.new(user, project_id: accessible_project.id, scope: 'projects', search: valid_search).scope

          expect(scope).to eq 'blobs'
        end
      end

      context 'and no scope' do
        it 'returns the default scope' do
          scope = described_class.new(user, project_id: accessible_project.id, search: valid_search).scope

          expect(scope).to eq 'blobs'
        end
      end
    end

    context 'with \'true\' snippets' do
      context 'and allowed scope' do
        it 'returns the specified scope' do
          scope = described_class.new(user, snippets: 'true', scope: 'snippet_titles').scope

          expect(scope).to eq 'snippet_titles'
        end
      end

      context 'and disallowed scope' do
        it 'returns the default scope' do
          scope = described_class.new(user, snippets: 'true', scope: 'projects').scope

          expect(scope).to eq 'snippet_titles'
        end
      end

      context 'and no scope' do
        it 'returns the default scope' do
          scope = described_class.new(user, snippets: 'true').scope

          expect(scope).to eq 'snippet_titles'
        end
      end
    end

    context 'with no project_id, no snippets' do
      context 'and allowed scope' do
        it 'returns the specified scope' do
          scope = described_class.new(user, scope: 'issues').scope

          expect(scope).to eq 'issues'
        end
      end

      context 'and disallowed scope' do
        it 'returns the default scope' do
          scope = described_class.new(user, scope: 'blobs').scope

          expect(scope).to eq 'projects'
        end
      end

      context 'and no scope' do
        it 'returns the default scope' do
          scope = described_class.new(user).scope

          expect(scope).to eq 'projects'
        end
      end
    end
  end

  describe '#search_results' do
    context 'with accessible project_id' do
      it 'returns an instance of Gitlab::ProjectSearchResults' do
        search_results = described_class.new(
          user,
          project_id: accessible_project.id,
          scope: 'notes',
          search: note.note).search_results

        expect(search_results).to be_a Gitlab::ProjectSearchResults
      end
    end

    context 'with accessible project_id and \'true\' snippets' do
      it 'returns an instance of Gitlab::ProjectSearchResults' do
        search_results = described_class.new(
          user,
          project_id: accessible_project.id,
          snippets: 'true',
          scope: 'notes',
          search: note.note).search_results

        expect(search_results).to be_a Gitlab::ProjectSearchResults
      end
    end

    context 'with \'true\' snippets' do
      it 'returns an instance of Gitlab::SnippetSearchResults' do
        search_results = described_class.new(
          user,
          snippets: 'true',
          search: snippet.title).search_results

        expect(search_results).to be_a Gitlab::SnippetSearchResults
      end
    end

    context 'with no project_id and no snippets' do
      it 'returns an instance of Gitlab::SearchResults' do
        search_results = described_class.new(
          user,
          search: public_project.name).search_results

        expect(search_results).to be_a Gitlab::SearchResults
      end
    end
  end

  describe '#search_objects' do
    let(:search) { '' }
    let(:scope) { nil }

    describe 'per_page: parameter' do
      context 'when nil' do
        let(:per_page) { nil }

        it "defaults to #{described_class::DEFAULT_PER_PAGE}" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(per_page: described_class::DEFAULT_PER_PAGE))
            .and_call_original

          subject.search_objects
        end
      end

      context 'when empty string' do
        let(:per_page) { '' }

        it "defaults to #{described_class::DEFAULT_PER_PAGE}" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(per_page: described_class::DEFAULT_PER_PAGE))
            .and_call_original

          subject.search_objects
        end
      end

      context 'when negative' do
        let(:per_page) { '-1' }

        it "defaults to #{described_class::DEFAULT_PER_PAGE}" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(per_page: described_class::DEFAULT_PER_PAGE))
            .and_call_original

          subject.search_objects
        end
      end

      context 'when present' do
        let(:per_page) { '50' }

        it "converts to integer and passes to search results" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(per_page: 50))
            .and_call_original

          subject.search_objects
        end
      end

      context "when greater than #{described_class::MAX_PER_PAGE}" do
        let(:per_page) { described_class::MAX_PER_PAGE + 1 }

        it "passes #{described_class::MAX_PER_PAGE}" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(per_page: described_class::MAX_PER_PAGE))
            .and_call_original

          subject.search_objects
        end
      end
    end

    describe 'page: parameter' do
      context 'when < 1' do
        let(:page) { 0 }

        it "defaults to 1" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(page: 1))
            .and_call_original

          subject.search_objects
        end
      end

      context 'when nil' do
        let(:page) { nil }

        it "defaults to 1" do
          expect_any_instance_of(Gitlab::SearchResults)
            .to receive(:objects)
            .with(anything, hash_including(page: 1))
            .and_call_original

          subject.search_objects
        end
      end
    end

    context 'with accessible project_id' do
      it 'returns objects in the project' do
        search_objects = described_class.new(
          user,
          project_id: accessible_project.id,
          scope: 'notes',
          search: note.note).search_objects

        expect(search_objects.first).to eq note
      end
    end

    context 'with accessible project_id and \'true\' snippets' do
      it 'returns objects in the project' do
        search_objects = described_class.new(
          user,
          project_id: accessible_project.id,
          snippets: 'true',
          scope: 'notes',
          search: note.note).search_objects

        expect(search_objects.first).to eq note
      end
    end

    context 'with \'true\' snippets' do
      it 'returns objects in snippets' do
        search_objects = described_class.new(
          user,
          snippets: 'true',
          search: snippet.title).search_objects

        expect(search_objects.first).to eq snippet
      end
    end

    context 'with accessible group_id' do
      it 'returns objects in the group' do
        search_objects = described_class.new(
          user,
          group_id: accessible_group.id,
          search: group_project.name).search_objects

        expect(search_objects.first).to eq group_project
      end
    end

    context 'with no project_id, group_id or snippets' do
      it 'returns objects in global' do
        search_objects = described_class.new(
          user,
          search: public_project.name).search_objects

        expect(search_objects.first).to eq public_project
      end
    end

    context 'redacting search results' do
      let(:search) { 'anything' }

      subject(:result) { search_service.search_objects }

      shared_examples "redaction limits N+1 queries" do |limit:|
        it 'does not exceed the query limit' do
          # issuing the query to remove the data loading call
          unredacted_results.to_a

          # only the calls from the redaction are left
          query = ActiveRecord::QueryRecorder.new { result }

          # these are the project authorization calls, which are not preloaded
          expect(query.count).to be <= limit
        end
      end

      def found_blob(project)
        Gitlab::Search::FoundBlob.new(project: project)
      end

      def found_wiki_page(project)
        Gitlab::Search::FoundWikiPage.new(found_blob(project))
      end

      before do
        expect(search_service)
          .to receive(:search_results)
          .and_return(double('search results', objects: unredacted_results))
      end

      def ar_relation(klass, *objects)
        klass.id_in(objects.map(&:id))
      end

      def kaminari_array(*objects)
        Kaminari.paginate_array(objects).page(1).per(20)
      end

      context 'issues' do
        let(:readable) { create(:issue, project: accessible_project) }
        let(:unreadable) { create(:issue, project: inaccessible_project) }
        let(:unredacted_results) { ar_relation(Issue, readable, unreadable) }
        let(:scope) { 'issues' }

        it 'redacts the inaccessible issue' do
          expect(result).to contain_exactly(readable)
        end
      end

      context 'notes' do
        let(:readable) { create(:note_on_commit, project: accessible_project) }
        let(:unreadable) { create(:note_on_commit, project: inaccessible_project) }
        let(:unredacted_results) { ar_relation(Note, readable, unreadable) }
        let(:scope) { 'notes' }

        it 'redacts the inaccessible note' do
          expect(result).to contain_exactly(readable)
        end
      end

      context 'merge_requests' do
        let(:readable) { create(:merge_request, source_project: accessible_project, author: user) }
        let(:unreadable) { create(:merge_request, source_project: inaccessible_project) }
        let(:unredacted_results) { ar_relation(MergeRequest, readable, unreadable) }
        let(:scope) { 'merge_requests' }

        it 'redacts the inaccessible merge request' do
          expect(result).to contain_exactly(readable)
        end

        context 'with :with_api_entity_associations' do
          let(:unredacted_results) { ar_relation(MergeRequest.with_api_entity_associations, readable, unreadable) }

          it_behaves_like "redaction limits N+1 queries", limit: 8
        end
      end

      context 'project repository blobs' do
        let(:readable) { found_blob(accessible_project) }
        let(:unreadable) { found_blob(inaccessible_project) }
        let(:unredacted_results) { kaminari_array(readable, unreadable) }
        let(:scope) { 'blobs' }

        it 'redacts the inaccessible blob' do
          expect(result).to contain_exactly(readable)
        end
      end

      context 'project wiki blobs' do
        let(:readable) { found_wiki_page(accessible_project) }
        let(:unreadable) { found_wiki_page(inaccessible_project) }
        let(:unredacted_results) { kaminari_array(readable, unreadable) }
        let(:scope) { 'wiki_blobs' }

        it 'redacts the inaccessible blob' do
          expect(result).to contain_exactly(readable)
        end
      end

      context 'project snippets' do
        let(:readable) { create(:project_snippet, project: accessible_project) }
        let(:unreadable) { create(:project_snippet, project: inaccessible_project) }
        let(:unredacted_results) { ar_relation(ProjectSnippet, readable, unreadable) }
        let(:scope) { 'snippet_titles' }

        it 'redacts the inaccessible snippet' do
          expect(result).to contain_exactly(readable)
        end

        context 'with :with_api_entity_associations' do
          it_behaves_like "redaction limits N+1 queries", limit: 14
        end
      end

      context 'personal snippets' do
        let(:readable) { create(:personal_snippet, :private, author: user) }
        let(:unreadable) { create(:personal_snippet, :private) }
        let(:unredacted_results) { ar_relation(PersonalSnippet, readable, unreadable) }
        let(:scope) { 'snippet_titles' }

        it 'redacts the inaccessible snippet' do
          expect(result).to contain_exactly(readable)
        end

        context 'with :with_api_entity_associations' do
          it_behaves_like "redaction limits N+1 queries", limit: 4
        end
      end

      context 'commits' do
        let(:readable) { accessible_project.commit }
        let(:unreadable) { inaccessible_project.commit }
        let(:unredacted_results) { kaminari_array(readable, unreadable) }
        let(:scope) { 'commits' }

        it 'redacts the inaccessible commit' do
          expect(result).to contain_exactly(readable)
        end
      end

      context 'users' do
        let(:other_user) { create(:user) }
        let(:unredacted_results) { ar_relation(User, user, other_user) }
        let(:scope) { 'users' }

        it 'passes the users through' do
          # Users are always visible to everyone
          expect(result).to contain_exactly(user, other_user)
        end
      end
    end
  end

  describe '#valid_request?' do
    let(:scope) { 'issues' }
    let(:search) { 'foobar' }
    let(:params) { instance_double(Gitlab::Search::Params) }

    before do
      allow(Gitlab::Search::Params).to receive(:new).and_return(params)
      allow(params).to receive(:valid?).and_return double(:valid?)
    end

    it 'is the return value of params.valid?' do
      expect(subject.valid_request?).to eq(params.valid?)
    end
  end

  describe '#abuse_messages' do
    let(:scope) { 'issues' }
    let(:search) { 'foobar' }
    let(:params) { instance_double(Gitlab::Search::Params) }

    before do
      allow(Gitlab::Search::Params).to receive(:new).and_return(params)
    end

    it 'returns an empty array when not abusive' do
      allow(params).to receive(:abusive?).and_return false
      expect(subject.abuse_messages).to match_array([])
    end

    it 'calls on abuse_detection.errors.full_messages when abusive' do
      allow(params).to receive(:abusive?).and_return true
      expect(params).to receive_message_chain(:abuse_detection, :errors, :full_messages)
      subject.abuse_messages
    end
  end

  describe 'abusive search handling' do
    subject { described_class.new(user, raw_params) }

    let(:raw_params) { { search: search, scope: scope } }
    let(:search) { 'foobar' }

    let(:search_service) { double(:search_service) }

    before do
      expect(Gitlab::Search::Params).to receive(:new)
        .with(raw_params, detect_abuse: true).and_call_original

      allow(subject).to receive(:search_service).and_return search_service
    end

    context 'a search is abusive' do
      let(:scope) { '1;drop%20table' }

      it 'does NOT execute search service' do
        expect(search_service).not_to receive(:execute)
        subject.search_results
      end
    end

    context 'a search is NOT abusive' do
      let(:scope) { 'issues' }

      it 'executes search service' do
        expect(search_service).to receive(:execute)
        subject.search_results
      end
    end
  end
end

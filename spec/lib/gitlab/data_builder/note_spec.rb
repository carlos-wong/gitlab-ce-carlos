# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DataBuilder::Note do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:data) { described_class.build(note, user) }
  let(:fixed_time) { Time.at(1425600000) } # Avoid time precision errors

  shared_examples 'includes general data' do
    specify do
      expect(data).to have_key(:object_attributes)
      expect(data[:object_attributes]).to have_key(:url)
      expect(data[:object_attributes][:url])
        .to eq(Gitlab::UrlBuilder.build(note))
      expect(data[:object_kind]).to eq('note')
      expect(data[:user]).to eq(user.hook_attrs)
    end
  end

  describe 'When asking for a note on commit' do
    let(:note) { create(:note_on_commit, project: project) }

    it_behaves_like 'includes general data'

    it 'returns the note and commit-specific data' do
      expect(data).to have_key(:commit)
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end

  describe 'When asking for a note on commit diff' do
    let(:note) { create(:diff_note_on_commit, project: project) }

    it_behaves_like 'includes general data'

    it 'returns the note and commit-specific data' do
      expect(data).to have_key(:commit)
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end

  describe 'When asking for a note on issue' do
    let(:label) { create(:label, project: project) }

    let(:issue) do
      create(:labeled_issue, created_at: fixed_time, updated_at: fixed_time,
             project: project, labels: [label])
    end

    let(:note) do
      create(:note_on_issue, noteable: issue, project: project)
    end

    it_behaves_like 'includes general data'

    it 'returns the note and issue-specific data' do
      expect_next_instance_of(Gitlab::HookData::IssueBuilder) do |issue_data_builder|
        expect(issue_data_builder).to receive(:build).and_return('Issue data')
      end

      expect(data[:issue]).to eq('Issue data')
    end

    context 'with confidential issue' do
      let(:issue) { create(:issue, project: project, confidential: true) }

      it_behaves_like 'includes general data'

      it 'sets event_type to confidential_note' do
        expect(data[:event_type]).to eq('confidential_note')
      end
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end

  describe 'When asking for a note on merge request' do
    let(:label) { create(:label, project: project) }
    let(:merge_request) do
      create(:labeled_merge_request, created_at: fixed_time,
                             updated_at: fixed_time,
                             source_project: project,
                             labels: [label])
    end

    let(:note) do
      create(:note_on_merge_request, noteable: merge_request,
                                     project: project)
    end

    it_behaves_like 'includes general data'

    it 'returns the merge request data' do
      expect_next_instance_of(Gitlab::HookData::MergeRequestBuilder) do |mr_data_builder|
        expect(mr_data_builder).to receive(:build).and_return('MR data')
      end

      expect(data[:merge_request]).to eq('MR data')
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end

  describe 'When asking for a note on merge request diff' do
    let(:label) { create(:label, project: project) }
    let(:merge_request) do
      create(:labeled_merge_request, created_at: fixed_time, updated_at: fixed_time,
                             source_project: project,
                             labels: [label])
    end

    let(:note) do
      create(:diff_note_on_merge_request, noteable: merge_request,
                                          project: project)
    end

    it_behaves_like 'includes general data'

    it 'returns the merge request data' do
      expect_next_instance_of(Gitlab::HookData::MergeRequestBuilder) do |mr_data_builder|
        expect(mr_data_builder).to receive(:build).and_return('MR data')
      end

      expect(data[:merge_request]).to eq('MR data')
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end

  describe 'When asking for a note on project snippet' do
    let!(:snippet) do
      create(:project_snippet, created_at: fixed_time, updated_at: fixed_time,
                               project: project)
    end

    let!(:note) do
      create(:note_on_project_snippet, noteable: snippet,
                                       project: project)
    end

    it_behaves_like 'includes general data'

    it 'returns the note and project snippet data' do
      expect(data).to have_key(:snippet)
      expect(data[:snippet].except('updated_at'))
        .to eq(snippet.hook_attrs.except('updated_at'))
      expect(data[:snippet]['updated_at'])
        .to be >= snippet.hook_attrs['updated_at']
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end
end

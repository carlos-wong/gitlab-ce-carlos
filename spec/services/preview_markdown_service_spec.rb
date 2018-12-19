require 'spec_helper'

describe PreviewMarkdownService do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    project.add_developer(user)
  end

  describe 'user references' do
    let(:params) { { text: "Take a look #{user.to_reference}" } }
    let(:service) { described_class.new(project, user, params) }

    it 'returns users referenced in text' do
      result = service.execute

      expect(result[:users]).to eq [user.username]
    end
  end

  describe 'suggestions' do
    let(:params) { { text: "```suggestion\nfoo\n```", preview_suggestions: preview_suggestions } }
    let(:service) { described_class.new(project, user, params) }

    context 'when preview markdown param is present' do
      let(:preview_suggestions) { true }

      it 'returns users referenced in text' do
        result = service.execute

        expect(result[:suggestions]).to eq(['foo'])
      end
    end

    context 'when preview markdown param is not present' do
      let(:preview_suggestions) { false }

      it 'returns users referenced in text' do
        result = service.execute

        expect(result[:suggestions]).to eq([])
      end
    end
  end

  context 'new note with quick actions' do
    let(:issue) { create(:issue, project: project) }
    let(:params) do
      {
        text: "Please do it\n/assign #{user.to_reference}",
        quick_actions_target_type: 'Issue',
        quick_actions_target_id: issue.id
      }
    end
    let(:service) { described_class.new(project, user, params) }

    it 'removes quick actions from text' do
      result = service.execute

      expect(result[:text]).to eq 'Please do it'
    end

    it 'explains quick actions effect' do
      result = service.execute

      expect(result[:commands]).to eq "Assigns #{user.to_reference}."
    end
  end

  context 'merge request description' do
    let(:params) do
      {
        text: "My work\n/estimate 2y",
        quick_actions_target_type: 'MergeRequest'
      }
    end
    let(:service) { described_class.new(project, user, params) }

    it 'removes quick actions from text' do
      result = service.execute

      expect(result[:text]).to eq 'My work'
    end

    it 'explains quick actions effect' do
      result = service.execute

      expect(result[:commands]).to eq 'Sets time estimate to 2y.'
    end
  end

  context 'commit description' do
    let(:project) { create(:project, :repository) }
    let(:commit) { project.commit }
    let(:params) do
      {
        text: "My work\n/tag v1.2.3 Stable release",
        quick_actions_target_type: 'Commit',
        quick_actions_target_id: commit.id
      }
    end
    let(:service) { described_class.new(project, user, params) }

    it 'removes quick actions from text' do
      result = service.execute

      expect(result[:text]).to eq 'My work'
    end

    it 'explains quick actions effect' do
      result = service.execute

      expect(result[:commands]).to eq 'Tags this commit to v1.2.3 with "Stable release".'
    end
  end

  it 'sets correct markdown engine' do
    service = described_class.new(project, user, { markdown_version: CacheMarkdownField::CACHE_REDCARPET_VERSION })
    result  = service.execute

    expect(result[:markdown_engine]).to eq :redcarpet

    service = described_class.new(project, user, { markdown_version: CacheMarkdownField::CACHE_COMMONMARK_VERSION })
    result  = service.execute

    expect(result[:markdown_engine]).to eq :common_mark
  end

  it 'honors the legacy_render parameter' do
    service = described_class.new(project, user, { legacy_render: '1' })
    result  = service.execute

    expect(result[:markdown_engine]).to eq :redcarpet
  end
end

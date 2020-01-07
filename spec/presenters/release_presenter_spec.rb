# frozen_string_literal: true

require 'spec_helper'

describe ReleasePresenter do
  include Gitlab::Routing.url_helpers

  let_it_be(:project) { create(:project, :repository) }
  let(:developer) { create(:user) }
  let(:guest) { create(:user) }
  let(:user) { developer }
  let(:release) { create(:release, project: project) }
  let(:presenter) { described_class.new(release, current_user: user) }

  before do
    project.add_developer(developer)
    project.add_guest(guest)
  end

  describe '#commit_path' do
    subject { presenter.commit_path }

    it 'returns commit path' do
      is_expected.to eq(project_commit_path(project, release.commit.id))
    end

    context 'when commit is not found' do
      let(:release) { create(:release, project: project, sha: 'not-found') }

      it { is_expected.to be_nil }
    end

    context 'when user is guest' do
      let(:user) { guest }

      it { is_expected.to be_nil }
    end
  end

  describe '#tag_path' do
    subject { presenter.tag_path }

    it 'returns tag path' do
      is_expected.to eq(project_tag_path(project, release.tag))
    end

    context 'when user is guest' do
      let(:user) { guest }

      it { is_expected.to be_nil }
    end
  end

  describe '#merge_requests_url' do
    subject { presenter.merge_requests_url }

    it 'returns merge requests url' do
      is_expected.to match /#{project_merge_requests_url(project)}/
    end

    context 'when release_mr_issue_urls feature flag is disabled' do
      before do
        stub_feature_flags(release_mr_issue_urls: false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#issues_url' do
    subject { presenter.issues_url }

    it 'returns merge requests url' do
      is_expected.to match /#{project_issues_url(project)}/
    end

    context 'when release_mr_issue_urls feature flag is disabled' do
      before do
        stub_feature_flags(release_mr_issue_urls: false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#edit_url' do
    subject { presenter.edit_url }

    it 'returns release edit url' do
      is_expected.to match /#{edit_project_release_url(project, release)}/
    end

    context 'when release_edit_page feature flag is disabled' do
      before do
        stub_feature_flags(release_edit_page: false)
      end

      it { is_expected.to be_nil }
    end
  end
end

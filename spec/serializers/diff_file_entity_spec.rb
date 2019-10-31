# frozen_string_literal: true

require 'spec_helper'

describe DiffFileEntity do
  include RepoHelpers

  let(:project) { create(:project, :repository) }
  let(:repository) { project.repository }
  let(:commit) { project.commit(sample_commit.id) }
  let(:diff_refs) { commit.diff_refs }
  let(:diff) { commit.raw_diffs.first }
  let(:diff_file) { Gitlab::Diff::File.new(diff, diff_refs: diff_refs, repository: repository) }
  let(:entity) { described_class.new(diff_file, request: {}) }

  subject { entity.as_json }

  context 'when there is no merge request' do
    it_behaves_like 'diff file entity'
  end

  context 'when there is a merge request' do
    let(:user) { create(:user) }
    let(:request) { EntityRequest.new(project: project, current_user: user) }
    let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let(:entity) { described_class.new(diff_file, request: request, merge_request: merge_request) }
    let(:exposed_urls) { %i(edit_path view_path context_lines_path) }

    it_behaves_like 'diff file entity'

    it 'exposes additional attributes' do
      expect(subject).to include(*exposed_urls)
      expect(subject).to include(:replaced_view_path)
    end

    it 'points all urls to merge request target project' do
      response = subject

      exposed_urls.each do |attribute|
        expect(response[attribute]).to include(merge_request.target_project.to_param)
      end
    end

    it 'exposes load_collapsed_diff_url if the file viewer is collapsed' do
      allow(diff_file.viewer).to receive(:collapsed?) { true }

      expect(subject).to include(:load_collapsed_diff_url)
    end
  end

  context '#parallel_diff_lines' do
    it 'exposes parallel diff lines correctly' do
      response = subject

      lines = response[:parallel_diff_lines]

      # make sure at least one line is present for each side
      expect(lines.map { |line| line[:right] }.compact).to be_present
      expect(lines.map { |line| line[:left] }.compact).to be_present
      # make sure all lines are in correct format
      lines.each do |parallel_line|
        expect(parallel_line[:left].as_json).to match_schema('entities/diff_line') if parallel_line[:left]
        expect(parallel_line[:right].as_json).to match_schema('entities/diff_line') if parallel_line[:right]
      end
    end
  end
end

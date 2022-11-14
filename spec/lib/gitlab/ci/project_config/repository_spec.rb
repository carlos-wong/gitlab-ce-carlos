# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::ProjectConfig::Repository do
  let(:project) { create(:project, :custom_repo, files: files) }
  let(:sha) { project.repository.head_commit.sha }
  let(:files) { { 'README.md' => 'hello' } }

  subject(:config) { described_class.new(project, sha, nil, nil, nil) }

  describe '#content' do
    subject(:content) { config.content }

    context 'when file is in repository' do
      let(:config_content_result) do
        <<~CICONFIG
        ---
        include:
        - local: ".gitlab-ci.yml"
        CICONFIG
      end

      let(:files) { { '.gitlab-ci.yml' => 'content' } }

      it { is_expected.to eq(config_content_result) }
    end

    context 'when file is not in repository' do
      it { is_expected.to be_nil }
    end

    context 'when Gitaly raises error' do
      before do
        allow(project.repository).to receive(:gitlab_ci_yml_for).and_raise(GRPC::Internal)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#source' do
    subject { config.source }

    it { is_expected.to eq(:repository_source) }
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Git::Blame do
  let(:project) { create(:project, :repository) }
  let(:repository) { project.repository.raw }
  let(:sha) { TestEnv::BRANCH_SHA['master'] }
  let(:path) { 'CONTRIBUTING.md' }
  let(:range) { nil }

  subject(:blame) { Gitlab::Git::Blame.new(repository, sha, path, range: range) }

  let(:result) do
    [].tap do |data|
      blame.each do |commit, line, previous_path|
        data << { commit: commit, line: line, previous_path: previous_path }
      end
    end
  end

  describe 'blaming a file' do
    it 'has the right number of lines' do
      expect(result.size).to eq(95)
      expect(result.first[:commit]).to be_kind_of(Gitlab::Git::Commit)
      expect(result.first[:line]).to eq("# Contribute to GitLab")
      expect(result.first[:line]).to be_utf8
    end

    context 'blaming a range' do
      let(:range) { 2..4 }

      it 'only returns the range' do
        expect(result.size).to eq(range.size)
        expect(result.map {|r| r[:line] }).to eq(['', 'This guide details how contribute to GitLab.', ''])
      end
    end

    context "ISO-8859 encoding" do
      let(:path) { 'encoding/iso8859.txt' }

      it 'converts to UTF-8' do
        expect(result.size).to eq(1)
        expect(result.first[:commit]).to be_kind_of(Gitlab::Git::Commit)
        expect(result.first[:line]).to eq("Äü")
        expect(result.first[:line]).to be_utf8
      end
    end

    context "unknown encoding" do
      let(:path) { 'encoding/iso8859.txt' }

      it 'converts to UTF-8' do
        expect_next_instance_of(CharlockHolmes::EncodingDetector) do |detector|
          expect(detector).to receive(:detect).and_return(nil)
        end

        expect(result.size).to eq(1)
        expect(result.first[:commit]).to be_kind_of(Gitlab::Git::Commit)
        expect(result.first[:line]).to eq("")
        expect(result.first[:line]).to be_utf8
      end
    end

    context "renamed file" do
      let(:commit) { project.commit('blame-on-renamed') }
      let(:sha) { commit.id }
      let(:path) { 'files/plain_text/renamed' }

      it 'includes the previous path' do
        expect(result.size).to eq(5)

        expect(result[0]).to include(line: 'Initial commit', previous_path: nil)
        expect(result[1]).to include(line: 'Initial commit', previous_path: nil)
        expect(result[2]).to include(line: 'Renamed as "filename"', previous_path: 'files/plain_text/initial-commit')
        expect(result[3]).to include(line: 'Renamed as renamed', previous_path: 'files/plain_text/"filename"')
        expect(result[4]).to include(line: 'Last edit, no rename', previous_path: path)
      end
    end
  end
end

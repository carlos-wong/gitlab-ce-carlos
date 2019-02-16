# frozen_string_literal: true

require 'spec_helper'

describe BlobPresenter, :seed_helper do
  let(:repository) { Gitlab::Git::Repository.new('default', TEST_REPO_PATH, '', 'group/project') }

  let(:git_blob) do
    Gitlab::Git::Blob.find(
      repository,
      'fa1b1e6c004a68b7d8763b86455da9e6b23e36d6',
      'files/ruby/regex.rb'
    )
  end
  let(:blob) { Blob.new(git_blob) }

  describe '#highlight' do
    subject { described_class.new(blob) }

    it 'returns highlighted content' do
      expect(Gitlab::Highlight).to receive(:highlight).with('files/ruby/regex.rb', git_blob.data, plain: nil, language: nil)

      subject.highlight
    end

    it 'returns plain content when :plain is true' do
      expect(Gitlab::Highlight).to receive(:highlight).with('files/ruby/regex.rb', git_blob.data, plain: true, language: nil)

      subject.highlight(plain: true)
    end

    context 'gitlab-language contains a match' do
      before do
        allow(blob).to receive(:language_from_gitattributes).and_return('ruby')
      end

      it 'passes language to inner call' do
        expect(Gitlab::Highlight).to receive(:highlight).with('files/ruby/regex.rb', git_blob.data, plain: nil, language: 'ruby')

        subject.highlight
      end
    end
  end
end

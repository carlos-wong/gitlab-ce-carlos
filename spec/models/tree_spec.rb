# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Tree do
  let_it_be(:repository) { create(:project, :repository).repository }

  let(:sha) { repository.root_ref }

  subject(:tree) { described_class.new(repository, '54fcc214') }

  describe '#readme' do
    before do
      stub_const('FakeBlob', Class.new)
      FakeBlob.class_eval do
        attr_reader :name

        def initialize(name)
          @name = name
        end

        def readme?
          name =~ /^readme/i
        end
      end
    end

    it 'returns nil when repository does not contains a README file' do
      files = [FakeBlob.new('file'), FakeBlob.new('license'), FakeBlob.new('copying')]
      expect(subject).to receive(:blobs).and_return(files)

      expect(subject.readme).to eq nil
    end

    it 'returns nil when repository does not contains a previewable README file' do
      files = [FakeBlob.new('file'), FakeBlob.new('README.pages'), FakeBlob.new('README.png')]
      expect(subject).to receive(:blobs).and_return(files)

      expect(subject.readme).to eq nil
    end

    it 'returns README when repository contains a previewable README file' do
      files = [FakeBlob.new('README.png'), FakeBlob.new('README'), FakeBlob.new('file')]
      expect(subject).to receive(:blobs).and_return(files)

      expect(subject.readme.name).to eq 'README'
    end

    it 'returns first previewable README when repository contains more than one' do
      files = [FakeBlob.new('file'), FakeBlob.new('README.md'), FakeBlob.new('README.asciidoc')]
      expect(subject).to receive(:blobs).and_return(files)

      expect(subject.readme.name).to eq 'README.md'
    end

    it 'returns first plain text README when repository contains more than one' do
      files = [FakeBlob.new('file'), FakeBlob.new('README'), FakeBlob.new('README.txt')]
      expect(subject).to receive(:blobs).and_return(files)

      expect(subject.readme.name).to eq 'README'
    end

    it 'prioritizes previewable README file over one in plain text' do
      files = [FakeBlob.new('file'), FakeBlob.new('README'), FakeBlob.new('README.md')]
      expect(subject).to receive(:blobs).and_return(files)

      expect(subject.readme.name).to eq 'README.md'
    end
  end

  describe '#cursor' do
    subject { tree.cursor }

    it { is_expected.to be_an_instance_of(Gitaly::PaginationCursor) }
  end
end

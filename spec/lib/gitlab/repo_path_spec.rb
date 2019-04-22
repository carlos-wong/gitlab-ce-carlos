require 'spec_helper'

describe ::Gitlab::RepoPath do
  describe '.parse' do
    set(:project) { create(:project, :repository) }

    context 'a repository storage path' do
      it 'parses a full repository path' do
        expect(described_class.parse(project.repository.full_path)).to eq([project, Gitlab::GlRepository::PROJECT, nil])
      end

      it 'parses a full wiki path' do
        expect(described_class.parse(project.wiki.repository.full_path)).to eq([project, Gitlab::GlRepository::WIKI, nil])
      end
    end

    context 'a relative path' do
      it 'parses a relative repository path' do
        expect(described_class.parse(project.full_path + '.git')).to eq([project, Gitlab::GlRepository::PROJECT, nil])
      end

      it 'parses a relative wiki path' do
        expect(described_class.parse(project.full_path + '.wiki.git')).to eq([project, Gitlab::GlRepository::WIKI, nil])
      end

      it 'parses a relative path starting with /' do
        expect(described_class.parse('/' + project.full_path + '.git')).to eq([project, Gitlab::GlRepository::PROJECT, nil])
      end

      context 'of a redirected project' do
        let(:redirect) { project.route.create_redirect('foo/bar') }

        it 'parses a relative repository path' do
          expect(described_class.parse(redirect.path + '.git')).to eq([project, Gitlab::GlRepository::PROJECT, 'foo/bar'])
        end

        it 'parses a relative wiki path' do
          expect(described_class.parse(redirect.path + '.wiki.git')).to eq([project, Gitlab::GlRepository::WIKI, 'foo/bar.wiki'])
        end

        it 'parses a relative path starting with /' do
          expect(described_class.parse('/' + redirect.path + '.git')).to eq([project, Gitlab::GlRepository::PROJECT, 'foo/bar'])
        end
      end
    end

    it "returns the default type for non existent paths" do
      _project, type, _redirected = described_class.parse("path/non-existent.git")

      expect(type).to eq(Gitlab::GlRepository.default_type)
    end
  end

  describe '.find_project' do
    let(:project) { create(:project) }
    let(:redirect) { project.route.create_redirect('foo/bar/baz') }

    context 'when finding a project by its canonical path' do
      context 'when the cases match' do
        it 'returns the project and false' do
          expect(described_class.find_project(project.full_path)).to eq([project, false])
        end
      end

      context 'when the cases do not match' do
        # This is slightly different than web behavior because on the web it is
        # easy and safe to redirect someone to the correctly-cased URL. For git
        # requests, we should accept wrongly-cased URLs because it is a pain to
        # block people's git operations and force them to update remote URLs.
        it 'returns the project and false' do
          expect(described_class.find_project(project.full_path.upcase)).to eq([project, false])
        end
      end
    end

    context 'when finding a project via a redirect' do
      it 'returns the project and true' do
        expect(described_class.find_project(redirect.path)).to eq([project, true])
      end
    end
  end
end

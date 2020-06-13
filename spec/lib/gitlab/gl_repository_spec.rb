# frozen_string_literal: true

require 'spec_helper'

describe ::Gitlab::GlRepository do
  describe '.parse' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:snippet) { create(:personal_snippet) }

    it 'parses a project gl_repository' do
      expect(described_class.parse("project-#{project.id}")).to eq([project, project, Gitlab::GlRepository::PROJECT])
    end

    it 'parses a wiki gl_repository' do
      expect(described_class.parse("wiki-#{project.id}")).to eq([project, project, Gitlab::GlRepository::WIKI])
    end

    it 'parses a snippet gl_repository' do
      expect(described_class.parse("snippet-#{snippet.id}")).to eq([snippet, nil, Gitlab::GlRepository::SNIPPET])
    end

    it 'throws an argument error on an invalid gl_repository type' do
      expect { described_class.parse("badformat-#{project.id}") }.to raise_error(ArgumentError)
    end

    it 'throws an argument error on an invalid gl_repository id' do
      expect { described_class.parse("project-foo") }.to raise_error(ArgumentError)
    end
  end
end

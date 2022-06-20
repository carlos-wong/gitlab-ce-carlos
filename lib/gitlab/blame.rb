# frozen_string_literal: true

module Gitlab
  class Blame
    attr_accessor :blob, :commit, :range

    def initialize(blob, commit, range: nil)
      @blob = blob
      @commit = commit
      @range = range
    end

    def first_line
      range&.first || 1
    end

    def groups(highlight: true)
      prev_sha = nil
      groups = []
      current_group = nil

      i = first_line - 1
      blame.each do |commit, line, previous_path|
        commit = Commit.new(commit, project)
        commit.lazy_author # preload author

        if prev_sha != commit.sha
          groups << current_group if current_group
          current_group = { commit: commit, lines: [], previous_path: previous_path }
        end

        current_group[:lines] << (highlight ? highlighted_lines[i].html_safe : line)

        prev_sha = commit.sha
        i += 1
      end
      groups << current_group if current_group

      groups
    end

    private

    def blame
      @blame ||= Gitlab::Git::Blame.new(repository, @commit.id, @blob.path, range: range)
    end

    def highlighted_lines
      @blob.load_all_data!
      @highlighted_lines ||= @blob.present.highlight.lines
    end

    def project
      commit.project
    end

    def repository
      project.repository
    end
  end
end

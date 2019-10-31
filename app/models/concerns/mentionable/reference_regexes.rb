# frozen_string_literal: true

module Mentionable
  module ReferenceRegexes
    extend Gitlab::Utils::StrongMemoize

    def self.reference_pattern(link_patterns, issue_pattern)
      Regexp.union(link_patterns,
                   issue_pattern,
                   *other_patterns)
    end

    def self.other_patterns
      [
        Commit.reference_pattern,
        MergeRequest.reference_pattern,
        Label.reference_pattern,
        Milestone.reference_pattern
      ]
    end

    def self.default_pattern
      strong_memoize(:default_pattern) do
        issue_pattern = Issue.reference_pattern
        link_patterns = Regexp.union([Issue, Commit, MergeRequest, Epic].map(&:link_reference_pattern).compact)
        reference_pattern(link_patterns, issue_pattern)
      end
    end

    def self.external_pattern
      strong_memoize(:external_pattern) do
        issue_pattern = IssueTrackerService.reference_pattern
        link_patterns = URI.regexp(%w(http https))
        reference_pattern(link_patterns, issue_pattern)
      end
    end
  end
end

Mentionable::ReferenceRegexes.prepend_if_ee('EE::Mentionable::ReferenceRegexes')

# frozen_string_literal: true
require 'net/http'
require 'json'

require_relative 'teammate'

module Gitlab
  module Danger
    module Helper
      RELEASE_TOOLS_BOT = 'gitlab-release-tools-bot'
      ROULETTE_DATA_URL = URI.parse('https://about.gitlab.com/roulette.json').freeze

      # Returns a list of all files that have been added, modified or renamed.
      # `git.modified_files` might contain paths that already have been renamed,
      # so we need to remove them from the list.
      #
      # Considering these changes:
      #
      # - A new_file.rb
      # - D deleted_file.rb
      # - M modified_file.rb
      # - R renamed_file_before.rb -> renamed_file_after.rb
      #
      # it will return
      # ```
      # [ 'new_file.rb', 'modified_file.rb', 'renamed_file_after.rb' ]
      # ```
      #
      # @return [Array<String>]
      def all_changed_files
        Set.new
          .merge(git.added_files.to_a)
          .merge(git.modified_files.to_a)
          .merge(git.renamed_files.map { |x| x[:after] })
          .subtract(git.renamed_files.map { |x| x[:before] })
          .to_a
          .sort
      end

      def ee?
        ENV['CI_PROJECT_NAME'] == 'gitlab-ee' || File.exist?('../../CHANGELOG-EE.md')
      end

      def release_automation?
        gitlab.mr_author == RELEASE_TOOLS_BOT
      end

      def project_name
        ee? ? 'gitlab-ee' : 'gitlab-ce'
      end

      # Looks up the current list of GitLab team members and parses it into a
      # useful form
      #
      # @return [Array<Teammate>]
      def team
        @team ||=
          begin
            rsp = Net::HTTP.get_response(ROULETTE_DATA_URL)
            raise "Failed to read #{ROULETTE_DATA_URL}: #{rsp.code} #{rsp.message}" unless
              rsp.is_a?(Net::HTTPSuccess)

            data = JSON.parse(rsp.body)
            data.map { |hash| ::Gitlab::Danger::Teammate.new(hash) }
          rescue JSON::ParserError
            raise "Failed to parse JSON response from #{ROULETTE_DATA_URL}"
          end
      end

      # Like +team+, but only returns teammates in the current project, based on
      # project_name.
      #
      # @return [Array<Teammate>]
      def project_team
        team.select { |member| member.in_project?(project_name) }
      end

      # @return [Hash<String,Array<String>>]
      def changes_by_category
        all_changed_files.each_with_object(Hash.new { |h, k| h[k] = [] }) do |file, hash|
          hash[category_for_file(file)] << file
        end
      end

      # Determines the category a file is in, e.g., `:frontend` or `:backend`
      # @return[Symbol]
      def category_for_file(file)
        _, category = CATEGORIES.find { |regexp, _| regexp.match?(file) }

        category || :unknown
      end

      # Returns the GFM for a category label, making its best guess if it's not
      # a category we know about.
      #
      # @return[String]
      def label_for_category(category)
        CATEGORY_LABELS.fetch(category, "~#{category}")
      end

      CATEGORY_LABELS = {
        docs: "~Documentation",
        none: "",
        qa: "~QA"
      }.freeze

      # rubocop:disable Style/RegexpLiteral
      CATEGORIES = {
        %r{\Adoc/} => :docs,
        %r{\A(CONTRIBUTING|LICENSE|MAINTENANCE|PHILOSOPHY|PROCESS|README)(\.md)?\z} => :docs,

        %r{\A(ee/)?app/(assets|views)/} => :frontend,
        %r{\A(ee/)?public/} => :frontend,
        %r{\A(ee/)?spec/(javascripts|frontend)/} => :frontend,
        %r{\A(ee/)?vendor/assets/} => :frontend,
        %r{\Ascripts/frontend/} => :frontend,
        %r{(\A|/)(
          \.babelrc |
          \.eslintignore |
          \.eslintrc(\.yml)? |
          \.nvmrc |
          \.prettierignore |
          \.prettierrc |
          \.scss-lint.yml |
          \.stylelintrc |
          babel\.config\.js |
          jest\.config\.js |
          karma\.config\.js |
          webpack\.config\.js |
          package\.json |
          yarn\.lock
        )\z}x => :frontend,

        %r{\A(ee/)?app/(?!assets|views)[^/]+} => :backend,
        %r{\A(ee/)?(bin|config|danger|generator_templates|lib|rubocop|scripts)/} => :backend,
        %r{\A(ee/)?spec/(?!javascripts|frontend)[^/]+} => :backend,
        %r{\A(ee/)?vendor/(?!assets)[^/]+} => :backend,
        %r{\A(ee/)?vendor/(languages\.yml|licenses\.csv)\z} => :backend,
        %r{\A(Dangerfile|Gemfile|Gemfile.lock|Procfile|Rakefile|\.gitlab-ci\.yml)\z} => :backend,
        %r{\A[A-Z_]+_VERSION\z} => :backend,

        %r{\A(ee/)?db/} => :database,
        %r{\A(ee/)?qa/} => :qa,

        # Files that don't fit into any category are marked with :none
        %r{\A(ee/)?changelogs/} => :none,
        %r{\Alocale/gitlab\.pot\z} => :none,

        # Fallbacks in case the above patterns miss anything
        %r{\.rb\z} => :backend,
        %r{\.(md|txt)\z} => :docs,
        %r{\.js\z} => :frontend
      }.freeze
      # rubocop:enable Style/RegexpLiteral
    end
  end
end

# frozen_string_literal: true

module Gitlab
  class SnippetSearchResults < SearchResults
    include SnippetsHelper

    attr_reader :limit_snippets

    def initialize(limit_snippets, query)
      @limit_snippets = limit_snippets
      @query = query
    end

    def objects(scope, page = nil)
      case scope
      when 'snippet_titles'
        snippet_titles.page(page).per(per_page)
      when 'snippet_blobs'
        snippet_blobs.page(page).per(per_page)
      else
        super(scope, nil, false)
      end
    end

    def formatted_count(scope)
      case scope
      when 'snippet_titles'
        snippet_titles_count.to_s
      when 'snippet_blobs'
        snippet_blobs_count.to_s
      else
        super
      end
    end

    def snippet_titles_count
      @snippet_titles_count ||= snippet_titles.count
    end

    def snippet_blobs_count
      @snippet_blobs_count ||= snippet_blobs.count
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def snippet_titles
      limit_snippets.search(query).order('updated_at DESC').includes(:author)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def snippet_blobs
      limit_snippets.search_code(query).order('updated_at DESC').includes(:author)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def default_scope
      'snippet_blobs'
    end
  end
end

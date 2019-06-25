# frozen_string_literal: true
require 'spec_helper'

describe Gitlab::MarkdownCache::Redis::Extension, :clean_gitlab_redis_cache do
  let(:klass) do
    Class.new do
      include CacheMarkdownField

      def initialize(title: nil, description: nil)
        @title, @description = title, description
      end

      attr_reader :title, :description

      cache_markdown_field :title, pipeline: :single_line
      cache_markdown_field :description

      def cache_key
        "cache-key"
      end
    end
  end

  let(:cache_version) { Gitlab::MarkdownCache::CACHE_COMMONMARK_VERSION << 16 }
  let(:thing) { klass.new(title: "`Hello`", description: "`World`") }
  let(:expected_cache_key) { "markdown_cache:cache-key" }

  it 'defines the html attributes' do
    expect(thing).to respond_to(:title_html, :description_html, :cached_markdown_version)
  end

  it 'loads the markdown from the cache only once' do
    expect(thing).to receive(:load_cached_markdown).once.and_call_original

    thing.title_html
    thing.description_html
  end

  it 'correctly loads the markdown if it was stored in redis' do
    Gitlab::Redis::Cache.with do |r|
      r.mapped_hmset(expected_cache_key,
                     title_html: 'hello',
                     description_html: 'world',
                     cached_markdown_version: cache_version)
    end

    expect(thing.title_html).to eq('hello')
    expect(thing.description_html).to eq('world')
    expect(thing.cached_markdown_version).to eq(cache_version)
  end

  describe "#refresh_markdown_cache!" do
    it "stores the value in redis" do
      expected_results = { "title_html" => "`Hello`",
                           "description_html" => "<p data-sourcepos=\"1:1-1:7\" dir=\"auto\"><code>World</code></p>",
                           "cached_markdown_version" => cache_version.to_s }

      thing.refresh_markdown_cache!

      results = Gitlab::Redis::Cache.with do |r|
        r.mapped_hmget(expected_cache_key,
                       "title_html", "description_html", "cached_markdown_version")
      end

      expect(results).to eq(expected_results)
    end

    it "assigns the values" do
      thing.refresh_markdown_cache!

      expect(thing.title_html).to eq('`Hello`')
      expect(thing.description_html).to eq("<p data-sourcepos=\"1:1-1:7\" dir=\"auto\"><code>World</code></p>")
      expect(thing.cached_markdown_version).to eq(cache_version)
    end
  end
end

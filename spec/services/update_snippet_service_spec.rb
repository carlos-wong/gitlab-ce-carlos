# frozen_string_literal: true

require 'spec_helper'

describe UpdateSnippetService do
  before do
    @user = create :user
    @admin = create :user, admin: true
    @opts = {
      title: 'Test snippet',
      file_name: 'snippet.rb',
      content: 'puts "hello world"',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE
    }
  end

  context 'When public visibility is restricted' do
    before do
      stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])

      @snippet = create_snippet(@project, @user, @opts)
      @opts.merge!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
    end

    it 'non-admins should not be able to update to public visibility' do
      old_visibility = @snippet.visibility_level
      update_snippet(@project, @user, @snippet, @opts)
      expect(@snippet.errors.messages).to have_key(:visibility_level)
      expect(@snippet.errors.messages[:visibility_level].first).to(
        match('has been restricted')
      )
      expect(@snippet.visibility_level).to eq(old_visibility)
    end

    it 'admins should be able to update to public visibility' do
      old_visibility = @snippet.visibility_level
      update_snippet(@project, @admin, @snippet, @opts)
      expect(@snippet.visibility_level).not_to eq(old_visibility)
      expect(@snippet.visibility_level).to eq(Gitlab::VisibilityLevel::PUBLIC)
    end

    describe "when visibility level is passed as a string" do
      before do
        @opts[:visibility] = 'internal'
        @opts.delete(:visibility_level)
      end

      it "assigns the correct visibility level" do
        update_snippet(@project, @user, @snippet, @opts)
        expect(@snippet.errors.any?).to be_falsey
        expect(@snippet.visibility_level).to eq(Gitlab::VisibilityLevel::INTERNAL)
      end
    end
  end

  describe 'usage counter' do
    let(:counter) { Gitlab::UsageDataCounters::SnippetCounter }
    let(:snippet) { create_snippet(nil, @user, @opts) }

    it 'increments count' do
      expect do
        update_snippet(nil, @admin, snippet, @opts)
      end.to change { counter.read(:update) }.by 1
    end

    it 'does not increment count if create fails' do
      expect do
        update_snippet(nil, @admin, snippet, { title: '' })
      end.not_to change { counter.read(:update) }
    end
  end

  def create_snippet(project, user, opts)
    CreateSnippetService.new(project, user, opts).execute
  end

  def update_snippet(project, user, snippet, opts)
    UpdateSnippetService.new(project, user, snippet, opts).execute
  end
end

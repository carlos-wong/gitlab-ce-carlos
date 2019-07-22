# frozen_string_literal: true

require 'spec_helper'

describe AwardEmojiPresenter do
  let(:emoji_name) { 'thumbsup' }
  let(:award_emoji) { build(:award_emoji, name: emoji_name) }
  let(:presenter) { described_class.new(award_emoji) }

  describe '#description' do
    it { expect(presenter.description).to eq Gitlab::Emoji.emojis[emoji_name]['description'] }
  end

  describe '#unicode' do
    it { expect(presenter.unicode).to eq Gitlab::Emoji.emojis[emoji_name]['unicode'] }
  end

  describe '#unicode_version' do
    it { expect(presenter.unicode_version).to eq Gitlab::Emoji.emoji_unicode_version(emoji_name) }
  end

  describe '#emoji' do
    it { expect(presenter.emoji).to eq Gitlab::Emoji.emojis[emoji_name]['moji'] }
  end

  describe 'when presenting an award emoji with an invalid name' do
    let(:emoji_name) { 'invalid-name' }

    it 'returns nil for all properties' do
      expect(presenter.description).to be_nil
      expect(presenter.emoji).to be_nil
      expect(presenter.unicode).to be_nil
      expect(presenter.unicode_version).to be_nil
    end
  end
end

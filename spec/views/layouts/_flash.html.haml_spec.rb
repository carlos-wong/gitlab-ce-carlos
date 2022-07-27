# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_flash' do
  before do
    allow(view).to receive(:flash).and_return(flash)
    render
  end

  describe 'closable flash messages' do
    where(:flash_type) do
      %w[alert notice success]
    end

    with_them do
      let(:flash) { { flash_type => 'This is a closable flash message' } }

      it 'shows a close button' do
        expect(rendered).to include('js-close-icon')
      end
    end
  end

  describe 'non closable flash messages' do
    where(:flash_type) do
      %w[error message toast warning]
    end

    with_them do
      let(:flash) { { flash_type => 'This is a non closable flash message' } }

      it 'does not show a close button' do
        expect(rendered).not_to include('js-close-icon')
      end
    end
  end
end

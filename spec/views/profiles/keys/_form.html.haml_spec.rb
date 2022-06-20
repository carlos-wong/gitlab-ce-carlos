# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/keys/_form.html.haml' do
  include SshKeysHelper

  let_it_be(:key) { Key.new }

  let(:page) { Capybara::Node::Simple.new(rendered) }

  before do
    assign(:key, key)
  end

  context 'when the form partial is used' do
    before do
      allow(view).to receive(:ssh_key_expires_field_description).and_return('Key can still be used after expiration.')

      render
    end

    it 'renders the form with the correct action' do
      expect(page.find('form')['action']).to eq('/-/profile/keys')
    end

    it 'has the key field', :aggregate_failures do
      expect(rendered).to have_field('Key', type: 'textarea')
      expect(rendered).to have_text(s_('Profiles|Begins with %{ssh_key_algorithms}.') % { ssh_key_algorithms: ssh_key_allowed_algorithms })
    end

    it 'has the title field', :aggregate_failures do
      expect(rendered).to have_field('Title', type: 'text', placeholder: 'Example: MacBook key')
      expect(rendered).to have_text('Key titles are publicly visible.')
    end

    it 'has the expires at field', :aggregate_failures do
      expect(rendered).to have_field('Expiration date', type: 'date')
      expect(page.find_field('Expiration date')['min']).to eq(l(1.day.from_now, format: "%Y-%m-%d"))
      expect(rendered).to have_text('Key can still be used after expiration.')
    end

    it 'has the validation warning', :aggregate_failures do
      expect(rendered).to have_text("Oops, are you sure? Publicly visible private SSH keys can compromise your system.")
      expect(rendered).to have_button('Yes, add it')
    end

    it 'has the submit button' do
      expect(rendered).to have_button('Add key')
    end
  end
end

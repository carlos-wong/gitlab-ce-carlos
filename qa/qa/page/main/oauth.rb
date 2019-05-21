# frozen_string_literal: true

module QA
  module Page
    module Main
      class OAuth < Page::Base
        view 'app/views/doorkeeper/authorizations/new.html.haml' do
          element :authorization_button, 'submit_tag _("Authorize")' # rubocop:disable QA/ElementWithPattern
        end

        def needs_authorization?
          page.current_url.include?('/oauth')
        end

        def authorize!
          click_button 'Authorize'
        end
      end
    end
  end
end

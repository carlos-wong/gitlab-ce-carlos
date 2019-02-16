# frozen_string_literal: true

module QA
  module Vendor
    module Github
      module Page
        class Base
          include Capybara::DSL
          include Scenario::Actable
        end
      end
    end
  end
end

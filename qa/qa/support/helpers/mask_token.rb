# frozen_string_literal: true

module QA
  module Support
    module Helpers
      module MaskToken
        def use_ci_variable(name:, value:, project:)
          Resource::CiVariable.fabricate_via_api! do |ci_variable|
            ci_variable.project = project
            ci_variable.key = name
            ci_variable.value = value
            ci_variable.protected = true
          end
          "$#{name}"
        end
      end
    end
  end
end

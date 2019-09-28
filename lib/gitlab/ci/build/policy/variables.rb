# frozen_string_literal: true

module Gitlab
  module Ci
    module Build
      module Policy
        class Variables < Policy::Specification
          def initialize(expressions)
            @expressions = Array(expressions)
          end

          def satisfied_by?(pipeline, seed)
            variables = seed.scoped_variables_hash

            statements = @expressions.map do |statement|
              ::Gitlab::Ci::Pipeline::Expression::Statement
                .new(statement, variables)
            end

            statements.any?(&:truthful?)
          end
        end
      end
    end
  end
end

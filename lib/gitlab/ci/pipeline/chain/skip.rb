# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        class Skip < Chain::Base
          include ::Gitlab::Utils::StrongMemoize

          SKIP_PATTERN = /\[(ci[ _-]skip|skip[ _-]ci)\]/i

          def perform!
            if skipped?
              @pipeline.skip if @command.save_incompleted
            end
          end

          def skipped?
            !@command.ignore_skip_ci && (commit_message_skips_ci? || push_option_skips_ci?)
          end

          def break?
            skipped?
          end

          private

          def commit_message_skips_ci?
            return false unless @pipeline.git_commit_message

            strong_memoize(:commit_message_skips_ci) do
              !!(@pipeline.git_commit_message =~ SKIP_PATTERN)
            end
          end

          def push_option_skips_ci?
            @command.push_options.present? &&
              @command.push_options.deep_symbolize_keys.dig(:ci, :skip).present?
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Gitlab
  module Ci
    module Status
      module Stage
        class PlayManual < Status::Extended
          include Gitlab::Routing

          def action_icon
            'play'
          end

          def action_title
            'Play all manual'
          end

          def action_path
            pipeline = subject.pipeline

            project_stage_play_manual_path(pipeline.project, pipeline, subject.name)
          end

          def action_method
            :post
          end

          def action_button_title
            _('Play all manual')
          end

          def self.matches?(stage, user)
            stage.manual_playable?
          end

          def has_action?
            true
          end
        end
      end
    end
  end
end

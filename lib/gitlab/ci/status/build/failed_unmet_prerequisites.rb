# frozen_string_literal: true

module Gitlab
  module Ci
    module Status
      module Build
        class FailedUnmetPrerequisites < Status::Extended
          def illustration
            {
              image: 'illustrations/pipelines_failed.svg',
              size: 'svg-430',
              title: _('Failed to create resources'),
              content: _('Retry this job in order to create the necessary resources.')
            }
          end

          def self.matches?(build, _)
            build.unmet_prerequisites?
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module ErrorTracking
  class BaseService < ::BaseService
    def execute
      return unauthorized if unauthorized

      perform
    end

    private

    def perform
      raise NotImplementedError,
          "#{self.class} does not implement #{__method__}"
    end

    def compose_response(response, &block)
      errors = parse_errors(response)
      return errors if errors

      yield if block_given?

      success(parse_response(response))
    end

    def parse_response(response)
      raise NotImplementedError,
          "#{self.class} does not implement #{__method__}"
    end

    def unauthorized
      return error('Error Tracking is not enabled') unless enabled?
      return error('Access denied', :unauthorized) unless can_read?
    end

    def parse_errors(response)
      return error('Not ready. Try again later', :no_content) unless response
      return error(response[:error], http_status_for(response[:error_type])) if response[:error].present?
    end

    def http_status_for(error_type)
      case error_type
      when ErrorTracking::ProjectErrorTrackingSetting::SENTRY_API_ERROR_TYPE_MISSING_KEYS
        :internal_server_error
      else
        :bad_request
      end
    end

    def project_error_tracking_setting
      project.error_tracking_setting
    end

    def enabled?
      project_error_tracking_setting&.enabled?
    end

    def can_read?
      can?(current_user, :read_sentry_issue, project)
    end

    def can_update?
      can?(current_user, :update_sentry_issue, project)
    end
  end
end

# frozen_string_literal: true

module IncidentManagement
  module TimelineEvents
    DEFAULT_ACTION = 'comment'
    DEFAULT_EDITABLE = false
    DEFAULT_AUTO_CREATED = false

    class CreateService < TimelineEvents::BaseService
      def initialize(incident, user, params)
        @project = incident.project
        @incident = incident
        @user = user
        @params = params
        @auto_created = !!params.fetch(:auto_created, DEFAULT_AUTO_CREATED)
      end

      class << self
        def create_incident(incident, user)
          note = "@#{user.username} created the incident"
          occurred_at = incident.created_at
          action = 'issues'

          new(incident, user, note: note, occurred_at: occurred_at, action: action, auto_created: true).execute
        end

        def reopen_incident(incident, user)
          note = "@#{user.username} reopened the incident"
          occurred_at = incident.updated_at
          action = 'issues'

          new(incident, user, note: note, occurred_at: occurred_at, action: action, auto_created: true).execute
        end

        def resolve_incident(incident, user)
          note = "@#{user.username} resolved the incident"
          occurred_at = incident.updated_at
          action = 'status'

          new(incident, user, note: note, occurred_at: occurred_at, action: action, auto_created: true).execute
        end

        def change_incident_status(incident, user, escalation_status)
          status = escalation_status.status_name.to_s.titleize
          note = "@#{user.username} changed the incident status to **#{status}**"
          occurred_at = incident.updated_at
          action = 'status'

          new(incident, user, note: note, occurred_at: occurred_at, action: action, auto_created: true).execute
        end
      end

      def execute
        return error_no_permissions unless allowed?

        timeline_event_params = {
          project: project,
          incident: incident,
          author: user,
          note: params[:note],
          action: params.fetch(:action, DEFAULT_ACTION),
          note_html: params[:note_html].presence || params[:note],
          occurred_at: params[:occurred_at],
          promoted_from_note: params[:promoted_from_note],
          editable: params.fetch(:editable, DEFAULT_EDITABLE)
        }

        timeline_event = IncidentManagement::TimelineEvent.new(timeline_event_params)

        if timeline_event.save
          add_system_note(timeline_event)
          track_usage_event(:incident_management_timeline_event_created, user.id)

          success(timeline_event)
        else
          error_in_save(timeline_event)
        end
      end

      private

      attr_reader :project, :user, :incident, :params, :auto_created

      def allowed?
        return true if auto_created

        super
      end

      def add_system_note(timeline_event)
        return if auto_created
        return unless Feature.enabled?(:incident_timeline, project)

        SystemNoteService.add_timeline_event(timeline_event)
      end
    end
  end
end

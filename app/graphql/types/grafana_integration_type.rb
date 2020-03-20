# frozen_string_literal: true

module Types
  class GrafanaIntegrationType < ::Types::BaseObject
    graphql_name 'GrafanaIntegration'

    authorize :admin_operations

    field :id, GraphQL::ID_TYPE, null: false,
      description: 'Internal ID of the Grafana integration'
    field :grafana_url, GraphQL::STRING_TYPE, null: false,
      description: 'Url for the Grafana host for the Grafana integration'
    field :enabled, GraphQL::BOOLEAN_TYPE, null: false,
      description: 'Indicates whether Grafana integration is enabled'
    field :created_at, Types::TimeType, null: false,
          description: 'Timestamp of the issue\'s creation'
    field :updated_at, Types::TimeType, null: false,
          description: 'Timestamp of the issue\'s last activity'

    field :token, GraphQL::STRING_TYPE, null: false,
          deprecation_reason: 'Plain text token has been masked for security reasons',
          description: 'API token for the Grafana integration. Field is permanently masked.'

    def token
      object.masked_token
    end
  end
end

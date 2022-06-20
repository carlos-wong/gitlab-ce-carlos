# frozen_string_literal: true

module Mutations
  module Environments
    module CanaryIngress
      class Update < ::Mutations::BaseMutation
        graphql_name 'EnvironmentsCanaryIngressUpdate'
        description '**Deprecated** This endpoint is planned to be removed along with certificate-based clusters. [See this epic](https://gitlab.com/groups/gitlab-org/configure/-/epics/8) for more information.'

        authorize :update_environment

        argument :id,
                 ::Types::GlobalIDType[::Environment],
                 required: true,
                 description: 'Global ID of the environment to update.'

        argument :weight,
                 GraphQL::Types::Int,
                 required: true,
                 description: 'Weight of the Canary Ingress.'

        REMOVAL_ERR_MSG = 'This endpoint was deactivated as part of the certificate-based' \
          'kubernetes integration removal. See Epic:' \
          'https://gitlab.com/groups/gitlab-org/configure/-/epics/8'

        def resolve(id:, **kwargs)
          return { errors: [REMOVAL_ERR_MSG] } if cert_based_clusters_ff_disabled?

          environment = authorized_find!(id: id)

          result = ::Environments::CanaryIngress::UpdateService
            .new(environment.project, current_user, kwargs)
            .execute_async(environment)

          { errors: Array.wrap(result[:message]) }
        end

        def find_object(id:)
          # TODO: remove as part of https://gitlab.com/gitlab-org/gitlab/-/issues/257883
          id = ::Types::GlobalIDType[::Environment].coerce_isolated_input(id)
          GitlabSchema.find_by_gid(id)
        end

        private

        def cert_based_clusters_ff_disabled?
          Feature.disabled?(:certificate_based_clusters, default_enabled: :yaml, type: :ops)
        end
      end
    end
  end
end

# frozen_string_literal: true

module API
  module Entities
    class Cluster < Grape::Entity
      expose :id, :name, :created_at, :domain
      expose :provider_type, :platform_type, :environment_scope, :cluster_type
      expose :user, using: Entities::UserBasic
      expose :platform_kubernetes, using: Entities::Platform::Kubernetes
      expose :provider_gcp, using: Entities::Provider::Gcp
      expose :management_project, using: Entities::ProjectIdentity
    end
  end
end

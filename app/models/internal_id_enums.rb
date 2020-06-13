# frozen_string_literal: true

module InternalIdEnums
  def self.usage_resources
    # when adding new resource, make sure it doesn't conflict with EE usage_resources
    { issues: 0, merge_requests: 1, deployments: 2, milestones: 3, epics: 4, ci_pipelines: 5, operations_feature_flags: 6 }
  end
end

InternalIdEnums.prepend_if_ee('EE::InternalIdEnums')

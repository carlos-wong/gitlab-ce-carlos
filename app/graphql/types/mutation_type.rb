# frozen_string_literal: true

module Types
  class MutationType < BaseObject
    graphql_name 'Mutation'

    include Gitlab::Graphql::MountMutation

    mount_mutation Mutations::Admin::SidekiqQueues::DeleteJobs
    mount_mutation Mutations::AlertManagement::CreateAlertIssue
    mount_mutation Mutations::AlertManagement::UpdateAlertStatus
    mount_mutation Mutations::AlertManagement::Alerts::SetAssignees
    mount_mutation Mutations::AlertManagement::Alerts::Todo::Create
    mount_mutation Mutations::AlertManagement::HttpIntegration::Create
    mount_mutation Mutations::AlertManagement::HttpIntegration::Update
    mount_mutation Mutations::AlertManagement::HttpIntegration::ResetToken
    mount_mutation Mutations::AlertManagement::HttpIntegration::Destroy
    mount_mutation Mutations::Security::CiConfiguration::ConfigureSast
    mount_mutation Mutations::Security::CiConfiguration::ConfigureSastIac
    mount_mutation Mutations::Security::CiConfiguration::ConfigureSecretDetection
    mount_mutation Mutations::AlertManagement::PrometheusIntegration::Create
    mount_mutation Mutations::AlertManagement::PrometheusIntegration::Update
    mount_mutation Mutations::AlertManagement::PrometheusIntegration::ResetToken
    mount_mutation Mutations::AwardEmojis::Add
    mount_mutation Mutations::AwardEmojis::Remove
    mount_mutation Mutations::AwardEmojis::Toggle
    mount_mutation Mutations::Boards::Create
    mount_mutation Mutations::Boards::Destroy
    mount_mutation Mutations::Boards::Update
    mount_mutation Mutations::Boards::Issues::IssueMoveList
    mount_mutation Mutations::Boards::Lists::Create
    mount_mutation Mutations::Boards::Lists::Update
    mount_mutation Mutations::Boards::Lists::Destroy
    mount_mutation Mutations::Branches::Create, calls_gitaly: true
    mount_mutation Mutations::Clusters::Agents::Create
    mount_mutation Mutations::Clusters::Agents::Delete
    mount_mutation Mutations::Clusters::AgentTokens::Create
    mount_mutation Mutations::Clusters::AgentTokens::Revoke
    mount_mutation Mutations::Commits::Create, calls_gitaly: true
    mount_mutation Mutations::CustomEmoji::Create, feature_flag: :custom_emoji
    mount_mutation Mutations::CustomEmoji::Destroy, feature_flag: :custom_emoji
    mount_mutation Mutations::CustomerRelations::Contacts::Create
    mount_mutation Mutations::CustomerRelations::Contacts::Update
    mount_mutation Mutations::CustomerRelations::Organizations::Create
    mount_mutation Mutations::CustomerRelations::Organizations::Update
    mount_mutation Mutations::Discussions::ToggleResolve
    mount_mutation Mutations::DependencyProxy::ImageTtlGroupPolicy::Update
    mount_mutation Mutations::DependencyProxy::GroupSettings::Update
    mount_mutation Mutations::Environments::CanaryIngress::Update
    mount_mutation Mutations::IncidentManagement::TimelineEvent::Create
    mount_mutation Mutations::IncidentManagement::TimelineEvent::PromoteFromNote
    mount_mutation Mutations::IncidentManagement::TimelineEvent::Update
    mount_mutation Mutations::IncidentManagement::TimelineEvent::Destroy
    mount_mutation Mutations::Issues::Create
    mount_mutation Mutations::Issues::SetAssignees
    mount_mutation Mutations::Issues::SetCrmContacts
    mount_mutation Mutations::Issues::SetConfidential
    mount_mutation Mutations::Issues::SetLocked
    mount_mutation Mutations::Issues::SetDueDate
    mount_mutation Mutations::Issues::SetSeverity
    mount_mutation Mutations::Issues::SetSubscription
    mount_mutation Mutations::Issues::SetEscalationStatus
    mount_mutation Mutations::Issues::Update
    mount_mutation Mutations::Issues::Move
    mount_mutation Mutations::Labels::Create
    mount_mutation Mutations::MergeRequests::Accept
    mount_mutation Mutations::MergeRequests::Create
    mount_mutation Mutations::MergeRequests::Update
    mount_mutation Mutations::MergeRequests::SetLabels
    mount_mutation Mutations::MergeRequests::SetLocked
    mount_mutation Mutations::MergeRequests::SetMilestone
    mount_mutation Mutations::MergeRequests::SetSubscription
    mount_mutation Mutations::MergeRequests::SetDraft, calls_gitaly: true
    mount_mutation Mutations::MergeRequests::SetAssignees
    mount_mutation Mutations::MergeRequests::ReviewerRereview
    mount_mutation Mutations::MergeRequests::RequestAttention
    mount_mutation Mutations::MergeRequests::RemoveAttentionRequest
    mount_mutation Mutations::MergeRequests::ToggleAttentionRequested
    mount_mutation Mutations::Metrics::Dashboard::Annotations::Create
    mount_mutation Mutations::Metrics::Dashboard::Annotations::Delete
    mount_mutation Mutations::Notes::Create::Note, calls_gitaly: true
    mount_mutation Mutations::Notes::Create::DiffNote, calls_gitaly: true
    mount_mutation Mutations::Notes::Create::ImageDiffNote, calls_gitaly: true
    mount_mutation Mutations::Notes::Update::Note
    mount_mutation Mutations::Notes::Update::ImageDiffNote
    mount_mutation Mutations::Notes::RepositionImageDiffNote
    mount_mutation Mutations::Notes::Destroy
    mount_mutation Mutations::Releases::Create
    mount_mutation Mutations::Releases::Update
    mount_mutation Mutations::Releases::Delete
    mount_mutation Mutations::ReleaseAssetLinks::Create
    mount_mutation Mutations::ReleaseAssetLinks::Update
    mount_mutation Mutations::ReleaseAssetLinks::Delete
    mount_mutation Mutations::Terraform::State::Delete
    mount_mutation Mutations::Terraform::State::Lock
    mount_mutation Mutations::Terraform::State::Unlock
    mount_mutation Mutations::Timelogs::Delete
    mount_mutation Mutations::Todos::Create
    mount_mutation Mutations::Todos::MarkDone
    mount_mutation Mutations::Todos::Restore
    mount_mutation Mutations::Todos::MarkAllDone
    mount_mutation Mutations::Todos::RestoreMany
    mount_mutation Mutations::Snippets::Destroy
    mount_mutation Mutations::Snippets::Update
    mount_mutation Mutations::Snippets::Create
    mount_mutation Mutations::Snippets::MarkAsSpam
    mount_mutation Mutations::JiraImport::Start
    mount_mutation Mutations::JiraImport::ImportUsers
    mount_mutation Mutations::DesignManagement::Upload, calls_gitaly: true
    mount_mutation Mutations::DesignManagement::Delete, calls_gitaly: true
    mount_mutation Mutations::DesignManagement::Move
    mount_mutation Mutations::ContainerExpirationPolicies::Update
    mount_mutation Mutations::ContainerRepositories::Destroy
    mount_mutation Mutations::ContainerRepositories::DestroyTags
    mount_mutation Mutations::Ci::Pipeline::Cancel
    mount_mutation Mutations::Ci::Pipeline::Destroy
    mount_mutation Mutations::Ci::Pipeline::Retry
    mount_mutation Mutations::Ci::CiCdSettingsUpdate, deprecated: {
      reason: :renamed,
      replacement: 'ProjectCiCdSettingsUpdate',
      milestone: '15.0'
    }
    mount_mutation Mutations::Ci::ProjectCiCdSettingsUpdate
    mount_mutation Mutations::Ci::Job::Play
    mount_mutation Mutations::Ci::Job::Retry
    mount_mutation Mutations::Ci::Job::Cancel
    mount_mutation Mutations::Ci::Job::Unschedule
    mount_mutation Mutations::Ci::JobTokenScope::AddProject
    mount_mutation Mutations::Ci::JobTokenScope::RemoveProject
    mount_mutation Mutations::Ci::Runner::Update
    mount_mutation Mutations::Ci::Runner::Delete
    mount_mutation Mutations::Ci::RunnersRegistrationToken::Reset
    mount_mutation Mutations::Namespace::PackageSettings::Update
    mount_mutation Mutations::Groups::Update
    mount_mutation Mutations::UserCallouts::Create
    mount_mutation Mutations::UserPreferences::Update
    mount_mutation Mutations::Packages::Destroy
    mount_mutation Mutations::Packages::DestroyFile
    mount_mutation Mutations::Packages::DestroyFiles
    mount_mutation Mutations::Packages::Cleanup::Policy::Update
    mount_mutation Mutations::Echo
    mount_mutation Mutations::WorkItems::Create, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::WorkItems::CreateFromTask, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::WorkItems::Delete, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::WorkItems::DeleteTask, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::WorkItems::Update, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::WorkItems::UpdateWidgets, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::WorkItems::UpdateTask, deprecated: { milestone: '15.1', reason: :alpha }
    mount_mutation Mutations::SavedReplies::Create
    mount_mutation Mutations::SavedReplies::Update
    mount_mutation Mutations::Pages::MarkOnboardingComplete
    mount_mutation Mutations::SavedReplies::Destroy
  end
end

::Types::MutationType.prepend(::Types::DeprecatedMutations)
::Types::MutationType.prepend_mod_with('Types::MutationType')

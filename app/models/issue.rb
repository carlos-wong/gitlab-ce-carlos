# frozen_string_literal: true

require 'carrierwave/orm/activerecord'

class Issue < ApplicationRecord
  include AtomicInternalId
  include IidRoutes
  include Issuable
  include Noteable
  include Referable
  include Spammable
  include FasterCacheKeys
  include RelativePositioning
  include TimeTrackable
  include ThrottledTouch
  include LabelEventable
  include IgnorableColumns
  include MilestoneEventable
  include WhereComposite
  include StateEventable
  include IdInOrdered
  include Presentable
  include IssueAvailableFeatures
  include Todoable
  include FromUnion
  include EachBatch
  include PgFullTextSearchable

  extend ::Gitlab::Utils::Override

  DueDateStruct                   = Struct.new(:title, :name).freeze
  NoDueDate                       = DueDateStruct.new('No Due Date', '0').freeze
  AnyDueDate                      = DueDateStruct.new('Any Due Date', 'any').freeze
  Overdue                         = DueDateStruct.new('Overdue', 'overdue').freeze
  DueToday                        = DueDateStruct.new('Due Today', 'today').freeze
  DueTomorrow                     = DueDateStruct.new('Due Tomorrow', 'tomorrow').freeze
  DueThisWeek                     = DueDateStruct.new('Due This Week', 'week').freeze
  DueThisMonth                    = DueDateStruct.new('Due This Month', 'month').freeze
  DueNextMonthAndPreviousTwoWeeks = DueDateStruct.new('Due Next Month And Previous Two Weeks', 'next_month_and_previous_two_weeks').freeze

  SORTING_PREFERENCE_FIELD = :issues_sort
  MAX_BRANCH_TEMPLATE = 255

  # Types of issues that should be displayed on issue lists across the app
  # for example, project issues list, group issues list, and issues dashboard.
  #
  # This should be kept consistent with the enums used for the GraphQL issue list query in
  # https://gitlab.com/gitlab-org/gitlab/-/blob/1379c2d7bffe2a8d809f23ac5ef9b4114f789c07/app/assets/javascripts/issues/list/constants.js#L154-158
  TYPES_FOR_LIST = %w(issue incident test_case task objective key_result).freeze

  # Types of issues that should be displayed on issue board lists
  TYPES_FOR_BOARD_LIST = %w(issue incident).freeze

  belongs_to :project
  belongs_to :namespace, inverse_of: :issues

  belongs_to :duplicated_to, class_name: 'Issue'
  belongs_to :closed_by, class_name: 'User'
  belongs_to :iteration, foreign_key: 'sprint_id'
  belongs_to :work_item_type, class_name: 'WorkItems::Type', inverse_of: :work_items

  belongs_to :moved_to, class_name: 'Issue'
  has_one :moved_from, class_name: 'Issue', foreign_key: :moved_to_id

  has_internal_id :iid, scope: :namespace, track_if: -> { !importing? }, init: ->(issue, scope) do
    # we need this init for the case where the IID allocation in internal_ids#last_value
    # is higher than the actual issues.max(iid) value for a given project. For instance
    # in case of an import where a batch of IIDs may be prealocated
    #
    # TODO: remove this once the UpdateIssuesInternalIdScope migration completes
    if issue
      [
        InternalId.where(project: issue.project, usage: :issues).pick(:last_value).to_i,
        issue.namespace&.issues&.maximum(:iid).to_i
      ].max
    else
      [
        InternalId.where(**scope, usage: :issues).pick(:last_value).to_i,
        where(**scope).maximum(:iid).to_i
      ].max
    end
  end

  has_many :events, as: :target, dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent

  has_many :merge_requests_closing_issues,
    class_name: 'MergeRequestsClosingIssues',
    dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent

  has_many :issue_assignees
  has_many :issue_email_participants
  has_one :email
  has_many :assignees, class_name: "User", through: :issue_assignees
  has_many :zoom_meetings
  has_many :user_mentions, class_name: "IssueUserMention", dependent: :delete_all # rubocop:disable Cop/ActiveRecordDependent
  has_many :sent_notifications, as: :noteable
  has_many :designs, class_name: 'DesignManagement::Design', inverse_of: :issue
  has_many :design_versions, class_name: 'DesignManagement::Version', inverse_of: :issue do
    def most_recent
      ordered.first
    end
  end

  has_one :search_data, class_name: 'Issues::SearchData'
  has_one :issuable_severity
  has_one :sentry_issue
  has_one :alert_management_alert, class_name: 'AlertManagement::Alert'
  has_one :incident_management_issuable_escalation_status, class_name: 'IncidentManagement::IssuableEscalationStatus'
  has_and_belongs_to_many :self_managed_prometheus_alert_events, join_table: :issues_self_managed_prometheus_alert_events # rubocop: disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :prometheus_alert_events, join_table: :issues_prometheus_alert_events # rubocop: disable Rails/HasAndBelongsToMany
  has_many :alert_management_alerts, class_name: 'AlertManagement::Alert', inverse_of: :issue, validate: false
  has_many :prometheus_alerts, through: :prometheus_alert_events
  has_many :issue_customer_relations_contacts, class_name: 'CustomerRelations::IssueContact', inverse_of: :issue
  has_many :customer_relations_contacts, through: :issue_customer_relations_contacts, source: :contact, class_name: 'CustomerRelations::Contact', inverse_of: :issues
  has_many :incident_management_timeline_events, class_name: 'IncidentManagement::TimelineEvent', foreign_key: :issue_id, inverse_of: :incident

  alias_attribute :escalation_status, :incident_management_issuable_escalation_status

  accepts_nested_attributes_for :issuable_severity, update_only: true
  accepts_nested_attributes_for :sentry_issue
  accepts_nested_attributes_for :incident_management_issuable_escalation_status, update_only: true

  validates :project, presence: true, if: -> { !namespace || namespace.is_a?(Namespaces::ProjectNamespace) }
  validates :issue_type, presence: true
  validates :namespace, presence: true
  validates :work_item_type, presence: true
  validates :confidential, inclusion: { in: [true, false], message: 'must be a boolean' }

  validate :allowed_work_item_type_change, on: :update, if: :work_item_type_id_changed?
  validate :due_date_after_start_date
  validate :parent_link_confidentiality

  enum issue_type: WorkItems::Type.base_types

  alias_method :issuing_parent, :project
  alias_attribute :issuing_parent_id, :project_id

  alias_attribute :external_author, :service_desk_reply_to

  pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }, { name: 'description', weight: 'B' }]

  scope :in_projects, ->(project_ids) { where(project_id: project_ids) }
  scope :not_in_projects, ->(project_ids) { where.not(project_id: project_ids) }

  scope :with_due_date, -> { where.not(due_date: nil) }
  scope :without_due_date, -> { where(due_date: nil) }
  scope :due_before, ->(date) { where('issues.due_date < ?', date) }
  scope :due_between, ->(from_date, to_date) { where('issues.due_date >= ?', from_date).where('issues.due_date <= ?', to_date) }
  scope :due_today, -> { where(due_date: Date.current) }
  scope :due_tomorrow, -> { where(due_date: Date.tomorrow) }

  scope :not_authored_by, ->(user) { where.not(author_id: user) }

  scope :order_due_date_asc, -> { reorder(arel_table[:due_date].asc.nulls_last) }
  scope :order_due_date_desc, -> { reorder(arel_table[:due_date].desc.nulls_last) }
  scope :order_closest_future_date, -> { reorder(Arel.sql("CASE WHEN issues.due_date >= CURRENT_DATE THEN 0 ELSE 1 END ASC, ABS(CURRENT_DATE - issues.due_date) ASC")) }
  scope :order_created_at_desc, -> { reorder(created_at: :desc) }
  scope :order_severity_asc, -> do
    build_keyset_order_on_joined_column(
      scope: includes(:issuable_severity),
      attribute_name: 'issuable_severities_severity',
      column: IssuableSeverity.arel_table[:severity],
      direction: :asc,
      nullable: :nulls_first
    )
  end
  scope :order_severity_desc, -> do
    build_keyset_order_on_joined_column(
      scope: includes(:issuable_severity),
      attribute_name: 'issuable_severities_severity',
      column: IssuableSeverity.arel_table[:severity],
      direction: :desc,
      nullable: :nulls_last
    )
  end
  scope :order_escalation_status_asc, -> { includes(:incident_management_issuable_escalation_status).order(IncidentManagement::IssuableEscalationStatus.arel_table[:status].asc.nulls_last).references(:incident_management_issuable_escalation_status) }
  scope :order_escalation_status_desc, -> { includes(:incident_management_issuable_escalation_status).order(IncidentManagement::IssuableEscalationStatus.arel_table[:status].desc.nulls_last).references(:incident_management_issuable_escalation_status) }
  scope :order_closed_at_asc, -> { reorder(arel_table[:closed_at].asc.nulls_last) }
  scope :order_closed_at_desc, -> { reorder(arel_table[:closed_at].desc.nulls_last) }

  scope :preload_associated_models, -> { preload(:assignees, :labels, project: :namespace) }
  scope :with_web_entity_associations, -> { preload(:author, :namespace, project: [:project_feature, :route, namespace: :route]) }
  scope :preload_awardable, -> { preload(:award_emoji) }
  scope :with_alert_management_alerts, -> { joins(:alert_management_alert) }
  scope :with_prometheus_alert_events, -> { joins(:issues_prometheus_alert_events) }
  scope :with_self_managed_prometheus_alert_events, -> { joins(:issues_self_managed_prometheus_alert_events) }
  scope :with_api_entity_associations, -> {
    preload(:timelogs, :closed_by, :assignees, :author, :labels, :issuable_severity, namespace: [{ parent: :route }, :route],
      milestone: { project: [:route, { namespace: :route }] },
      project: [:project_namespace, :project_feature, :route, { group: :route }, { namespace: :route }],
      duplicated_to: { project: [:project_feature] })
  }
  scope :with_issue_type, ->(types) { where(issue_type: types) }
  scope :without_issue_type, ->(types) { where.not(issue_type: types) }

  scope :public_only, -> { where(confidential: false) }

  scope :confidential_only, -> { where(confidential: true) }

  scope :without_hidden, -> {
    where('NOT EXISTS (?)', Users::BannedUser.select(1).where('issues.author_id = banned_users.user_id'))
  }

  scope :counts_by_state, -> { reorder(nil).group(:state_id).count }

  scope :service_desk, -> { where(author: ::User.support_bot) }
  scope :inc_relations_for_view, -> { includes(author: :status, assignees: :status) }

  # An issue can be uniquely identified by project_id and iid
  # Takes one or more sets of composite IDs, expressed as hash-like records of
  # `{project_id: x, iid: y}`.
  #
  # @see WhereComposite::where_composite
  #
  # e.g:
  #
  #   .by_project_id_and_iid({project_id: 1, iid: 2})
  #   .by_project_id_and_iid([]) # returns ActiveRecord::NullRelation
  #   .by_project_id_and_iid([
  #     {project_id: 1, iid: 1},
  #     {project_id: 2, iid: 1},
  #     {project_id: 1, iid: 2}
  #   ])
  #
  scope :by_project_id_and_iid, ->(composites) do
    where_composite(%i[project_id iid], composites)
  end
  scope :with_null_relative_position, -> { where(relative_position: nil) }
  scope :with_non_null_relative_position, -> { where.not(relative_position: nil) }
  scope :with_projects_matching_search_data, -> { where('issue_search_data.project_id = issues.project_id') }

  before_validation :ensure_namespace_id, :ensure_work_item_type

  after_save :ensure_metrics!, unless: :importing?
  after_commit :expire_etag_cache, unless: :importing?
  after_create_commit :record_create_action, unless: :importing?

  attr_spammable :title, spam_title: true
  attr_spammable :description, spam_description: true

  state_machine :state_id, initial: :opened, initialize: false do
    event :close do
      transition [:opened] => :closed
    end

    event :reopen do
      transition closed: :opened
    end

    state :opened, value: Issue.available_states[:opened]
    state :closed, value: Issue.available_states[:closed]

    before_transition any => :closed do |issue, transition|
      args = transition.args

      issue.closed_at = issue.system_note_timestamp

      next if args.empty?

      next unless args.first.is_a?(User)

      issue.closed_by = args.first
    end

    before_transition closed: :opened do |issue|
      issue.closed_at = nil
      issue.closed_by = nil

      issue.clear_closure_reason_references
    end
  end

  class << self
    extend ::Gitlab::Utils::Override

    # Alias to state machine .with_state_id method
    # This needs to be defined after the state machine block to avoid errors
    alias_method :with_state, :with_state_id
    alias_method :with_states, :with_state_ids

    override :order_upvotes_desc
    def order_upvotes_desc
      reorder(upvotes_count: :desc)
    end

    override :order_upvotes_asc
    def order_upvotes_asc
      reorder(upvotes_count: :asc)
    end

    override :full_search
    def full_search(query, matched_columns: nil, use_minimum_char_limit: true)
      return super if query.match?(IssuableFinder::FULL_TEXT_SEARCH_TERM_REGEX)

      super.where(
        'issues.title NOT SIMILAR TO :pattern OR issues.description NOT SIMILAR TO :pattern',
        pattern: IssuableFinder::FULL_TEXT_SEARCH_TERM_PATTERN
      )
    end
  end

  def self.participant_includes
    [:assignees] + super
  end

  def next_object_by_relative_position(ignoring: nil, order: :asc)
    array_mapping_scope = -> (id_expression) do
      relation = Issue.where(Issue.arel_table[:project_id].eq(id_expression))

      if order == :asc
        relation.where(Issue.arel_table[:relative_position].gt(relative_position))
      else
        relation.where(Issue.arel_table[:relative_position].lt(relative_position))
      end
    end

    relation = Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
      scope: Issue.order(relative_position: order, id: order),
      array_scope: relative_positioning_parent_projects,
      array_mapping_scope: array_mapping_scope,
      finder_query: -> (_, id_expression) { Issue.where(Issue.arel_table[:id].eq(id_expression)) }
    ).execute

    relation = exclude_self(relation, excluded: ignoring) if ignoring.present?

    relation.take
  end

  def relative_positioning_parent_projects
    project.group&.root_ancestor&.all_projects&.select(:id) || Project.id_in(project).select(:id)
  end

  def self.relative_positioning_query_base(issue)
    in_projects(issue.relative_positioning_parent_projects)
  end

  def self.relative_positioning_parent_column
    :project_id
  end

  def self.reference_prefix
    '#'
  end

  # Alternative prefix for situations where the standard prefix would be
  # interpreted as a comment, most notably to begin commit messages with
  # (e.g. "GL-123: My commit")
  def self.alternative_reference_prefix
    'GL-'
  end

  # Pattern used to extract `#123` issue references from text
  #
  # This pattern supports cross-project references.
  def self.reference_pattern
    @reference_pattern ||= %r{
      (?:
        (#{Project.reference_pattern})?#{Regexp.escape(reference_prefix)} |
        #{Regexp.escape(alternative_reference_prefix)}
      )#{Gitlab::Regex.issue}
    }x
  end

  def self.link_reference_pattern
    @link_reference_pattern ||= compose_link_reference_pattern(%r{issues(?:\/incident)?}, Gitlab::Regex.issue)
  end

  def self.reference_valid?(reference)
    reference.to_i > 0 && reference.to_i <= Gitlab::Database::MAX_INT_VALUE
  end

  def self.project_foreign_key
    'project_id'
  end

  def self.simple_sorts
    super.merge(
      {
        'closest_future_date' => -> { order_closest_future_date },
        'closest_future_date_asc' => -> { order_closest_future_date },
        'due_date' => -> { order_due_date_asc.with_order_id_desc },
        'due_date_asc' => -> { order_due_date_asc.with_order_id_desc },
        'due_date_desc' => -> { order_due_date_desc.with_order_id_desc },
        'relative_position' => -> { order_by_relative_position },
        'relative_position_asc' => -> { order_by_relative_position }
      }
    )
  end

  def self.sort_by_attribute(method, excluded_labels: [])
    case method.to_s
    when 'closest_future_date', 'closest_future_date_asc' then order_closest_future_date
    when 'due_date', 'due_date_asc'                       then order_due_date_asc.with_order_id_desc
    when 'due_date_desc'                                  then order_due_date_desc.with_order_id_desc
    when 'relative_position', 'relative_position_asc'     then order_by_relative_position
    when 'severity_asc'                                   then order_severity_asc
    when 'severity_desc'                                  then order_severity_desc
    when 'escalation_status_asc'                          then order_escalation_status_asc
    when 'escalation_status_desc'                         then order_escalation_status_desc
    when 'closed_at', 'closed_at_asc'                     then order_closed_at_asc
    when 'closed_at_desc'                                 then order_closed_at_desc
    else
      super
    end
  end

  def self.order_by_relative_position
    reorder(Gitlab::Pagination::Keyset::Order.build([column_order_relative_position, column_order_id_asc]))
  end

  def self.column_order_relative_position
    Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
      attribute_name: 'relative_position',
      column_expression: arel_table[:relative_position],
      order_expression: Issue.arel_table[:relative_position].asc.nulls_last,
      nullable: :nulls_last,
      distinct: false
    )
  end

  def self.column_order_id_asc
    Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
      attribute_name: 'id',
      order_expression: arel_table[:id].asc
    )
  end

  def self.to_branch_name(id, title, project: nil)
    params = {
      'id' => id.to_s.parameterize(preserve_case: true),
      'title' => title.to_s.parameterize
    }
    template = project&.issue_branch_template

    branch_name =
      if template.present?
        Gitlab::StringPlaceholderReplacer.replace_string_placeholders(template, /(#{params.keys.join('|')})/) do |arg|
          params[arg]
        end
      else
        params.values.select(&:present?).join('-')
      end

    if branch_name.length > 100
      truncated_string = branch_name[0, 100]
      # Delete everything dangling after the last hyphen so as not to risk
      # existence of unintended words in the branch name due to mid-word split.
      branch_name = truncated_string.sub(/-[^-]*\Z/, '')
    end

    branch_name
  end

  # Temporary disable moving null elements because of performance problems
  # For more information check https://gitlab.com/gitlab-com/gl-infra/production/-/issues/4321
  def check_repositioning_allowed!
    if blocked_for_repositioning?
      raise ::Gitlab::RelativePositioning::IssuePositioningDisabled, "Issue relative position changes temporarily disabled."
    end
  end

  def blocked_for_repositioning?
    resource_parent.root_namespace&.issue_repositioning_disabled?
  end

  # `from` argument can be a Namespace or Project.
  def to_reference(from = nil, full: false)
    reference = "#{self.class.reference_prefix}#{iid}"

    "#{namespace.to_reference_base(from, full: full)}#{reference}"
  end

  def suggested_branch_name
    return to_branch_name unless project.repository.branch_exists?(to_branch_name)

    start_counting_from = 2

    branch_name_generator = -> (counter) do
      suffix = counter > 5 ? SecureRandom.hex(8) : counter
      "#{to_branch_name}-#{suffix}"
    end

    Gitlab::Utils::Uniquify.new(start_counting_from).string(branch_name_generator) do |suggested_branch_name|
      project.repository.branch_exists?(suggested_branch_name)
    end
  end

  # To allow polymorphism with MergeRequest.
  def source_project
    project
  end

  def moved?
    !moved_to_id.nil?
  end

  def duplicated?
    !duplicated_to_id.nil?
  end

  def clear_closure_reason_references
    self.moved_to_id = nil
    self.duplicated_to_id = nil
  end

  def can_move?(user, to_project = nil)
    if to_project
      return false unless user.can?(:admin_issue, to_project)
    end

    !moved? && persisted? &&
      user.can?(:admin_issue, self.project)
  end
  alias_method :can_clone?, :can_move?

  def to_branch_name
    if self.confidential?
      "#{iid}-confidential-issue"
    else
      self.class.to_branch_name(iid, title, project: project)
    end
  end

  def related_issues(current_user, preload: nil)
    related_issues = ::Issue
                       .select(['issues.*', 'issue_links.id AS issue_link_id',
                                'issue_links.link_type as issue_link_type_value',
                                'issue_links.target_id as issue_link_source_id',
                                'issue_links.created_at as issue_link_created_at',
                                'issue_links.updated_at as issue_link_updated_at'])
                       .joins("INNER JOIN issue_links ON
	                             (issue_links.source_id = issues.id AND issue_links.target_id = #{id})
	                             OR
	                             (issue_links.target_id = issues.id AND issue_links.source_id = #{id})")
                       .preload(preload)
                       .reorder('issue_link_id')

    related_issues = yield related_issues if block_given?

    cross_project_filter = -> (issues) { issues.where(project: project) }
    Ability.issues_readable_by_user(related_issues,
      current_user,
      filters: { read_cross_project: cross_project_filter })
  end

  def can_be_worked_on?
    !self.closed? && !self.project.forked?
  end

  # Returns `true` if the current issue can be viewed by either a logged in User
  # or an anonymous user.
  def visible_to_user?(user = nil)
    return publicly_visible? unless user

    return false unless readable_by?(user)

    user.can_read_all_resources? ||
      ::Gitlab::ExternalAuthorization.access_allowed?(
        user, project.external_authorization_classification_label)
  end

  def check_for_spam?(user:)
    # content created via support bots is always checked for spam, EVEN if
    # the issue is not publicly visible and/or confidential
    return true if user.support_bot? && spammable_attribute_changed?

    # Only check for spam on issues which are publicly visible (and thus indexed in search engines)
    return false unless publicly_visible?

    # Only check for spam if certain attributes have changed
    spammable_attribute_changed?
  end

  def as_json(options = {})
    super(options).tap do |json|
      if options.key?(:labels)
        json[:labels] = labels.as_json(
          project: project,
          only: [:id, :title, :description, :color, :priority],
          methods: [:text_color]
        )
      end
    end
  end

  def etag_caching_enabled?
    true
  end

  def discussions_rendered_on_frontend?
    true
  end

  # rubocop: disable CodeReuse/ServiceClass
  def update_project_counter_caches
    Projects::OpenIssuesCountService.new(project).refresh_cache
  end
  # rubocop: enable CodeReuse/ServiceClass

  def merge_requests_count(user = nil)
    ::MergeRequestsClosingIssues.count_for_issue(self.id, user)
  end

  def previous_updated_at
    previous_changes['updated_at']&.first || updated_at
  end

  def banzai_render_context(field)
    super.merge(label_url_method: :project_issues_url)
  end

  def design_collection
    @design_collection ||= ::DesignManagement::DesignCollection.new(self)
  end

  def from_service_desk?
    author.id == User.support_bot.id
  end

  def issue_link_type
    return unless respond_to?(:issue_link_type_value) && respond_to?(:issue_link_source_id)

    type = IssueLink.link_types.key(issue_link_type_value) || IssueLink::TYPE_RELATES_TO
    return type if issue_link_source_id == id

    IssueLink.inverse_link_type(type)
  end

  def relocation_target
    moved_to || duplicated_to
  end

  def supports_assignee?
    issue_type_supports?(:assignee)
  end

  def supports_time_tracking?
    issue_type_supports?(:time_tracking)
  end

  def supports_move_and_clone?
    issue_type_supports?(:move_and_clone)
  end

  def email_participants_emails
    issue_email_participants.pluck(:email)
  end

  def email_participants_emails_downcase
    issue_email_participants.pluck(IssueEmailParticipant.arel_table[:email].lower)
  end

  def issue_assignee_user_ids
    issue_assignees.pluck(:user_id)
  end

  def update_upvotes_count
    self.lock!
    self.update_column(:upvotes_count, self.upvotes)
  end

  # Returns `true` if the given User can read the current Issue.
  #
  # This method duplicates the same check of issue_policy.rb
  # for performance reasons, check commit: 002ad215818450d2cbbc5fa065850a953dc7ada8
  # Make sure to sync this method with issue_policy.rb
  def readable_by?(user)
    if !project.issues_enabled?
      false
    elsif user.can_read_all_resources?
      true
    elsif project.personal? && project.team.owner?(user)
      true
    elsif confidential? && !assignee_or_author?(user)
      project.team.member?(user, Gitlab::Access::REPORTER)
    elsif hidden?
      false
    elsif project.public? || (project.internal? && !user.external?)
      project.feature_available?(:issues, user)
    else
      project.team.member?(user)
    end
  end

  def hidden?
    author&.banned?
  end

  def expire_etag_cache
    key = Gitlab::Routing.url_helpers.realtime_changes_project_issue_path(project, self)
    Gitlab::EtagCaching::Store.new.touch(key)
  end

  def supports_confidentiality?
    true
  end

  # we want to have subscriptions working on work items only, legacy issues do not support graphql subscriptions, yet so
  # we need sometimes GID of an issue instance to be represented as WorkItem GID. E.g. notes subscriptions.
  def to_work_item_global_id
    ::Gitlab::GlobalId.as_global_id(id, model_name: WorkItem.name)
  end

  private

  def due_date_after_start_date
    return unless start_date.present? && due_date.present?

    if due_date < start_date
      errors.add(:due_date, 'must be greater than or equal to start date')
    end
  end

  # Although parent/child relationship can be set only for WorkItems, we
  # still need to validate it for Issue model too, because both models use
  # same table.
  def parent_link_confidentiality
    return unless persisted?

    if confidential? && WorkItems::ParentLink.has_public_children?(id)
      errors.add(:base, _('A confidential issue cannot have a parent that already has non-confidential children.'))
    end

    if !confidential? && WorkItems::ParentLink.has_confidential_parent?(id)
      errors.add(:base, _('A non-confidential issue cannot have a confidential parent.'))
    end
  end

  override :persist_pg_full_text_search_vector
  def persist_pg_full_text_search_vector(search_vector)
    Issues::SearchData.upsert({ project_id: project_id, issue_id: id, search_vector: search_vector }, unique_by: %i(project_id issue_id))
  end

  def spammable_attribute_changed?
    title_changed? ||
      description_changed? ||
      # NOTE: We need to check them for spam when issues are made non-confidential, because spam
      # may have been added while they were confidential and thus not being checked for spam.
      confidential_changed?(from: true, to: false)
  end

  def ensure_metrics!
    Issue::Metrics.record!(self)
  end

  def record_create_action
    Gitlab::UsageDataCounters::IssueActivityUniqueCounter.track_issue_created_action(author: author, project: project)
  end

  # Returns `true` if this Issue is visible to everybody.
  def publicly_visible?
    project.public? && project.feature_available?(:issues, nil) &&
      !confidential? && !hidden? && !::Gitlab::ExternalAuthorization.enabled?
  end

  def could_not_move(exception)
    # Symptom of running out of space - schedule rebalancing
    Issues::RebalancingWorker.perform_async(nil, *project.self_or_root_group_ids)
  end

  def ensure_namespace_id
    self.namespace = project.project_namespace if project
  end

  def ensure_work_item_type
    return if work_item_type_id.present? || work_item_type_id_change&.last.present?

    self.work_item_type = WorkItems::Type.default_by_type(issue_type)
  end

  def allowed_work_item_type_change
    return unless changes[:work_item_type_id]

    involved_types = WorkItems::Type.where(id: changes[:work_item_type_id].compact).pluck(:base_type).uniq
    disallowed_types = involved_types - WorkItems::Type::CHANGEABLE_BASE_TYPES

    return if disallowed_types.empty?

    errors.add(:work_item_type_id, format(_('can not be changed to %{new_type}'), new_type: work_item_type&.name))
  end
end

Issue.prepend_mod_with('Issue')

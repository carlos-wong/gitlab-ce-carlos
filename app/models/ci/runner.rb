# frozen_string_literal: true

module Ci
  class Runner < Ci::ApplicationRecord
    prepend Ci::BulkInsertableTags
    include Gitlab::SQL::Pattern
    include RedisCacheable
    include ChronicDurationAttribute
    include FromUnion
    include TokenAuthenticatable
    include IgnorableColumns
    include FeatureGate
    include Gitlab::Utils::StrongMemoize
    include TaggableQueries
    include Presentable
    include EachBatch

    ignore_column :semver, remove_with: '15.3', remove_after: '2022-07-22'

    add_authentication_token_field :token, encrypted: :optional, expires_at: :compute_token_expiration, expiration_enforced?: :token_expiration_enforced?

    enum access_level: {
      not_protected: 0,
      ref_protected: 1
    }

    enum runner_type: {
      instance_type: 1,
      group_type: 2,
      project_type: 3
    }

    enum executor_type: {
      unknown: 0,
      custom: 1,
      shell: 2,
      docker: 3,
      docker_windows: 4,
      docker_ssh: 5,
      ssh: 6,
      parallels: 7,
      virtualbox: 8,
      docker_machine: 9,
      docker_ssh_machine: 10,
      kubernetes: 11
    }, _suffix: true

    # This `ONLINE_CONTACT_TIMEOUT` needs to be larger than
    #   `RUNNER_QUEUE_EXPIRY_TIME+UPDATE_CONTACT_COLUMN_EVERY`
    #
    ONLINE_CONTACT_TIMEOUT = 2.hours

    # The `RUNNER_QUEUE_EXPIRY_TIME` indicates the longest interval that
    #   Runner request needs to be refreshed by Rails instead of being handled
    #   by Workhorse
    RUNNER_QUEUE_EXPIRY_TIME = 1.hour

    # The `UPDATE_CONTACT_COLUMN_EVERY` defines how often the Runner DB entry can be updated
    UPDATE_CONTACT_COLUMN_EVERY = (40.minutes..55.minutes).freeze

    # The `STALE_TIMEOUT` constant defines the how far past the last contact or creation date a runner will be considered stale
    STALE_TIMEOUT = 3.months

    AVAILABLE_TYPES_LEGACY = %w[specific shared].freeze
    AVAILABLE_TYPES = runner_types.keys.freeze
    AVAILABLE_STATUSES = %w[active paused online offline never_contacted stale].freeze # TODO: Remove in %16.0: active, paused. Relevant issue: https://gitlab.com/gitlab-org/gitlab/-/issues/344648
    AVAILABLE_SCOPES = (AVAILABLE_TYPES_LEGACY + AVAILABLE_TYPES + AVAILABLE_STATUSES).freeze

    FORM_EDITABLE = %i[description tag_list active run_untagged locked access_level maximum_timeout_human_readable].freeze
    MINUTES_COST_FACTOR_FIELDS = %i[public_projects_minutes_cost_factor private_projects_minutes_cost_factor].freeze

    TAG_LIST_MAX_LENGTH = 50

    has_many :builds
    has_many :runner_projects, inverse_of: :runner, autosave: true, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent
    has_many :projects, through: :runner_projects, disable_joins: true
    has_many :runner_namespaces, inverse_of: :runner, autosave: true
    has_many :groups, through: :runner_namespaces, disable_joins: true

    has_one :last_build, -> { order('id DESC') }, class_name: 'Ci::Build'
    has_one :runner_version, primary_key: :version, foreign_key: :version, class_name: 'Ci::RunnerVersion'

    before_save :ensure_token

    scope :active, -> (value = true) { where(active: value) }
    scope :paused, -> { active(false) }
    scope :online, -> { where('contacted_at > ?', online_contact_time_deadline) }
    scope :recent, -> { where('ci_runners.created_at >= :date OR ci_runners.contacted_at >= :date', date: stale_deadline) }
    scope :stale, -> { where('ci_runners.created_at < :date AND (ci_runners.contacted_at IS NULL OR ci_runners.contacted_at < :date)', date: stale_deadline) }
    scope :offline, -> { where(arel_table[:contacted_at].lteq(online_contact_time_deadline)) }
    scope :never_contacted, -> { where(contacted_at: nil) }
    scope :ordered, -> { order(id: :desc) }

    scope :with_recent_runner_queue, -> { where('contacted_at > ?', recent_queue_deadline) }

    # BACKWARD COMPATIBILITY: There are needed to maintain compatibility with `AVAILABLE_SCOPES` used by `lib/api/runners.rb`
    scope :deprecated_shared, -> { instance_type }
    scope :deprecated_specific, -> { project_type.or(group_type) }

    scope :belonging_to_project, -> (project_id) {
      joins(:runner_projects).where(ci_runner_projects: { project_id: project_id })
    }

    scope :belonging_to_group, -> (group_id) {
      joins(:runner_namespaces)
        .where(ci_runner_namespaces: { namespace_id: group_id })
    }

    scope :belonging_to_group_or_project_descendants, -> (group_id) {
      group_ids = Ci::NamespaceMirror.by_group_and_descendants(group_id).select(:namespace_id)
      project_ids = Ci::ProjectMirror.by_namespace_id(group_ids).select(:project_id)

      group_runners = joins(:runner_namespaces).where(ci_runner_namespaces: { namespace_id: group_ids })
      project_runners = joins(:runner_projects).where(ci_runner_projects: { project_id: project_ids })

      union_sql = ::Gitlab::SQL::Union.new([group_runners, project_runners]).to_sql

      from("(#{union_sql}) #{table_name}")
    }

    scope :belonging_to_group_and_ancestors, -> (group_id) {
      group_self_and_ancestors_ids = ::Group.find_by(id: group_id)&.self_and_ancestor_ids

      joins(:runner_namespaces)
        .where(ci_runner_namespaces: { namespace_id: group_self_and_ancestors_ids })
    }

    scope :belonging_to_parent_group_of_project, -> (project_id) {
      raise ArgumentError, "only 1 project_id allowed for performance reasons" unless project_id.is_a?(Integer)

      project_groups = ::Group.joins(:projects).where(projects: { id: project_id })

      belonging_to_group(project_groups.self_and_ancestors.pluck(:id))
    }

    scope :owned_or_instance_wide, -> (project_id) do
      project = project_id.respond_to?(:shared_runners) ? project_id : Project.find(project_id)

      from_union(
        [
          belonging_to_project(project_id),
          project.group_runners_enabled? ? belonging_to_parent_group_of_project(project_id) : nil,
          project.shared_runners
        ].compact,
        remove_duplicates: false
      )
    end

    scope :group_or_instance_wide, -> (group) do
      from_union(
        [
          belonging_to_group_and_ancestors(group.id),
          group.shared_runners
        ],
        remove_duplicates: false
      )
    end

    scope :assignable_for, ->(project) do
      # FIXME: That `to_sql` is needed to workaround a weird Rails bug.
      #        Without that, placeholders would miss one and couldn't match.
      #
      # We use "unscoped" here so that any current Ci::Runner filters don't
      # apply to the inner query, which is not necessary.
      exclude_runners = unscoped { project.runners.select(:id) }.to_sql

      where(locked: false)
        .where.not("ci_runners.id IN (#{exclude_runners})")
        .project_type
    end

    scope :order_contacted_at_asc, -> { order(contacted_at: :asc) }
    scope :order_contacted_at_desc, -> { order(contacted_at: :desc) }
    scope :order_created_at_asc, -> { order(created_at: :asc) }
    scope :order_created_at_desc, -> { order(created_at: :desc) }
    scope :order_token_expires_at_asc, -> { order(token_expires_at: :asc) }
    scope :order_token_expires_at_desc, -> { order(token_expires_at: :desc) }
    scope :with_tags, -> { preload(:tags) }

    validate :tag_constraints
    validates :access_level, presence: true
    validates :runner_type, presence: true

    validate :no_projects, unless: :project_type?
    validate :no_groups, unless: :group_type?
    validate :any_project, if: :project_type?
    validate :exactly_one_group, if: :group_type?

    acts_as_taggable

    after_destroy :cleanup_runner_queue

    cached_attr_reader :version, :revision, :platform, :architecture, :ip_address, :contacted_at, :executor_type

    chronic_duration_attr :maximum_timeout_human_readable, :maximum_timeout,
        error_message: 'Maximum job timeout has a value which could not be accepted'

    validates :maximum_timeout, allow_nil: true,
                                numericality: { greater_than_or_equal_to: 600,
                                                message: 'needs to be at least 10 minutes' }

    validates :public_projects_minutes_cost_factor, :private_projects_minutes_cost_factor,
      allow_nil: false,
      numericality: { greater_than_or_equal_to: 0.0,
                      message: 'needs to be non-negative' }

    validates :config, json_schema: { filename: 'ci_runner_config' }

    validates :maintenance_note, length: { maximum: 1024 }

    alias_attribute :maintenance_note, :maintainer_note

    # Searches for runners matching the given query.
    #
    # This method uses ILIKE on PostgreSQL for the description field and performs a full match on tokens.
    #
    # query - The search query as a String.
    #
    # Returns an ActiveRecord::Relation.
    def self.search(query)
      where(token: query).or(fuzzy_search(query, [:description]))
    end

    def self.online_contact_time_deadline
      ONLINE_CONTACT_TIMEOUT.ago
    end

    def self.stale_deadline
      STALE_TIMEOUT.ago
    end

    def self.recent_queue_deadline
      # we add queue expiry + online
      # - contacted_at can be updated at any time within this interval
      #   we have always accurate `contacted_at` but it is stored in Redis
      #   and not persisted in database
      (ONLINE_CONTACT_TIMEOUT + RUNNER_QUEUE_EXPIRY_TIME).ago
    end

    def self.order_by(order)
      case order
      when 'contacted_asc'
        order_contacted_at_asc
      when 'contacted_desc'
        order_contacted_at_desc
      when 'created_at_asc'
        order_created_at_asc
      when 'token_expires_at_asc'
        order_token_expires_at_asc
      when 'token_expires_at_desc'
        order_token_expires_at_desc
      else
        order_created_at_desc
      end
    end

    def self.runner_matchers
      unique_params = [
        :runner_type,
        :public_projects_minutes_cost_factor,
        :private_projects_minutes_cost_factor,
        :run_untagged,
        :access_level,
        Arel.sql("(#{arel_tag_names_array.to_sql})")
      ]

      group(*unique_params).pluck('array_agg(ci_runners.id)', *unique_params).map do |values|
        Gitlab::Ci::Matching::RunnerMatcher.new({
          runner_ids: values[0],
          runner_type: values[1],
          public_projects_minutes_cost_factor: values[2],
          private_projects_minutes_cost_factor: values[3],
          run_untagged: values[4],
          access_level: values[5],
          tag_list: values[6]
        })
      end
    end

    def runner_matcher
      strong_memoize(:runner_matcher) do
        Gitlab::Ci::Matching::RunnerMatcher.new({
          runner_ids: [id],
          runner_type: runner_type,
          public_projects_minutes_cost_factor: public_projects_minutes_cost_factor,
          private_projects_minutes_cost_factor: private_projects_minutes_cost_factor,
          run_untagged: run_untagged,
          access_level: access_level,
          tag_list: tag_list
        })
      end
    end

    def assign_to(project, current_user = nil)
      if instance_type?
        raise ArgumentError, 'Transitioning an instance runner to a project runner is not supported'
      elsif group_type?
        raise ArgumentError, 'Transitioning a group runner to a project runner is not supported'
      end

      begin
        transaction do
          self.runner_projects << ::Ci::RunnerProject.new(project: project, runner: self)
          self.save!
        end
      rescue ActiveRecord::RecordInvalid => e
        self.errors.add(:assign_to, e.message)
        false
      end
    end

    def display_name
      return short_sha if description.blank?

      description
    end

    def online?
      contacted_at && contacted_at > self.class.online_contact_time_deadline
    end

    def stale?
      return false unless created_at

      [created_at, contacted_at].compact.max < self.class.stale_deadline
    end

    def status(legacy_mode = nil)
      # TODO Deprecate legacy_mode in %16.0 and make it a no-op
      #   (see https://gitlab.com/gitlab-org/gitlab/-/issues/360545)
      # TODO Remove legacy_mode in %17.0
      return deprecated_rest_status if legacy_mode == '14.5'

      return :stale if stale?
      return :never_contacted unless contacted_at

      online? ? :online : :offline
    end

    # DEPRECATED
    # TODO Remove in %16.0 in favor of `status` for REST calls, see https://gitlab.com/gitlab-org/gitlab/-/issues/344648
    def deprecated_rest_status
      return :stale if stale?

      if contacted_at.nil?
        :never_contacted
      elsif active?
        online? ? :online : :offline
      else
        :paused
      end
    end

    def belongs_to_one_project?
      runner_projects.count == 1
    end

    def belongs_to_more_than_one_project?
      runner_projects.limit(2).count(:all) > 1
    end

    def assigned_to_group?
      runner_namespaces.any?
    end

    def assigned_to_project?
      runner_projects.any?
    end

    def match_build_if_online?(build)
      active? && online? && matches_build?(build)
    end

    def only_for?(project)
      !runner_projects.where.not(project_id: project.id).exists?
    end

    def short_sha
      token[0...8] if token
    end

    def tag_list
      if tags.loaded?
        tags.map(&:name)
      else
        super
      end
    end

    def has_tags?
      tag_list.any?
    end

    def predefined_variables
      Gitlab::Ci::Variables::Collection.new
        .append(key: 'CI_RUNNER_ID', value: id.to_s)
        .append(key: 'CI_RUNNER_DESCRIPTION', value: description)
        .append(key: 'CI_RUNNER_TAGS', value: tag_list.to_s)
    end

    def tick_runner_queue
      ##
      # We only stick a runner to primary database to be able to detect the
      # replication lag in `EE::Ci::RegisterJobService#execute`. The
      # intention here is not to execute `Ci::RegisterJobService#execute` on
      # the primary database.
      #
      ::Ci::Runner.sticking.stick(:runner, id)

      SecureRandom.hex.tap do |new_update|
        ::Gitlab::Workhorse.set_key_and_notify(runner_queue_key, new_update,
          expire: RUNNER_QUEUE_EXPIRY_TIME, overwrite: true)
      end
    end

    def ensure_runner_queue_value
      new_value = SecureRandom.hex
      ::Gitlab::Workhorse.set_key_and_notify(runner_queue_key, new_value,
        expire: RUNNER_QUEUE_EXPIRY_TIME, overwrite: false)
    end

    def runner_queue_value_latest?(value)
      ensure_runner_queue_value == value if value.present?
    end

    def heartbeat(values)
      ##
      # We can safely ignore writes performed by a runner heartbeat. We do
      # not want to upgrade database connection proxy to use the primary
      # database after heartbeat write happens.
      #
      ::Gitlab::Database::LoadBalancing::Session.without_sticky_writes do
        values = values&.slice(:version, :revision, :platform, :architecture, :ip_address, :config, :executor) || {}
        values[:contacted_at] = Time.current
        values[:executor_type] = EXECUTOR_NAME_TO_TYPES.fetch(values.delete(:executor), :unknown)

        cache_attributes(values)

        # We save data without validation, it will always change due to `contacted_at`
        self.update_columns(values) if persist_cached_data?
      end
    end

    def pick_build!(build)
      tick_runner_queue if matches_build?(build)
    end

    def matches_build?(build)
      runner_matcher.matches?(build.build_matcher)
    end

    def uncached_contacted_at
      read_attribute(:contacted_at)
    end

    def namespace_ids
      strong_memoize(:namespace_ids) do
        runner_namespaces.pluck(:namespace_id).compact
      end
    end

    def compute_token_expiration
      case runner_type
      when 'instance_type'
        compute_token_expiration_instance
      when 'group_type'
        compute_token_expiration_group
      when 'project_type'
        compute_token_expiration_project
      end
    end

    def self.token_expiration_enforced?
      Feature.enabled?(:enforce_runner_token_expires_at)
    end

    private

    scope :with_upgrade_status, ->(upgrade_status) do
      Ci::Runner.joins(:runner_version).where(runner_version: { status: upgrade_status })
    end

    EXECUTOR_NAME_TO_TYPES = {
      'unknown' => :unknown,
      'custom' => :custom,
      'shell' => :shell,
      'docker' => :docker,
      'docker-windows' => :docker_windows,
      'docker-ssh' => :docker_ssh,
      'ssh' => :ssh,
      'parallels' => :parallels,
      'virtualbox' => :virtualbox,
      'docker+machine' => :docker_machine,
      'docker-ssh+machine' => :docker_ssh_machine,
      'kubernetes' => :kubernetes
    }.freeze

    EXECUTOR_TYPE_TO_NAMES = EXECUTOR_NAME_TO_TYPES.invert.freeze

    def compute_token_expiration_instance
      return unless expiration_interval = Gitlab::CurrentSettings.runner_token_expiration_interval

      expiration_interval.seconds.from_now
    end

    def compute_token_expiration_group
      ::Group.where(id: runner_namespaces.map(&:namespace_id)).map(&:effective_runner_token_expiration_interval).compact.min&.from_now
    end

    def compute_token_expiration_project
      Project.where(id: runner_projects.map(&:project_id)).map(&:effective_runner_token_expiration_interval).compact.min&.from_now
    end

    def cleanup_runner_queue
      Gitlab::Redis::SharedState.with do |redis|
        redis.del(runner_queue_key)
      end
    end

    def runner_queue_key
      "runner:build_queue:#{self.token}"
    end

    def persist_cached_data?
      # Use a random threshold to prevent beating DB updates.
      contacted_at_max_age = Random.rand(UPDATE_CONTACT_COLUMN_EVERY)

      real_contacted_at = read_attribute(:contacted_at)
      real_contacted_at.nil? ||
        (Time.current - real_contacted_at) >= contacted_at_max_age
    end

    def tag_constraints
      unless has_tags? || run_untagged?
        errors.add(:tags_list,
          'can not be empty when runner is not allowed to pick untagged jobs')
      end

      if tag_list_changed? && tag_list.count > TAG_LIST_MAX_LENGTH
        errors.add(:tags_list,
          "Too many tags specified. Please limit the number of tags to #{TAG_LIST_MAX_LENGTH}")
      end
    end

    def no_projects
      if runner_projects.any?
        errors.add(:runner, 'cannot have projects assigned')
      end
    end

    def no_groups
      if runner_namespaces.any?
        errors.add(:runner, 'cannot have groups assigned')
      end
    end

    def any_project
      unless runner_projects.any?
        errors.add(:runner, 'needs to be assigned to at least one project')
      end
    end

    def exactly_one_group
      unless runner_namespaces.one?
        errors.add(:runner, 'needs to be assigned to exactly one group')
      end
    end
  end
end

Ci::Runner.prepend_mod_with('Ci::Runner')

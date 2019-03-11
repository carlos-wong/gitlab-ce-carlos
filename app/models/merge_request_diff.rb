# frozen_string_literal: true

class MergeRequestDiff < ActiveRecord::Base
  include Sortable
  include Importable
  include ManualInverseAssociation
  include IgnorableColumn
  include EachBatch
  include Gitlab::Utils::StrongMemoize
  include ObjectStorage::BackgroundMove

  # Don't display more than 100 commits at once
  COMMITS_SAFE_SIZE = 100

  belongs_to :merge_request

  manual_inverse_association :merge_request, :merge_request_diff

  has_many :merge_request_diff_files,
    -> { order(:merge_request_diff_id, :relative_order) },
    inverse_of: :merge_request_diff

  has_many :merge_request_diff_commits, -> { order(:merge_request_diff_id, :relative_order) }

  validates :base_commit_sha, :head_commit_sha, :start_commit_sha, sha: true

  state_machine :state, initial: :empty do
    event :clean do
      transition any => :without_files
    end

    state :collected
    state :overflow
    # Diff files have been deleted by the system
    state :without_files
    # Deprecated states: these are no longer used but these values may still occur
    # in the database.
    state :timeout
    state :overflow_commits_safe_size
    state :overflow_diff_files_limit
    state :overflow_diff_lines_limit
  end

  scope :with_files, -> { without_states(:without_files, :empty) }
  scope :viewable, -> { without_state(:empty) }
  scope :by_commit_sha, ->(sha) do
    joins(:merge_request_diff_commits).where(merge_request_diff_commits: { sha: sha }).reorder(nil)
  end

  scope :recent, -> { order(id: :desc).limit(100) }

  mount_uploader :external_diff, ExternalDiffUploader

  # All diff information is collected from repository after object is created.
  # It allows you to override variables like head_commit_sha before getting diff.
  after_create :save_git_content, unless: :importing?

  after_save :update_external_diff_store, if: :external_diff_changed?

  def self.find_by_diff_refs(diff_refs)
    find_by(start_commit_sha: diff_refs.start_sha, head_commit_sha: diff_refs.head_sha, base_commit_sha: diff_refs.base_sha)
  end

  def viewable?
    collected? || without_files? || overflow?
  end

  # Collect information about commits and diff from repository
  # and save it to the database as serialized data
  def save_git_content
    MergeRequest
      .where('id = ? AND COALESCE(latest_merge_request_diff_id, 0) < ?', self.merge_request_id, self.id)
      .update_all(latest_merge_request_diff_id: self.id)

    ensure_commit_shas
    save_commits
    save_diffs
    save
    keep_around_commits
  end

  def ensure_commit_shas
    self.start_commit_sha ||= merge_request.target_branch_sha
    self.head_commit_sha  ||= merge_request.source_branch_sha
    self.base_commit_sha  ||= find_base_sha
  end

  # Override head_commit_sha to keep compatibility with merge request diff
  # created before version 8.4 that does not store head_commit_sha in separate db field.
  def head_commit_sha
    if persisted? && super.nil?
      last_commit_sha
    else
      super
    end
  end

  # This method will rely on repository branch sha
  # in case start_commit_sha is nil. Its necesarry for old merge request diff
  # created before version 8.4 to work
  def safe_start_commit_sha
    start_commit_sha || merge_request.target_branch_sha
  end

  def size
    real_size.presence || raw_diffs.size
  end

  def raw_diffs(options = {})
    if options[:ignore_whitespace_change]
      @diffs_no_whitespace ||= compare.diffs(options)
    else
      @raw_diffs ||= {}
      @raw_diffs[options] ||= load_diffs(options)
    end
  end

  def commits
    @commits ||= load_commits
  end

  def last_commit_sha
    commit_shas.first
  end

  def first_commit
    commits.last
  end

  def base_commit
    return unless base_commit_sha

    project.commit_by(oid: base_commit_sha)
  end

  def start_commit
    return unless start_commit_sha

    project.commit_by(oid: start_commit_sha)
  end

  def head_commit
    return unless head_commit_sha

    project.commit_by(oid: head_commit_sha)
  end

  def commit_shas
    merge_request_diff_commits.map(&:sha)
  end

  def commits_by_shas(shas)
    return MergeRequestDiffCommit.none unless shas.present?

    merge_request_diff_commits.where(sha: shas)
  end

  def diff_refs=(new_diff_refs)
    self.base_commit_sha = new_diff_refs&.base_sha
    self.start_commit_sha = new_diff_refs&.start_sha
    self.head_commit_sha = new_diff_refs&.head_sha
  end

  def diff_refs
    return unless start_commit_sha || base_commit_sha

    Gitlab::Diff::DiffRefs.new(
      base_sha:  base_commit_sha,
      start_sha: start_commit_sha,
      head_sha:  head_commit_sha
    )
  end

  # MRs created before 8.4 don't store their true diff refs (start and base),
  # but we need to get a commit SHA for the "View file @ ..." link by a file,
  # so we use an approximation of the diff refs if we can't get the actual one.
  #
  # These will not be the actual diff refs if the target branch was merged into
  # the source branch after the merge request was created, but it is good enough
  # for the specific purpose of linking to a commit.
  #
  # It is not good enough for highlighting diffs, so we can't simply pass
  # these as `diff_refs.`
  def fallback_diff_refs
    real_refs = diff_refs
    return real_refs if real_refs

    likely_base_commit_sha = (first_commit&.parent || first_commit)&.sha

    Gitlab::Diff::DiffRefs.new(
      base_sha:  likely_base_commit_sha,
      start_sha: safe_start_commit_sha,
      head_sha:  head_commit_sha
    )
  end

  def diff_refs_by_sha?
    base_commit_sha? && head_commit_sha? && start_commit_sha?
  end

  def diffs(diff_options = nil)
    if without_files? && comparison = diff_refs&.compare_in(project)
      # It should fetch the repository when diffs are cleaned by the system.
      # We don't keep these for storage overload purposes.
      # See https://gitlab.com/gitlab-org/gitlab-ce/issues/37639
      comparison.diffs(diff_options)
    else
      diffs_collection(diff_options)
    end
  end

  # Should always return the DB persisted diffs collection
  # (e.g. Gitlab::Diff::FileCollection::MergeRequestDiff.
  # It's useful when trying to invalidate old caches through
  # FileCollection::MergeRequestDiff#clear_cache!
  def diffs_collection(diff_options = nil)
    Gitlab::Diff::FileCollection::MergeRequestDiff.new(self, diff_options: diff_options)
  end

  def project
    merge_request.target_project
  end

  def compare
    @compare ||=
      Gitlab::Git::Compare.new(
        repository.raw_repository,
        safe_start_commit_sha,
        head_commit_sha
      )
  end

  def latest?
    self.id == merge_request.latest_merge_request_diff_id
  end

  # rubocop: disable CodeReuse/ServiceClass
  def compare_with(sha)
    # When compare merge request versions we want diff A..B instead of A...B
    # so we handle cases when user does squash and rebase of the commits between versions.
    # For this reason we set straight to true by default.
    CompareService.new(project, head_commit_sha).execute(project, sha, straight: true)
  end
  # rubocop: enable CodeReuse/ServiceClass

  def modified_paths
    strong_memoize(:modified_paths) do
      merge_request_diff_files.pluck(:new_path, :old_path).flatten.uniq
    end
  end

  # Carrierwave defines `write_uploader` dynamically on this class, so `super`
  # does not work. Alias the carrierwave method so we can call it when needed
  alias_method :carrierwave_write_uploader, :write_uploader

  # The `external_diff`, `external_diff_store`, and `stored_externally`
  # columns were introduced in GitLab 11.8, but some background migration specs
  # use factories that rely on current code with an old schema. Without these
  # `has_attribute?` guards, they fail with a `MissingAttributeError`.
  #
  # For more details, see: https://gitlab.com/gitlab-org/gitlab-ce/issues/44990

  def write_uploader(column, identifier)
    carrierwave_write_uploader(column, identifier) if has_attribute?(column)
  end

  def update_external_diff_store
    update_column(:external_diff_store, external_diff.object_store) if
      has_attribute?(:external_diff_store)
  end

  def external_diff_changed?
    super if has_attribute?(:external_diff)
  end

  def stored_externally
    super if has_attribute?(:stored_externally)
  end
  alias_method :stored_externally?, :stored_externally

  # If enabled, yields the external file containing the diff. Otherwise, yields
  # nil. This method is not thread-safe, but it *is* re-entrant, which allows
  # multiple merge_request_diff_files to load their data efficiently
  def opening_external_diff
    return yield(nil) unless stored_externally?
    return yield(@external_diff_file) if @external_diff_file

    external_diff.open do |file|
      begin
        @external_diff_file = file

        yield(@external_diff_file)
      ensure
        @external_diff_file = nil
      end
    end
  end

  private

  def create_merge_request_diff_files(diffs)
    rows =
      if has_attribute?(:external_diff) && Gitlab.config.external_diffs.enabled
        build_external_merge_request_diff_files(diffs)
      else
        build_merge_request_diff_files(diffs)
      end

    # Faster inserts
    Gitlab::Database.bulk_insert('merge_request_diff_files', rows)
  end

  def build_external_merge_request_diff_files(diffs)
    rows = build_merge_request_diff_files(diffs)
    tempfile = build_external_diff_tempfile(rows)

    self.external_diff = tempfile
    self.stored_externally = true

    rows
  ensure
    tempfile&.unlink
  end

  def build_external_diff_tempfile(rows)
    Tempfile.open(external_diff.filename) do |file|
      rows.inject(0) do |offset, row|
        data = row.delete(:diff)
        row[:external_diff_offset] = offset
        row[:external_diff_size] = data.size

        file.write(data)

        offset + data.size
      end

      file
    end
  end

  def build_merge_request_diff_files(diffs)
    diffs.map.with_index do |diff, index|
      diff_hash = diff.to_hash.merge(
        binary: false,
        merge_request_diff_id: self.id,
        relative_order: index
      )

      # Compatibility with old diffs created with Psych.
      diff_hash.tap do |hash|
        diff_text = hash[:diff]

        if diff_text.encoding == Encoding::BINARY && !diff_text.ascii_only?
          hash[:binary] = true
          hash[:diff] = [diff_text].pack('m0')
        end
      end
    end
  end

  def load_diffs(options)
    # Ensure all diff files operate on the same external diff file instance if
    # present. This reduces file open/close overhead.
    opening_external_diff do
      collection = merge_request_diff_files

      if paths = options[:paths]
        collection = collection.where('old_path IN (?) OR new_path IN (?)', paths, paths)
      end

      Gitlab::Git::DiffCollection.new(collection.map(&:to_hash), options)
    end
  end

  def load_commits
    commits = merge_request_diff_commits.map { |commit| Commit.from_hash(commit.to_hash, project) }

    CommitCollection
      .new(merge_request.source_project, commits, merge_request.source_branch)
  end

  def save_diffs
    new_attributes = {}

    if compare.commits.size.zero?
      new_attributes[:state] = :empty
    else
      diff_collection = compare.diffs(Commit.max_diff_options)
      new_attributes[:real_size] = diff_collection.real_size

      if diff_collection.any?
        new_attributes[:state] = :collected

        create_merge_request_diff_files(diff_collection)
      end

      # Set our state to 'overflow' to make the #empty? and #collected?
      # methods (generated by StateMachine) return false.
      #
      # This attribution has to come at the end of the method so 'overflow'
      # state does not get overridden by 'collected'.
      new_attributes[:state] = :overflow if diff_collection.overflow?
    end

    assign_attributes(new_attributes)
  end

  def save_commits
    MergeRequestDiffCommit.create_bulk(self.id, compare.commits.reverse)

    # merge_request_diff_commits.reload is preferred way to reload associated
    # objects but it returns cached result for some reason in this case
    # we can circumvent that by specifying that we need an uncached reload
    commits = self.class.uncached { merge_request_diff_commits.reload }
    self.commits_count = commits.size
  end

  def repository
    project.repository
  end

  def find_base_sha
    return unless head_commit_sha && start_commit_sha

    project.merge_base_commit(head_commit_sha, start_commit_sha).try(:sha)
  end

  def keep_around_commits
    [repository, merge_request.source_project.repository].uniq.each do |repo|
      repo.keep_around(start_commit_sha, head_commit_sha, base_commit_sha)
    end
  end
end

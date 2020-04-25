# frozen_string_literal: true

# == Mentionable concern
#
# Contains functionality related to objects that can mention Users, Issues, MergeRequests, Commits or Snippets by
# GFM references.
#
# Used by Issue, Note, MergeRequest, and Commit.
#
module Mentionable
  extend ActiveSupport::Concern

  class_methods do
    # Indicate which attributes of the Mentionable to search for GFM references.
    def attr_mentionable(attr, options = {})
      attr = attr.to_s
      mentionable_attrs << [attr, options]
    end
  end

  included do
    # Accessor for attributes marked mentionable.
    cattr_accessor :mentionable_attrs, instance_accessor: false do
      []
    end

    if self < Participable
      participant -> (user, ext) { all_references(user, extractor: ext) }
    end
  end

  # Returns the text used as the body of a Note when this object is referenced
  #
  # By default this will be the class name and the result of calling
  # `to_reference` on the object.
  def gfm_reference(from = nil)
    # "MergeRequest" > "merge_request" > "Merge request" > "merge request"
    friendly_name = self.class.to_s.underscore.humanize.downcase

    "#{friendly_name} #{to_reference(from)}"
  end

  # The GFM reference to this Mentionable, which shouldn't be included in its #references.
  def local_reference
    self
  end

  def all_references(current_user = nil, extractor: nil)
    # Use custom extractor if it's passed in the function parameters.
    if extractor
      extractors[current_user] = extractor
    else
      extractor = extractors[current_user] ||= Gitlab::ReferenceExtractor.new(project, current_user)

      extractor.reset_memoized_values
    end

    self.class.mentionable_attrs.each do |attr, options|
      text    = __send__(attr) # rubocop:disable GitlabSecurity/PublicSend
      options = options.merge(
        cache_key: [self, attr],
        author: author,
        skip_project_check: skip_project_check?
      ).merge(mentionable_params)

      cached_html = self.try(:updated_cached_html_for, attr.to_sym)
      options[:rendered] = cached_html if cached_html

      extractor.analyze(text, options)
    end

    extractor
  end

  def extractors
    @extractors ||= {}
  end

  def mentioned_users(current_user = nil)
    all_references(current_user).users
  end

  def store_mentions!
    # if store_mentioned_users_to_db feature flag is not enabled then consider storing operation as succeeded
    # because we wrap this method in transaction with with_transaction_returning_status, and we need the status to be
    # successful if mentionable.save is successful.
    #
    # This line will get removed when we remove the feature flag.
    return true unless store_mentioned_users_to_db_enabled?

    refs = all_references(self.author)

    references = {}
    references[:mentioned_users_ids] = refs.mentioned_users&.pluck(:id).presence
    references[:mentioned_groups_ids] = refs.mentioned_groups&.pluck(:id).presence
    references[:mentioned_projects_ids] = refs.mentioned_projects&.pluck(:id).presence

    # One retry should be enough as next time `model_user_mention` should return the existing mention record, that
    # threw the `ActiveRecord::RecordNotUnique` exception in first place.
    self.class.safe_ensure_unique(retries: 1) do
      user_mention = model_user_mention

      # this may happen due to notes polymorphism, so noteable_id may point to a record that no longer exists
      # as we cannot have FK on noteable_id
      break if user_mention.blank?

      user_mention.mentioned_users_ids = references[:mentioned_users_ids]
      user_mention.mentioned_groups_ids = references[:mentioned_groups_ids]
      user_mention.mentioned_projects_ids = references[:mentioned_projects_ids]

      if user_mention.has_mentions?
        user_mention.save!
      else
        user_mention.destroy!
      end
    end

    true
  end

  def referenced_users
    User.where(id: user_mentions.select("unnest(mentioned_users_ids)"))
  end

  def referenced_projects(current_user = nil)
    Project.where(id: user_mentions.select("unnest(mentioned_projects_ids)")).public_or_visible_to_user(current_user)
  end

  def referenced_project_users(current_user = nil)
    User.joins(:project_members).where(members: { source_id: referenced_projects(current_user) }).distinct
  end

  def referenced_groups(current_user = nil)
    # TODO: IMPORTANT: Revisit before using it.
    # Check DB data for max mentioned groups per mentionable:
    #
    # select issue_id, count(mentions_count.men_gr_id) gr_count from
    # (select DISTINCT unnest(mentioned_groups_ids) as men_gr_id, issue_id
    # from issue_user_mentions group by issue_id, mentioned_groups_ids) as mentions_count
    # group by mentions_count.issue_id order by gr_count desc limit 10
    Group.where(id: user_mentions.select("unnest(mentioned_groups_ids)")).public_or_visible_to_user(current_user)
  end

  def referenced_group_users(current_user = nil)
    User.joins(:group_members).where(members: { source_id: referenced_groups }).distinct
  end

  def directly_addressed_users(current_user = nil)
    all_references(current_user).directly_addressed_users
  end

  # Extract GFM references to other Mentionables from this Mentionable. Always excludes its #local_reference.
  def referenced_mentionables(current_user = self.author)
    return [] unless matches_cross_reference_regex?

    refs = all_references(current_user)

    # We're using this method instead of Array diffing because that requires
    # both of the object's `hash` values to be the same, which may not be the
    # case for otherwise identical Commit objects.
    extracted_mentionables(refs).reject { |ref| ref == local_reference }
  end

  # Uses regex to quickly determine if mentionables might be referenced
  # Allows heavy processing to be skipped
  def matches_cross_reference_regex?
    reference_pattern = if !project || project.default_issues_tracker?
                          ReferenceRegexes.default_pattern
                        else
                          ReferenceRegexes.external_pattern
                        end

    self.class.mentionable_attrs.any? do |attr, _|
      __send__(attr) =~ reference_pattern # rubocop:disable GitlabSecurity/PublicSend
    end
  end

  # Create a cross-reference Note for each GFM reference to another Mentionable found in the +mentionable_attrs+.
  def create_cross_references!(author = self.author, without = [])
    refs = referenced_mentionables(author)

    # We're using this method instead of Array diffing because that requires
    # both of the object's `hash` values to be the same, which may not be the
    # case for otherwise identical Commit objects.
    refs.reject! { |ref| without.include?(ref) || cross_reference_exists?(ref) }

    refs.each do |ref|
      SystemNoteService.cross_reference(ref, local_reference, author)
    end
  end

  # When a mentionable field is changed, creates cross-reference notes that
  # don't already exist
  def create_new_cross_references!(author = self.author)
    changes = detect_mentionable_changes

    return if changes.empty?

    create_cross_references!(author)
  end

  private

  def extracted_mentionables(refs)
    refs.issues + refs.merge_requests + refs.commits
  end

  # Returns a Hash of changed mentionable fields
  #
  # Preference is given to the `changes` Hash, but falls back to
  # `previous_changes` if it's empty (i.e., the changes have already been
  # persisted).
  #
  # See ActiveModel::Dirty.
  #
  # Returns a Hash.
  def detect_mentionable_changes
    source = (changes.presence || previous_changes).dup

    mentionable = self.class.mentionable_attrs.map { |attr, options| attr }

    # Only include changed fields that are mentionable
    source.select { |key, val| mentionable.include?(key) }
  end

  def any_mentionable_attributes_changed?
    self.class.mentionable_attrs.any? do |attr|
      saved_changes.key?(attr.first)
    end
  end

  # Determine whether or not a cross-reference Note has already been created between this Mentionable and
  # the specified target.
  def cross_reference_exists?(target)
    SystemNoteService.cross_reference_exists?(target, local_reference)
  end

  def skip_project_check?
    false
  end

  def mentionable_params
    {}
  end

  # User mention that is parsed from model description rather then its related notes.
  # Models that have a descriprion attribute like Issue, MergeRequest, Epic, Snippet may have such a user mention.
  # Other mentionable models like Commit, DesignManagement::Design, will never have such record as those do not have
  # a description attribute.
  #
  # Using this method followed by a call to *save* may result in *ActiveRecord::RecordNotUnique* exception
  # in a multithreaded environment. Make sure to use it within a *safe_ensure_unique* block.
  def model_user_mention
    user_mentions.where(note_id: nil).first_or_initialize
  end

  # We need this method to be checking that store_mentioned_users_to_db feature flag is enabled at the group level
  # and not the project level as epics are defined at group level and we want to have epics store user mentions as well
  # for the test period.
  # During the test period the flag should be enabled at the group level.
  def store_mentioned_users_to_db_enabled?
    return Feature.enabled?(:store_mentioned_users_to_db, self.project&.group) if self.respond_to?(:project)
    return Feature.enabled?(:store_mentioned_users_to_db, self.group) if self.respond_to?(:group)
  end
end

Mentionable.prepend_if_ee('EE::Mentionable')

# frozen_string_literal: true

class GroupGroupLink < ApplicationRecord
  include Expirable

  belongs_to :shared_group, class_name: 'Group', foreign_key: :shared_group_id
  belongs_to :shared_with_group, class_name: 'Group', foreign_key: :shared_with_group_id

  validates :shared_group, presence: true
  validates :shared_group_id, uniqueness: { scope: [:shared_with_group_id],
                                            message: _('The group has already been shared with this group') }
  validates :shared_with_group, presence: true
  validates :group_access, inclusion: { in: Gitlab::Access.all_values },
                           presence: true

  scope :non_guests, -> { where('group_access > ?', Gitlab::Access::GUEST) }
  scope :preload_shared_with_groups, -> { preload(:shared_with_group) }

  scope :distinct_on_shared_with_group_id_with_group_access, -> do
    distinct_group_links = select('DISTINCT ON (shared_with_group_id) *')
    .order('shared_with_group_id, group_access DESC, expires_at DESC, created_at ASC')

    unscoped.from(distinct_group_links, :group_group_links)
  end

  alias_method :shared_from, :shared_group

  def self.search(query)
    joins(:shared_with_group).merge(Group.search(query))
  end

  def self.access_options
    Gitlab::Access.options_with_owner
  end

  def self.default_access
    Gitlab::Access::DEVELOPER
  end

  def human_access
    Gitlab::Access.human_access(self.group_access)
  end
end

GroupGroupLink.prepend_mod_with('GroupGroupLink')

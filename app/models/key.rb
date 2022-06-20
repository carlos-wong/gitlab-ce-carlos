# frozen_string_literal: true

require 'digest/md5'

class Key < ApplicationRecord
  include AfterCommitQueue
  include Sortable
  include Sha256Attribute
  include Expirable
  include FromUnion

  sha256_attribute :fingerprint_sha256

  belongs_to :user

  before_validation :generate_fingerprint

  validates :title,
    presence: true,
    length: { maximum: 255 }

  validates :key,
    presence: true,
    length: { maximum: 5000 },
    format: { with: /\A(#{Gitlab::SSHPublicKey.supported_algorithms.join('|')})/ }

  validates :fingerprint,
    uniqueness: true,
    presence: { message: 'cannot be generated' },
    unless: -> { Gitlab::FIPS.enabled? }

  validates :fingerprint_sha256,
    uniqueness: true,
    presence: { message: 'cannot be generated' },
    if: -> { Gitlab::FIPS.enabled? }

  validate :key_meets_restrictions

  delegate :name, :email, to: :user, prefix: true

  after_commit :add_to_authorized_keys, on: :create
  after_create :post_create_hook
  after_create :refresh_user_cache
  after_commit :remove_from_authorized_keys, on: :destroy
  after_destroy :post_destroy_hook
  after_destroy :refresh_user_cache

  alias_attribute :fingerprint_md5, :fingerprint

  scope :preload_users, -> { preload(:user) }
  scope :for_user, -> (user) { where(user: user) }
  scope :order_last_used_at_desc, -> { reorder(arel_table[:last_used_at].desc.nulls_last) }

  # Date is set specifically in this scope to improve query time.
  scope :expired_today_and_not_notified, -> { where(["date(expires_at AT TIME ZONE 'UTC') = CURRENT_DATE AND expiry_notification_delivered_at IS NULL"]) }
  scope :expiring_soon_and_not_notified, -> { where(["date(expires_at AT TIME ZONE 'UTC') > CURRENT_DATE AND date(expires_at AT TIME ZONE 'UTC') < ? AND before_expiry_notification_delivered_at IS NULL", DAYS_TO_EXPIRE.days.from_now.to_date]) }

  def self.regular_keys
    where(type: ['Key', nil])
  end

  def key=(value)
    write_attribute(:key, value.present? ? Gitlab::SSHPublicKey.sanitize(value) : nil)

    @public_key = nil
  end

  def publishable_key
    # Strip out the keys comment so we don't leak email addresses
    # Replace with simple ident of user_name (hostname)
    self.key.split[0..1].push("#{self.user_name} (#{Gitlab.config.gitlab.host})").join(' ')
  end

  # projects that has this key
  def projects
    user.authorized_projects
  end

  def shell_id
    "key-#{id}"
  end

  # EE overrides this
  def can_delete?
    true
  end

  # rubocop: disable CodeReuse/ServiceClass
  def update_last_used_at
    Keys::LastUsedService.new(self).execute
  end
  # rubocop: enable CodeReuse/ServiceClass

  def add_to_authorized_keys
    return unless Gitlab::CurrentSettings.authorized_keys_enabled?

    AuthorizedKeysWorker.perform_async(:add_key, shell_id, key)
  end

  # rubocop: disable CodeReuse/ServiceClass
  def post_create_hook
    SystemHooksService.new.execute_hooks_for(self, :create)
  end
  # rubocop: enable CodeReuse/ServiceClass

  def remove_from_authorized_keys
    return unless Gitlab::CurrentSettings.authorized_keys_enabled?

    AuthorizedKeysWorker.perform_async(:remove_key, shell_id)
  end

  # rubocop: disable CodeReuse/ServiceClass
  def refresh_user_cache
    return unless user

    Users::KeysCountService.new(user).refresh_cache
  end
  # rubocop: enable CodeReuse/ServiceClass

  # rubocop: disable CodeReuse/ServiceClass
  def post_destroy_hook
    SystemHooksService.new.execute_hooks_for(self, :destroy)
  end
  # rubocop: enable CodeReuse/ServiceClass

  def public_key
    @public_key ||= Gitlab::SSHPublicKey.new(key)
  end

  private

  def generate_fingerprint
    self.fingerprint = nil
    self.fingerprint_sha256 = nil

    return unless public_key.valid?

    self.fingerprint_md5 = public_key.fingerprint unless Gitlab::FIPS.enabled?
    self.fingerprint_sha256 = public_key.fingerprint_sha256.gsub("SHA256:", "")
  end

  def key_meets_restrictions
    restriction = Gitlab::CurrentSettings.key_restriction_for(public_key.type)

    if restriction == ApplicationSetting::FORBIDDEN_KEY_VALUE
      errors.add(:key, forbidden_key_type_message)
    elsif public_key.bits < restriction
      errors.add(:key, "must be at least #{restriction} bits")
    end
  end

  def forbidden_key_type_message
    allowed_types = Gitlab::CurrentSettings.allowed_key_types.map(&:upcase)

    "type is forbidden. Must be #{Gitlab::Utils.to_exclusive_sentence(allowed_types)}"
  end
end

Key.prepend_mod_with('Key')

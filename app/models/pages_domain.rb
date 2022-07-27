# frozen_string_literal: true

class PagesDomain < ApplicationRecord
  include Presentable
  include FromUnion
  include AfterCommitQueue

  VERIFICATION_KEY = 'gitlab-pages-verification-code'
  VERIFICATION_THRESHOLD = 3.days.freeze
  SSL_RENEWAL_THRESHOLD = 30.days.freeze

  enum certificate_source: { user_provided: 0, gitlab_provided: 1 }, _prefix: :certificate
  enum scope: { instance: 0, group: 1, project: 2 }, _prefix: :scope
  enum usage: { pages: 0, serverless: 1 }, _prefix: :usage

  belongs_to :project
  has_many :acme_orders, class_name: "PagesDomainAcmeOrder"
  has_many :serverless_domain_clusters, class_name: 'Serverless::DomainCluster', inverse_of: :pages_domain

  before_validation :clear_auto_ssl_failure, unless: :auto_ssl_enabled

  validates :domain, hostname: { allow_numeric_hostname: true }
  validates :domain, uniqueness: { case_sensitive: false }
  validates :certificate, :key, presence: true, if: :usage_serverless?
  validates :certificate, presence: { message: 'must be present if HTTPS-only is enabled' },
            if: :certificate_should_be_present?
  validates :certificate, certificate: true, if: ->(domain) { domain.certificate.present? }
  validates :key, presence: { message: 'must be present if HTTPS-only is enabled' },
            if: :certificate_should_be_present?
  validates :key, certificate_key: true, named_ecdsa_key: true, if: ->(domain) { domain.key.present? }
  validates :verification_code, presence: true, allow_blank: false

  validate :validate_pages_domain
  validate :validate_matching_key, if: ->(domain) { domain.certificate.present? || domain.key.present? }
  validate :validate_intermediates, if: ->(domain) { domain.certificate.present? && domain.certificate_changed? }

  default_value_for(:auto_ssl_enabled, allows_nil: false) { ::Gitlab::LetsEncrypt.enabled? }
  default_value_for :scope, allows_nil: false, value: :project
  default_value_for :wildcard, allows_nil: false, value: false
  default_value_for :usage, allows_nil: false, value: :pages

  attr_encrypted :key,
    mode: :per_attribute_iv_and_salt,
    insecure_mode: true,
    key: Settings.attr_encrypted_db_key_base,
    algorithm: 'aes-256-cbc'

  after_initialize :set_verification_code

  scope :for_project, ->(project) { where(project: project) }

  scope :enabled, -> { where('enabled_until >= ?', Time.current ) }
  scope :needs_verification, -> do
    verified_at = arel_table[:verified_at]
    enabled_until = arel_table[:enabled_until]
    threshold = Time.current + VERIFICATION_THRESHOLD

    where(verified_at.eq(nil).or(enabled_until.eq(nil).or(enabled_until.lt(threshold))))
  end

  scope :need_auto_ssl_renewal, -> do
    enabled_and_not_failed = where(auto_ssl_enabled: true, auto_ssl_failed: false)

    user_provided = enabled_and_not_failed.certificate_user_provided
    certificate_not_valid = enabled_and_not_failed.where(certificate_valid_not_after: nil)
    certificate_expiring = enabled_and_not_failed
                             .where(arel_table[:certificate_valid_not_after].lt(SSL_RENEWAL_THRESHOLD.from_now))

    from_union([user_provided, certificate_not_valid, certificate_expiring])
  end

  scope :for_removal, -> { where("remove_at < ?", Time.current) }

  scope :with_logging_info, -> { includes(project: [:namespace, :route]) }

  scope :instance_serverless, -> { where(wildcard: true, scope: :instance, usage: :serverless) }

  def self.find_by_domain_case_insensitive(domain)
    find_by("LOWER(domain) = LOWER(?)", domain)
  end

  def verified?
    !!verified_at
  end

  def unverified?
    !verified?
  end

  def enabled?
    !Gitlab::CurrentSettings.pages_domain_verification_enabled? || enabled_until.present?
  end

  def https?
    certificate.present?
  end

  def to_param
    domain
  end

  def url
    return unless domain

    if certificate.present?
      "https://#{domain}"
    else
      "http://#{domain}"
    end
  end

  def has_matching_key?
    return false unless x509
    return false unless pkey

    # We compare the public key stored in certificate with public key from certificate key
    x509.check_private_key(pkey)
  end

  def has_intermediates?
    return false unless x509

    # self-signed certificates doesn't have the certificate chain
    return true if x509.verify(x509.public_key)

    store = OpenSSL::X509::Store.new
    store.set_default_paths

    store.verify(x509, untrusted_ca_certs_bundle)
  rescue OpenSSL::X509::StoreError
    false
  end

  def untrusted_ca_certs_bundle
    ::Gitlab::X509::Certificate.load_ca_certs_bundle(certificate)
  end

  def expired?
    return false unless x509

    current = Time.current
    current < x509.not_before || x509.not_after < current
  end

  def expiration
    x509&.not_after
  end

  def subject
    return unless x509

    x509.subject.to_s
  end

  def certificate_text
    @certificate_text ||= x509.try(:to_text)
  end

  # Verification codes may be TXT records for domain or verification_domain, to
  # support the use of CNAME records on domain.
  def verification_domain
    return unless domain.present?

    "_#{VERIFICATION_KEY}.#{domain}"
  end

  def keyed_verification_code
    return unless verification_code.present?

    "#{VERIFICATION_KEY}=#{verification_code}"
  end

  def certificate=(certificate)
    super(certificate)

    # set nil, if certificate is nil
    self.certificate_valid_not_before = x509&.not_before
    self.certificate_valid_not_after = x509&.not_after
  end

  def user_provided_key
    key if certificate_user_provided?
  end

  def user_provided_key=(key)
    self.key = key
    self.certificate_source = 'user_provided' if attribute_changed?(:key)
  end

  def user_provided_certificate
    certificate if certificate_user_provided?
  end

  def user_provided_certificate=(certificate)
    self.certificate = certificate
    self.certificate_source = 'user_provided' if certificate_changed?
  end

  def gitlab_provided_certificate=(certificate)
    self.certificate = certificate
    self.certificate_source = 'gitlab_provided' if certificate_changed?
  end

  def gitlab_provided_key=(key)
    self.key = key
    self.certificate_source = 'gitlab_provided' if attribute_changed?(:key)
  end

  def pages_virtual_domain
    return unless pages_deployed?

    cache = if Feature.enabled?(:cache_pages_domain_api, project.root_namespace)
              ::Gitlab::Pages::CacheControl.for_project(project.id)
            end

    Pages::VirtualDomain.new(
      projects: [project],
      domain: self,
      cache: cache
    )
  end

  def clear_auto_ssl_failure
    self.auto_ssl_failed = false
  end

  private

  def pages_deployed?
    return false unless project

    project.pages_metadatum&.deployed?
  end

  def set_verification_code
    return if self.verification_code.present?

    self.verification_code = SecureRandom.hex(16)
  end

  def validate_matching_key
    unless has_matching_key?
      self.errors.add(:key, "doesn't match the certificate")
    end
  end

  def validate_intermediates
    unless has_intermediates?
      self.errors.add(:certificate, 'misses intermediates')
    end
  end

  def validate_pages_domain
    return unless domain

    if domain.downcase.ends_with?(".#{Settings.pages.host.downcase}")
      error_template = _("Subdomains of the Pages root domain %{root_domain} are reserved and cannot be used as custom Pages domains.")
      self.errors.add(:domain, error_template % { root_domain: Settings.pages.host })
    end
  end

  def x509
    return unless certificate.present?

    @x509 ||= OpenSSL::X509::Certificate.new(certificate)
  rescue OpenSSL::X509::CertificateError
    nil
  end

  def pkey
    return unless key

    @pkey ||= OpenSSL::PKey.read(key)
  rescue OpenSSL::PKey::PKeyError, OpenSSL::Cipher::CipherError
    nil
  end

  def certificate_should_be_present?
    !auto_ssl_enabled? && project&.pages_https_only?
  end
end

PagesDomain.prepend_mod_with('PagesDomain')

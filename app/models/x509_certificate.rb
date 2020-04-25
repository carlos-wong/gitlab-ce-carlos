# frozen_string_literal: true

class X509Certificate < ApplicationRecord
  include X509SerialNumberAttribute

  x509_serial_number_attribute :serial_number

  enum certificate_status: {
    good: 0,
    revoked: 1
  }

  belongs_to :x509_issuer, class_name: 'X509Issuer', foreign_key: 'x509_issuer_id', optional: false

  has_many :x509_commit_signatures, inverse_of: 'x509_certificate'

  # rfc 5280 - 4.2.1.2  Subject Key Identifier
  validates :subject_key_identifier, presence: true, format: { with: /\A(\h{2}:){19}\h{2}\z/ }
  # rfc 5280 - 4.1.2.6  Subject
  validates :subject, presence: true
  # rfc 5280 - 4.1.2.6  Subject (subjectAltName contains the email address)
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # rfc 5280 - 4.1.2.2  Serial number
  validates :serial_number, presence: true, numericality: { only_integer: true }

  validates :x509_issuer_id, presence: true

  def self.safe_create!(attributes)
    create_with(attributes)
      .safe_find_or_create_by!(subject_key_identifier: attributes[:subject_key_identifier])
  end
end

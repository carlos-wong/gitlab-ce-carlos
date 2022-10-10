# frozen_string_literal: true

class WebHookLog < ApplicationRecord
  include SafeUrl
  include Presentable
  include DeleteWithLimit
  include CreatedAtFilterable
  include PartitionedTable

  OVERSIZE_REQUEST_DATA = { 'oversize' => true }.freeze

  self.primary_key = :id

  partitioned_by :created_at, strategy: :monthly, retain_for: 3.months

  belongs_to :web_hook

  serialize :request_headers, Hash # rubocop:disable Cop/ActiveRecordSerialize
  serialize :request_data, Hash # rubocop:disable Cop/ActiveRecordSerialize
  serialize :response_headers, Hash # rubocop:disable Cop/ActiveRecordSerialize

  validates :web_hook, presence: true

  before_save :obfuscate_basic_auth
  before_save :redact_user_emails

  def self.recent
    where('created_at >= ?', 2.days.ago.beginning_of_day)
      .order(created_at: :desc)
  end

  # Delete a batch of log records. Returns true if there may be more remaining.
  def self.delete_batch_for(web_hook, batch_size:)
    raise ArgumentError, 'batch_size is too small' if batch_size < 1

    where(web_hook: web_hook).limit(batch_size).delete_all == batch_size
  end

  def success?
    response_status =~ /^2/
  end

  def internal_error?
    response_status == WebHookService::InternalErrorResponse::ERROR_MESSAGE
  end

  def oversize?
    request_data == OVERSIZE_REQUEST_DATA
  end

  private

  def obfuscate_basic_auth
    self.url = safe_url
  end

  def redact_user_emails
    self.request_data.deep_transform_values! do |value|
      value =~ URI::MailTo::EMAIL_REGEXP ? _('[REDACTED]') : value
    end
  end
end

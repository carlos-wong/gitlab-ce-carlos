# frozen_string_literal: true
class KeysFinder
  InvalidFingerprint = Class.new(StandardError)
  GitLabAccessDeniedError = Class.new(StandardError)

  FINGERPRINT_ATTRIBUTES = {
    'sha256' => 'fingerprint_sha256',
    'md5' => 'fingerprint'
  }.freeze

  def initialize(params)
    @params = params
  end

  def execute
    keys = by_key_type
    keys = by_users(keys)
    keys = sort(keys)

    by_fingerprint(keys)
  end

  private

  attr_reader :params

  def by_key_type
    if params[:key_type] == 'ssh'
      Key.regular_keys
    else
      Key.all
    end
  end

  def sort(keys)
    keys.order_last_used_at_desc
  end

  def by_users(keys)
    return keys unless params[:users]

    keys.for_user(params[:users])
  end

  def by_fingerprint(keys)
    return keys unless params[:fingerprint].present?
    raise InvalidFingerprint unless valid_fingerprint_param?

    keys.where(fingerprint_query).first # rubocop: disable CodeReuse/ActiveRecord
  end

  def valid_fingerprint_param?
    if fingerprint_type == "sha256"
      Base64.decode64(fingerprint).length == 32
    else
      fingerprint =~ /^(\h{2}:){15}\h{2}/
    end
  end

  def fingerprint_query
    fingerprint_attribute = FINGERPRINT_ATTRIBUTES[fingerprint_type]

    Key.arel_table[fingerprint_attribute].eq(fingerprint)
  end

  def fingerprint_type
    if params[:fingerprint].start_with?(/sha256:|SHA256:/)
      "sha256"
    else
      "md5"
    end
  end

  def fingerprint
    if fingerprint_type == "sha256"
      params[:fingerprint].gsub(/sha256:|SHA256:/, "")
    else
      params[:fingerprint]
    end
  end
end

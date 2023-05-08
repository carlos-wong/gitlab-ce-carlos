# frozen_string_literal: true

module Gitlab
  class UrlSanitizer
    include Gitlab::Utils::StrongMemoize

    ALLOWED_SCHEMES = %w[http https ssh git].freeze
    ALLOWED_WEB_SCHEMES = %w[http https].freeze
    SCHEMIFIED_SCHEME = 'glschemelessuri'
    SCHEMIFY_PLACEHOLDER = "#{SCHEMIFIED_SCHEME}://".freeze
    # URI::DEFAULT_PARSER.make_regexp will only match URLs with schemes or
    # relative URLs. This section will match schemeless URIs with userinfo
    # e.g. user:pass@gitlab.com but will not match scp-style URIs e.g.
    # user@server:path/to/file)
    #
    # The userinfo part is very loose compared to URI's implementation so we
    # also match non-escaped userinfo e.g foo:b?r@gitlab.com which should be
    # encoded as foo:b%3Fr@gitlab.com
    URI_REGEXP = %r{
    (?:
       #{URI::DEFAULT_PARSER.make_regexp(ALLOWED_SCHEMES)}
     |
       (?:(?:(?!@)[%#{URI::REGEXP::PATTERN::UNRESERVED}#{URI::REGEXP::PATTERN::RESERVED}])+(?:@))
       (?# negative lookahead ensures this isn't an SCP-style URL: [host]:[rel_path|abs_path] server:path/to/file)
       (?!#{URI::REGEXP::PATTERN::HOST}:(?:#{URI::REGEXP::PATTERN::REL_PATH}|#{URI::REGEXP::PATTERN::ABS_PATH}))
       #{URI::REGEXP::PATTERN::HOSTPORT}
    )
    }x

    def self.sanitize(content)
      content.gsub(URI_REGEXP) do |url|
        new(url).masked_url
      rescue Addressable::URI::InvalidURIError
        ''
      end
    end

    def self.valid?(url, allowed_schemes: ALLOWED_SCHEMES)
      return false unless url.present?
      return false unless url.is_a?(String)

      uri = Addressable::URI.parse(url.strip)

      allowed_schemes.include?(uri.scheme)
    rescue Addressable::URI::InvalidURIError
      false
    end

    def self.valid_web?(url)
      valid?(url, allowed_schemes: ALLOWED_WEB_SCHEMES)
    end

    def initialize(url, credentials: nil)
      %i[user password].each do |symbol|
        credentials[symbol] = credentials[symbol].presence if credentials&.key?(symbol)
      end

      @credentials = credentials
      @url = parse_url(url)
    end

    def credentials
      @credentials ||= { user: @url.user.presence, password: @url.password.presence }
    end

    def user
      credentials[:user]
    end

    def sanitized_url
      safe_url = @url.dup
      safe_url.password = nil
      safe_url.user = nil
      reverse_schemify(safe_url.to_s)
    end
    strong_memoize_attr :sanitized_url

    def masked_url
      url = @url.dup
      url.password = "*****" if url.password.present?
      url.user = "*****" if url.user.present?
      reverse_schemify(url.to_s)
    end
    strong_memoize_attr :masked_url

    def full_url
      return reverse_schemify(@url.to_s) unless valid_credentials?

      url = @url.dup
      url.password = encode_percent(credentials[:password]) if credentials[:password].present?
      url.user = encode_percent(credentials[:user]) if credentials[:user].present?
      reverse_schemify(url.to_s)
    end
    strong_memoize_attr :full_url

    private

    def parse_url(url)
      url = schemify(url.to_s.strip)
      match = url.match(%r{\A(?:(?:#{SCHEMIFIED_SCHEME}|git|ssh|http(?:s?)):)?//(?:(.+)(?:@))?(.+)}o)
      raw_credentials = match[1] if match

      if raw_credentials.present?
        url.sub!("#{raw_credentials}@", '')

        user, _, password = raw_credentials.partition(':')

        @credentials ||= {}
        @credentials[:user] = user.presence if @credentials[:user].blank?
        @credentials[:password] = password.presence if @credentials[:password].blank?
      end

      url = Addressable::URI.parse(url)
      url.password = password if password.present?
      url.user = user if user.present?
      url
    end

    def schemify(url)
      # Prepend the placeholder scheme unless the URL has a scheme or is relative
      url.prepend(SCHEMIFY_PLACEHOLDER) unless url.starts_with?(%r{(?:#{URI::REGEXP::PATTERN::SCHEME}:)?//}o)
      url
    end

    def reverse_schemify(url)
      url.slice!(SCHEMIFY_PLACEHOLDER) if url.starts_with?(SCHEMIFY_PLACEHOLDER)
      url
    end

    def valid_credentials?
      credentials.is_a?(Hash) && credentials.values.any?
    end

    def encode_percent(string)
      # CGI.escape converts spaces to +, but this doesn't work for git clone
      CGI.escape(string).gsub('+', '%20')
    end
  end
end

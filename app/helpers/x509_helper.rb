# frozen_string_literal: true

require 'net/ldap/dn'

module X509Helper
  def x509_subject(subject, search_keys)
    subjects = {}

    Net::LDAP::DN.new(subject).each_pair do |key, value|
      if key.upcase.start_with?(*search_keys.map(&:upcase))
        subjects[key.upcase] = value
      end
    end

    subjects
  rescue
    {}
  end
end

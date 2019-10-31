# frozen_string_literal: true

FactoryBot.define do
  factory :identity do
    provider { 'ldapmain' }
    extern_uid { 'my-ldap-id' }
  end
end

# frozen_string_literal: true

class PagesDomainSslRenewalWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  feature_category :pages

  def perform(domain_id)
    domain = PagesDomain.find_by_id(domain_id)
    return unless domain&.enabled?
    return unless ::Gitlab::LetsEncrypt.enabled?

    ::PagesDomains::ObtainLetsEncryptCertificateService.new(domain).execute
  end
end

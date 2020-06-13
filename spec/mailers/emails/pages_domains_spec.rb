# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

describe Emails::PagesDomains do
  include EmailSpec::Matchers
  include_context 'gitlab email notification'

  let_it_be(:domain, reload: true) { create(:pages_domain, project: project) }
  let_it_be(:user) { project.creator }

  shared_examples 'a pages domain email' do
    let(:recipient) { user }

    it_behaves_like 'an email sent to a user'
    it_behaves_like 'an email sent from GitLab'
    it_behaves_like 'it should not have Gmail Actions links'
    it_behaves_like 'a user cannot unsubscribe through footer link'

    it 'has the expected content' do
      aggregate_failures do
        is_expected.to have_subject(email_subject)
        is_expected.to have_body_text(project.human_name)
        is_expected.to have_body_text(domain.domain)
        is_expected.to have_body_text domain.url
        is_expected.to have_body_text project_pages_domain_url(project, domain)
        is_expected.to have_body_text help_page_url('user/project/pages/custom_domains_ssl_tls_certification/index.md', anchor: link_anchor)
      end
    end
  end

  shared_examples 'notification about upcoming domain removal' do
    context 'when domain is not scheduled for removal' do
      it 'asks user to remove it' do
        is_expected.to have_body_text 'please remove it'
      end
    end

    context 'when domain is scheduled for removal' do
      before do
        domain.update!(remove_at: 1.week.from_now)
      end
      it 'notifies user that domain will be removed automatically' do
        aggregate_failures do
          is_expected.to have_body_text domain.remove_at.strftime('%F %T')
          is_expected.to have_body_text "it will be removed from your GitLab project"
        end
      end
    end
  end

  describe '#pages_domain_enabled_email' do
    let(:email_subject) { "#{project.path} | GitLab Pages domain '#{domain.domain}' has been enabled" }
    let(:link_anchor) { 'steps' }

    subject { Notify.pages_domain_enabled_email(domain, user) }

    it_behaves_like 'a pages domain email'

    it { is_expected.to have_body_text 'has been enabled' }
  end

  describe '#pages_domain_disabled_email' do
    let(:email_subject) { "#{project.path} | GitLab Pages domain '#{domain.domain}' has been disabled" }
    let(:link_anchor) { '4-verify-the-domains-ownership' }

    subject { Notify.pages_domain_disabled_email(domain, user) }

    it_behaves_like 'a pages domain email'

    it_behaves_like 'notification about upcoming domain removal'

    it { is_expected.to have_body_text 'has been disabled' }
  end

  describe '#pages_domain_verification_succeeded_email' do
    let(:email_subject) { "#{project.path} | Verification succeeded for GitLab Pages domain '#{domain.domain}'" }
    let(:link_anchor) { 'steps' }

    subject { Notify.pages_domain_verification_succeeded_email(domain, user) }

    it_behaves_like 'a pages domain email'

    it { is_expected.to have_body_text 'successfully verified' }
  end

  describe '#pages_domain_verification_failed_email' do
    let(:email_subject) { "#{project.path} | ACTION REQUIRED: Verification failed for GitLab Pages domain '#{domain.domain}'" }
    let(:link_anchor) { 'steps' }

    subject { Notify.pages_domain_verification_failed_email(domain, user) }

    it_behaves_like 'a pages domain email'

    it_behaves_like 'notification about upcoming domain removal'

    it 'says verification has failed and when the domain is enabled until' do
      is_expected.to have_body_text 'Verification has failed'
      is_expected.to have_body_text domain.enabled_until.strftime('%F %T')
    end
  end
end

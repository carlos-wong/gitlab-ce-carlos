# frozen_string_literal: true
require 'spec_helper'

describe Gitlab::X509::Commit do
  describe '#signature' do
    let(:signature) { described_class.new(commit).signature }

    let(:user1_certificate_attributes) do
      {
        subject_key_identifier: X509Helpers::User1.certificate_subject_key_identifier,
        subject: X509Helpers::User1.certificate_subject,
        email: X509Helpers::User1.certificate_email,
        serial_number: X509Helpers::User1.certificate_serial
      }
    end

    let(:user1_issuer_attributes) do
      {
        subject_key_identifier: X509Helpers::User1.issuer_subject_key_identifier,
        subject: X509Helpers::User1.certificate_issuer,
        crl_url: X509Helpers::User1.certificate_crl
      }
    end

    shared_examples 'returns the cached signature on second call' do
      it 'returns the cached signature on second call' do
        x509_commit = described_class.new(commit)

        expect(x509_commit).to receive(:create_cached_signature).and_call_original
        signature

        # consecutive call
        expect(x509_commit).not_to receive(:create_cached_signature).and_call_original
        signature
      end
    end

    let!(:project) { create :project, :repository, path: X509Helpers::User1.path }
    let!(:commit_sha) { X509Helpers::User1.commit }

    context 'unsigned commit' do
      let!(:commit) { create :commit, project: project, sha: commit_sha }

      it 'returns nil' do
        expect(described_class.new(commit).signature).to be_nil
      end
    end

    context 'valid signature from known user' do
      let!(:commit) { create :commit, project: project, sha: commit_sha, created_at: Time.utc(2019, 1, 1, 20, 15, 0), committer_email: X509Helpers::User1.emails.first }

      let!(:user) { create(:user, email: X509Helpers::User1.emails.first) }

      before do
        allow(Gitlab::Git::Commit).to receive(:extract_signature_lazily)
            .with(Gitlab::Git::Repository, commit_sha)
            .and_return(
              [
                X509Helpers::User1.signed_commit_signature,
                X509Helpers::User1.signed_commit_base_data
              ]
            )
      end

      it 'returns an unverified signature' do
        expect(signature).to have_attributes(
          commit_sha: commit_sha,
          project: project,
          verification_status: 'unverified'
        )
        expect(signature.x509_certificate).to have_attributes(user1_certificate_attributes)
        expect(signature.x509_certificate.x509_issuer).to have_attributes(user1_issuer_attributes)
        expect(signature.persisted?).to be_truthy
      end
    end

    context 'verified signature from known user' do
      let!(:commit) { create :commit, project: project, sha: commit_sha, created_at: Time.utc(2019, 1, 1, 20, 15, 0), committer_email: X509Helpers::User1.emails.first }

      let!(:user) { create(:user, email: X509Helpers::User1.emails.first) }

      before do
        allow(Gitlab::Git::Commit).to receive(:extract_signature_lazily)
            .with(Gitlab::Git::Repository, commit_sha)
            .and_return(
              [
                X509Helpers::User1.signed_commit_signature,
                X509Helpers::User1.signed_commit_base_data
              ]
            )
      end

      context 'with trusted certificate store' do
        before do
          store = OpenSSL::X509::Store.new
          certificate = OpenSSL::X509::Certificate.new X509Helpers::User1.trust_cert
          store.add_cert(certificate)
          allow(OpenSSL::X509::Store).to receive(:new)
              .and_return(
                store
              )
        end

        it 'returns a verified signature' do
          expect(signature).to have_attributes(
            commit_sha: commit_sha,
            project: project,
            verification_status: 'verified'
          )
          expect(signature.x509_certificate).to have_attributes(user1_certificate_attributes)
          expect(signature.x509_certificate.x509_issuer).to have_attributes(user1_issuer_attributes)
          expect(signature.persisted?).to be_truthy
        end

        context 'revoked certificate' do
          let(:x509_issuer) { create(:x509_issuer, user1_issuer_attributes) }
          let!(:x509_certificate) { create(:x509_certificate, user1_certificate_attributes.merge(x509_issuer_id: x509_issuer.id, certificate_status: :revoked)) }

          it 'returns an unverified signature' do
            expect(signature).to have_attributes(
              commit_sha: commit_sha,
              project: project,
              verification_status: 'unverified'
            )
            expect(signature.x509_certificate).to have_attributes(user1_certificate_attributes)
            expect(signature.x509_certificate.x509_issuer).to have_attributes(user1_issuer_attributes)
            expect(signature.persisted?).to be_truthy
          end
        end
      end

      context 'without trusted certificate within store' do
        before do
          store = OpenSSL::X509::Store.new
          allow(OpenSSL::X509::Store).to receive(:new)
              .and_return(
                store
              )
        end

        it 'returns an unverified signature' do
          expect(signature).to have_attributes(
            commit_sha: commit_sha,
            project: project,
            verification_status: 'unverified'
          )
          expect(signature.x509_certificate).to have_attributes(user1_certificate_attributes)
          expect(signature.x509_certificate.x509_issuer).to have_attributes(user1_issuer_attributes)
          expect(signature.persisted?).to be_truthy
        end
      end
    end

    context 'unverified signature from unknown user' do
      let!(:commit) { create :commit, project: project, sha: commit_sha, created_at: Time.utc(2019, 1, 1, 20, 15, 0), committer_email: X509Helpers::User1.emails.first }

      before do
        allow(Gitlab::Git::Commit).to receive(:extract_signature_lazily)
            .with(Gitlab::Git::Repository, commit_sha)
            .and_return(
              [
                X509Helpers::User1.signed_commit_signature,
                X509Helpers::User1.signed_commit_base_data
              ]
            )
      end

      it 'returns an unverified signature' do
        expect(signature).to have_attributes(
          commit_sha: commit_sha,
          project: project,
          verification_status: 'unverified'
        )
        expect(signature.x509_certificate).to have_attributes(user1_certificate_attributes)
        expect(signature.x509_certificate.x509_issuer).to have_attributes(user1_issuer_attributes)
        expect(signature.persisted?).to be_truthy
      end
    end

    context 'invalid signature' do
      let!(:commit) { create :commit, project: project, sha: commit_sha, committer_email: X509Helpers::User1.emails.first }

      let!(:user) { create(:user, email: X509Helpers::User1.emails.first) }

      before do
        allow(Gitlab::Git::Commit).to receive(:extract_signature_lazily)
            .with(Gitlab::Git::Repository, commit_sha)
            .and_return(
              [
                # Corrupt the key
                X509Helpers::User1.signed_commit_signature.tr('A', 'B'),
                X509Helpers::User1.signed_commit_base_data
              ]
            )
      end

      it 'returns nil' do
        expect(described_class.new(commit).signature).to be_nil
      end
    end

    context 'invalid commit message' do
      let!(:commit) { create :commit, project: project, sha: commit_sha, committer_email: X509Helpers::User1.emails.first }

      let!(:user) { create(:user, email: X509Helpers::User1.emails.first) }

      before do
        allow(Gitlab::Git::Commit).to receive(:extract_signature_lazily)
            .with(Gitlab::Git::Repository, commit_sha)
            .and_return(
              [
                X509Helpers::User1.signed_commit_signature,
                # Corrupt the commit message
                'x'
              ]
            )
      end

      it 'returns nil' do
        expect(described_class.new(commit).signature).to be_nil
      end
    end

    context 'certificate_crl' do
      let!(:commit) { create :commit, project: project, sha: commit_sha, created_at: Time.utc(2019, 1, 1, 20, 15, 0), committer_email: X509Helpers::User1.emails.first }
      let(:signed_commit) { described_class.new(commit) }

      describe 'valid crlDistributionPoints' do
        before do
          allow(signed_commit).to receive(:get_certificate_extension).and_call_original

          allow(signed_commit).to receive(:get_certificate_extension)
            .with('crlDistributionPoints')
            .and_return("\nFull Name:\n  URI:http://ch.siemens.com/pki?ZZZZZZA2.crl\n  URI:ldap://cl.siemens.net/CN=ZZZZZZA2,L=PKI?certificateRevocationList\n  URI:ldap://cl.siemens.com/CN=ZZZZZZA2,o=Trustcenter?certificateRevocationList\n")
        end

        it 'returns an unverified signature' do
          expect(signed_commit.signature.x509_certificate.x509_issuer).to have_attributes(user1_issuer_attributes)
        end
      end

      describe 'valid crlDistributionPoints providing multiple http URIs' do
        before do
          allow(signed_commit).to receive(:get_certificate_extension).and_call_original

          allow(signed_commit).to receive(:get_certificate_extension)
            .with('crlDistributionPoints')
            .and_return("\nFull Name:\n  URI:http://cdp1.pca.dfn.de/dfn-ca-global-g2/pub/crl/cacrl.crl\n\nFull Name:\n  URI:http://cdp2.pca.dfn.de/dfn-ca-global-g2/pub/crl/cacrl.crl\n")
        end

        it 'extracts the first URI' do
          expect(signed_commit.signature.x509_certificate.x509_issuer.crl_url).to eq("http://cdp1.pca.dfn.de/dfn-ca-global-g2/pub/crl/cacrl.crl")
        end
      end
    end
  end
end

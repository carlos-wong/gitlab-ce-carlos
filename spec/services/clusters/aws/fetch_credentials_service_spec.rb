# frozen_string_literal: true

require 'spec_helper'

describe Clusters::Aws::FetchCredentialsService do
  describe '#execute' do
    let(:user) { create(:user) }
    let(:provider) { create(:cluster_provider_aws) }

    let(:gitlab_access_key_id) { 'gitlab-access-key-id' }
    let(:gitlab_secret_access_key) { 'gitlab-secret-access-key' }

    let(:region) { 'us-east-1' }
    let(:gitlab_credentials) { Aws::Credentials.new(gitlab_access_key_id, gitlab_secret_access_key) }
    let(:sts_client) { Aws::STS::Client.new(credentials: gitlab_credentials, region: region) }
    let(:assumed_role) { instance_double(Aws::AssumeRoleCredentials, credentials: assumed_role_credentials) }

    let(:assumed_role_credentials) { double }

    subject { described_class.new(provision_role, region: region, provider: provider).execute }

    context 'provision role is configured' do
      let(:provision_role) { create(:aws_role, user: user) }

      before do
        stub_application_setting(eks_access_key_id: gitlab_access_key_id)
        stub_application_setting(eks_secret_access_key: gitlab_secret_access_key)

        expect(Aws::Credentials).to receive(:new)
          .with(gitlab_access_key_id, gitlab_secret_access_key)
          .and_return(gitlab_credentials)

        expect(Aws::STS::Client).to receive(:new)
          .with(credentials: gitlab_credentials, region: region)
          .and_return(sts_client)

        expect(Aws::AssumeRoleCredentials).to receive(:new)
          .with(
            client: sts_client,
            role_arn: provision_role.role_arn,
            role_session_name: session_name,
            external_id: provision_role.role_external_id
          ).and_return(assumed_role)
      end

      context 'provider is specified' do
        let(:session_name) { "gitlab-eks-cluster-#{provider.cluster_id}-user-#{user.id}" }

        it { is_expected.to eq assumed_role_credentials }
      end

      context 'provider is not specifed' do
        let(:provider) { nil }
        let(:session_name) { "gitlab-eks-autofill-user-#{user.id}" }

        it { is_expected.to eq assumed_role_credentials }
      end
    end

    context 'provision role is not configured' do
      let(:provision_role) { nil }

      it 'raises an error' do
        expect { subject }.to raise_error(described_class::MissingRoleError, 'AWS provisioning role not configured')
      end
    end
  end
end

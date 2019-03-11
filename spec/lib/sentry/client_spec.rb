# frozen_string_literal: true

require 'spec_helper'

describe Sentry::Client do
  let(:sentry_url) { 'https://sentrytest.gitlab.com/api/0/projects/sentry-org/sentry-project' }
  let(:token) { 'test-token' }

  let(:issues_sample_response) do
    Gitlab::Utils.deep_indifferent_access(
      JSON.parse(fixture_file('sentry/issues_sample_response.json'))
    )
  end

  let(:projects_sample_response) do
    Gitlab::Utils.deep_indifferent_access(
      JSON.parse(fixture_file('sentry/list_projects_sample_response.json'))
    )
  end

  subject(:client) { described_class.new(sentry_url, token) }

  # Requires sentry_api_url and subject to be defined
  shared_examples 'no redirects' do
    let(:redirect_to) { 'https://redirected.example.com' }
    let(:other_url) { 'https://other.example.org' }

    let!(:redirected_req_stub) { stub_sentry_request(other_url) }

    let!(:redirect_req_stub) do
      stub_sentry_request(
        sentry_api_url,
        status: 302,
        headers: { location: redirect_to }
      )
    end

    it 'does not follow redirects' do
      expect { subject }.to raise_exception(Sentry::Client::Error, 'Sentry response status code: 302')
      expect(redirect_req_stub).to have_been_requested
      expect(redirected_req_stub).not_to have_been_requested
    end
  end

  shared_examples 'has correct return type' do |klass|
    it "returns objects of type #{klass}" do
      expect(subject).to all( be_a(klass) )
    end
  end

  shared_examples 'has correct length' do |length|
    it { expect(subject.length).to eq(length) }
  end

  # Requires sentry_api_request and subject to be defined
  shared_examples 'calls sentry api' do
    it 'calls sentry api' do
      subject

      expect(sentry_api_request).to have_been_requested
    end
  end

  describe '#list_issues' do
    let(:issue_status) { 'unresolved' }
    let(:limit) { 20 }

    let!(:sentry_api_request) { stub_sentry_request(sentry_url + '/issues/?limit=20&query=is:unresolved', body: issues_sample_response) }

    subject { client.list_issues(issue_status: issue_status, limit: limit) }

    it_behaves_like 'calls sentry api'

    it_behaves_like 'has correct return type', Gitlab::ErrorTracking::Error
    it_behaves_like 'has correct length', 1

    context 'error object created from sentry response' do
      using RSpec::Parameterized::TableSyntax

      where(:error_object, :sentry_response) do
        :id           | :id
        :first_seen   | :firstSeen
        :last_seen    | :lastSeen
        :title        | :title
        :type         | :type
        :user_count   | :userCount
        :count        | :count
        :message      | [:metadata, :value]
        :culprit      | :culprit
        :short_id     | :shortId
        :status       | :status
        :frequency    | [:stats, '24h']
        :project_id   | [:project, :id]
        :project_name | [:project, :name]
        :project_slug | [:project, :slug]
      end

      with_them do
        it { expect(subject[0].public_send(error_object)).to eq(issues_sample_response[0].dig(*sentry_response)) }
      end

      context 'external_url' do
        it 'is constructed correctly' do
          expect(subject[0].external_url).to eq('https://sentrytest.gitlab.com/sentry-org/sentry-project/issues/11')
        end
      end
    end

    context 'redirects' do
      let(:sentry_api_url) { sentry_url + '/issues/?limit=20&query=is:unresolved' }

      it_behaves_like 'no redirects'
    end

    # Sentry API returns 404 if there are extra slashes in the URL!
    context 'extra slashes in URL' do
      let(:sentry_url) { 'https://sentrytest.gitlab.com/api/0/projects//sentry-org/sentry-project/' }
      let(:client) { described_class.new(sentry_url, token) }

      let!(:valid_req_stub) do
        stub_sentry_request(
          'https://sentrytest.gitlab.com/api/0/projects/sentry-org/sentry-project/' \
          'issues/?limit=20&query=is:unresolved'
        )
      end

      it 'removes extra slashes in api url' do
        expect(Gitlab::HTTP).to receive(:get).with(
          URI('https://sentrytest.gitlab.com/api/0/projects/sentry-org/sentry-project/issues/'),
          anything
        ).and_call_original

        subject

        expect(valid_req_stub).to have_been_requested
      end
    end
  end

  describe '#list_projects' do
    let(:sentry_list_projects_url) { 'https://sentrytest.gitlab.com/api/0/projects/' }

    let!(:sentry_api_request) { stub_sentry_request(sentry_list_projects_url, body: projects_sample_response) }

    subject { client.list_projects }

    it_behaves_like 'calls sentry api'

    it_behaves_like 'has correct return type', Gitlab::ErrorTracking::Project
    it_behaves_like 'has correct length', 2

    context 'keys missing in API response' do
      it 'raises exception' do
        projects_sample_response[0].delete(:slug)

        stub_sentry_request(sentry_list_projects_url, body: projects_sample_response)

        expect { subject }.to raise_error(Sentry::Client::SentryError, 'Sentry API response is missing keys. key not found: "slug"')
      end
    end

    context 'error object created from sentry response' do
      using RSpec::Parameterized::TableSyntax

      where(:sentry_project_object, :sentry_response) do
        :id                | :id
        :name              | :name
        :status            | :status
        :slug              | :slug
        :organization_name | [:organization, :name]
        :organization_id   | [:organization, :id]
        :organization_slug | [:organization, :slug]
      end

      with_them do
        it { expect(subject[0].public_send(sentry_project_object)).to eq(projects_sample_response[0].dig(*sentry_response)) }
      end
    end

    context 'redirects' do
      let(:sentry_api_url) { sentry_list_projects_url }

      it_behaves_like 'no redirects'
    end

    # Sentry API returns 404 if there are extra slashes in the URL!
    context 'extra slashes in URL' do
      let(:sentry_url) { 'https://sentrytest.gitlab.com/api//0/projects//' }
      let(:client) { described_class.new(sentry_url, token) }

      let!(:valid_req_stub) do
        stub_sentry_request(sentry_list_projects_url)
      end

      it 'removes extra slashes in api url' do
        expect(Gitlab::HTTP).to receive(:get).with(
          URI(sentry_list_projects_url),
          anything
        ).and_call_original

        subject

        expect(valid_req_stub).to have_been_requested
      end
    end
  end

  private

  def stub_sentry_request(url, body: {}, status: 200, headers: {})
    WebMock.stub_request(:get, url)
      .to_return(
        status: status,
        headers: { 'Content-Type' => 'application/json' }.merge(headers),
        body: body.to_json
      )
  end
end

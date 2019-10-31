# frozen_string_literal: true

require 'spec_helper'

describe Projects::ContainerRepository::DeleteTagsService do
  set(:user) { create(:user) }
  set(:project) { create(:project, :private) }
  set(:repository) { create(:container_repository, :root, project: project) }

  let(:params) { { tags: tags } }
  let(:service) { described_class.new(project, user, params) }

  before do
    stub_container_registry_config(enabled: true,
                                   api_url: 'http://registry.gitlab',
                                   host_port: 'registry.gitlab')

    stub_container_registry_tags(
      repository: repository.path,
      tags: %w(latest A Ba Bb C D E))

    stub_tag_digest('latest', 'sha256:configA')
    stub_tag_digest('A', 'sha256:configA')
    stub_tag_digest('Ba', 'sha256:configB')
  end

  describe '#execute' do
    let(:tags) { %w[A] }
    subject { service.execute(repository) }

    context 'without permissions' do
      it { is_expected.to include(status: :error) }
    end

    context 'with permissions' do
      before do
        project.add_developer(user)
      end

      context 'when no params are specified' do
        let(:params) { {} }

        it 'does not remove anything' do
          expect_any_instance_of(ContainerRegistry::Client).not_to receive(:delete_repository_tag)

          is_expected.to include(status: :error)
        end
      end

      context 'with empty tags' do
        let(:tags) { [] }

        it 'does not remove anything' do
          expect_any_instance_of(ContainerRegistry::Client).not_to receive(:delete_repository_tag)

          is_expected.to include(status: :error)
        end
      end

      context 'with dummy tags disabled' do
        let(:tags) { %w[A Ba] }

        before do
          stub_feature_flags(container_registry_smart_delete: false)
        end

        it 'deletes tags one by one' do
          expect_delete_tag('sha256:configA')
          expect_delete_tag('sha256:configB')
          is_expected.to include(status: :success)
        end
      end

      context 'with dummy tags enabled' do
        let(:tags) { %w[A Ba] }

        it 'deletes the tags using a dummy image' do
          stub_upload("{\n  \"config\": {\n  }\n}", 'sha256:4435000728ee66e6a80e55637fc22725c256b61de344a2ecdeaac6bdb36e8bc3')

          stub_request(:put, "http://registry.gitlab/v2/#{repository.path}/manifests/A")
            .to_return(status: 200, body: "", headers: { 'docker-content-digest' => 'sha256:dummy' })

          stub_request(:put, "http://registry.gitlab/v2/#{repository.path}/manifests/Ba")
            .to_return(status: 200, body: "", headers: { 'docker-content-digest' => 'sha256:dummy' })

          expect_delete_tag('sha256:dummy')

          is_expected.to include(status: :success)
        end

        it 'succedes when tag delete returns 404' do
          stub_upload("{\n  \"config\": {\n  }\n}", 'sha256:4435000728ee66e6a80e55637fc22725c256b61de344a2ecdeaac6bdb36e8bc3')

          stub_request(:put, "http://registry.gitlab/v2/#{repository.path}/manifests/A")
            .to_return(status: 200, body: "", headers: { 'docker-content-digest' => 'sha256:dummy' })

          stub_request(:put, "http://registry.gitlab/v2/#{repository.path}/manifests/Ba")
            .to_return(status: 200, body: "", headers: { 'docker-content-digest' => 'sha256:dummy' })

          stub_request(:delete, "http://registry.gitlab/v2/#{repository.path}/manifests/sha256:dummy")
            .to_return(status: 404, body: "", headers: {})

          is_expected.to include(status: :success)
        end
      end
    end
  end

  private

  def stub_tag_digest(tag, digest)
    stub_request(:head, "http://registry.gitlab/v2/#{repository.path}/manifests/#{tag}")
      .to_return(status: 200, body: "", headers: { 'docker-content-digest' => digest })
  end

  def stub_digest_config(digest, created_at)
    allow_any_instance_of(ContainerRegistry::Client)
      .to receive(:blob)
      .with(repository.path, digest, nil) do
      { 'created' => created_at.to_datetime.rfc3339 }.to_json if created_at
    end
  end

  def stub_upload(content, digest)
    expect_any_instance_of(ContainerRegistry::Client)
      .to receive(:upload_blob)
      .with(repository.path, content, digest) { double(success?: true ) }
  end

  def expect_delete_tag(digest)
    expect_any_instance_of(ContainerRegistry::Client)
      .to receive(:delete_repository_tag)
      .with(repository.path, digest) { true }
  end
end

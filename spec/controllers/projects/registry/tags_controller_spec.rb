# frozen_string_literal: true

require 'spec_helper'

describe Projects::Registry::TagsController do
  let(:user)    { create(:user) }
  let(:project) { create(:project, :private) }

  let(:repository) do
    create(:container_repository, name: 'image', project: project)
  end

  let(:service) { double('service') }

  before do
    sign_in(user)
    stub_container_registry_config(enabled: true)
  end

  describe 'GET index' do
    let(:tags) do
      Array.new(40) { |i| "tag#{i}" }
    end

    before do
      stub_container_registry_tags(repository: /image/, tags: tags, with_manifest: true)
    end

    context 'when user can control the registry' do
      before do
        project.add_developer(user)
      end

      it 'receive a list of tags' do
        get_tags

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('registry/tags')
        expect(response).to include_pagination_headers
      end

      it 'tracks the event' do
        expect(Gitlab::Tracking).to receive(:event).with(anything, 'list_tags', {})

        get_tags
      end
    end

    context 'when user can read the registry' do
      before do
        project.add_reporter(user)
      end

      it 'receive a list of tags' do
        get_tags

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('registry/tags')
        expect(response).to include_pagination_headers
      end
    end

    context 'when user does not have access to registry' do
      before do
        project.add_guest(user)
      end

      it 'does not receive a list of tags' do
        get_tags

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    private

    def get_tags
      get :index, params: {
                    namespace_id: project.namespace,
                    project_id: project,
                    repository_id: repository
                  },
                  format: :json
    end
  end

  describe 'POST destroy' do
    context 'when user has access to registry' do
      before do
        project.add_developer(user)
      end

      context 'when there is matching tag present' do
        before do
          stub_container_registry_tags(repository: repository.path, tags: %w[rc1], with_manifest: true)
        end

        it 'makes it possible to delete regular tag' do
          expect_delete_tags(%w[rc1])

          destroy_tag('rc1')
        end

        it 'makes it possible to delete a tag that ends with a dot' do
          expect_delete_tags(%w[test.])

          destroy_tag('test.')
        end

        it 'tracks the event' do
          expect_delete_tags(%w[test.])
          expect(controller).to receive(:track_event).with(:delete_tag)

          destroy_tag('test.')
        end
      end
    end

    private

    def destroy_tag(name)
      post :destroy, params: {
                       namespace_id: project.namespace,
                       project_id: project,
                       repository_id: repository,
                       id: name
                     },
                     format: :json
    end
  end

  describe 'POST bulk_destroy' do
    context 'when user has access to registry' do
      before do
        project.add_developer(user)
      end

      context 'when there is matching tag present' do
        before do
          stub_container_registry_tags(repository: repository.path, tags: %w[rc1 test.])
        end

        let(:tags) { %w[tc1 test.] }

        it 'makes it possible to delete tags in bulk' do
          expect_delete_tags(tags)

          bulk_destroy_tags(tags)
        end

        it 'tracks the event' do
          expect_delete_tags(tags)
          expect(Gitlab::Tracking).to receive(:event).with(anything, 'delete_tag_bulk', {})

          bulk_destroy_tags(tags)
        end
      end
    end

    private

    def bulk_destroy_tags(names)
      post :bulk_destroy, params: {
                       namespace_id: project.namespace,
                       project_id: project,
                       repository_id: repository,
                       ids: names
                     },
                     format: :json
    end
  end

  def expect_delete_tags(tags, status = :success)
    expect(service).to receive(:execute).with(repository) { { status: status } }
    expect(Projects::ContainerRepository::DeleteTagsService).to receive(:new).with(repository.project, user, tags: tags) { service }
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe 'Container Registry', :js do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:project) { create(:project, namespace: group) }

  let(:container_repository) do
    create(:container_repository, name: 'my/image')
  end

  before do
    group.add_owner(user)
    sign_in(user)
    stub_container_registry_config(enabled: true)
    stub_container_registry_tags(repository: :any, tags: [])
  end

  it 'has a page title set' do
    visit_container_registry

    expect(page).to have_title _('Container Registry')
  end

  context 'when there are no image repositories' do
    it 'list page has no container title' do
      visit_container_registry

      expect(page).to have_content _('There are no container images available in this group')
    end
  end

  context 'when there are image repositories' do
    before do
      stub_container_registry_tags(repository: %r{my/image}, tags: %w[latest], with_manifest: true)
      project.container_repositories << container_repository
    end

    it 'list page has a list of images' do
      visit_container_registry

      expect(page).to have_content 'my/image'
    end

    it 'image repository delete is disabled' do
      visit_container_registry

      delete_btn = find('[title="Remove repository"]')
      expect(delete_btn).to be_disabled
    end

    it 'navigates to repo details' do
      visit_container_registry_details('my/image')

      expect(page).to have_content 'latest'
    end

    describe 'image repo details' do
      before do
        visit_container_registry_details 'my/image'
      end

      it 'shows the details breadcrumb' do
        expect(find('.breadcrumbs')).to have_link 'my/image'
      end

      it 'shows the image title' do
        expect(page).to have_content 'my/image tags'
      end

      it 'user removes a specific tag from container repository' do
        service = double('service')
        expect(service).to receive(:execute).with(container_repository) { { status: :success } }
        expect(Projects::ContainerRepository::DeleteTagsService).to receive(:new).with(container_repository.project, user, tags: ['latest']) { service }

        click_on(class: 'js-delete-registry')
        expect(find('.modal .modal-title')).to have_content _('Remove tag')
        find('.modal .modal-footer .btn-danger').click
      end
    end
  end

  def visit_container_registry
    visit group_container_registries_path(group)
  end

  def visit_container_registry_details(name)
    visit_container_registry
    click_link(name)
  end
end

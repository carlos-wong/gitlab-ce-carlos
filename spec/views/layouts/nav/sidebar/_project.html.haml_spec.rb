require 'spec_helper'

describe 'layouts/nav/sidebar/_project' do
  let(:project) { create(:project, :repository) }

  before do
    assign(:project, project)
    assign(:repository, project.repository)
    allow(view).to receive(:current_ref).and_return('master')

    allow(view).to receive(:can?).and_return(true)
  end

  it_behaves_like 'has nav sidebar'

  describe 'issue boards' do
    it 'has board tab' do
      render

      expect(rendered).to have_css('a[title="Boards"]')
    end
  end

  describe 'container registry tab' do
    before do
      stub_container_registry_config(enabled: true)

      allow(controller).to receive(:controller_name)
        .and_return('repositories')
      allow(controller).to receive(:controller_path)
        .and_return('projects/registry/repositories')
    end

    it 'has both Registry and Repository tabs' do
      render

      expect(rendered).to have_text 'Repository'
      expect(rendered).to have_text 'Registry'
    end

    it 'highlights sidebar item and flyout' do
      render

      expect(rendered).to have_css('.sidebar-top-level-items > li.active', count: 1)
      expect(rendered).to have_css('.is-fly-out-only > li.active', count: 1)
    end

    it 'highlights container registry tab' do
      render

      expect(rendered).to have_css('.sidebar-top-level-items > li.active', text: 'Registry')
    end
  end

  describe 'releases entry' do
    it 'renders releases link' do
      render

      expect(rendered).to have_link('Releases', href: project_releases_path(project))
    end
  end

  describe 'wiki entry tab' do
    let(:can_read_wiki) { true }

    before do
      allow(view).to receive(:can?).with(nil, :read_wiki, project).and_return(can_read_wiki)
    end

    describe 'when wiki is enabled' do
      it 'shows the wiki tab with the wiki internal link' do
        render

        expect(rendered).to have_link('Wiki', href: project_wiki_path(project, :home))
      end
    end

    describe 'when wiki is disabled' do
      let(:can_read_wiki) { false }

      it 'does not show the wiki tab' do
        render

        expect(rendered).not_to have_link('Wiki', href: project_wiki_path(project, :home))
      end
    end
  end

  describe 'external wiki entry tab' do
    let(:properties) { { 'external_wiki_url' => 'https://gitlab.com' } }
    let(:service_status) { true }

    before do
      project.create_external_wiki_service(active: service_status, properties: properties)
      project.reload
    end

    context 'when it is active' do
      it 'shows the external wiki tab with the external wiki service link' do
        render

        expect(rendered).to have_link('External Wiki', href: properties['external_wiki_url'])
      end
    end

    context 'when it is disabled' do
      let(:service_status) { false }

      it 'does not show the external wiki tab' do
        render

        expect(rendered).not_to have_link('External Wiki', href: project_wiki_path(project, :home))
      end
    end
  end

  describe 'ci/cd settings tab' do
    before do
      project.update!(archived: project_archived)
    end

    context 'when project is archived' do
      let(:project_archived) { true }

      it 'does not show the ci/cd settings tab' do
        render

        expect(rendered).not_to have_link('CI / CD', href: project_settings_ci_cd_path(project))
      end
    end

    context 'when project is active' do
      let(:project_archived) { false }

      it 'shows the ci/cd settings tab' do
        render

        expect(rendered).to have_link('CI / CD', href: project_settings_ci_cd_path(project))
      end
    end
  end

  describe 'operations settings tab' do
    before do
      project.update!(archived: project_archived)
    end

    context 'when project is archived' do
      let(:project_archived) { true }

      it 'does not show the operations settings tab' do
        render

        expect(rendered).not_to have_link('Operations', href: project_settings_operations_path(project))
      end
    end

    context 'when project is active' do
      let(:project_archived) { false }

      it 'shows the operations settings tab' do
        render

        expect(rendered).to have_link('Operations', href: project_settings_operations_path(project))
      end
    end
  end
end

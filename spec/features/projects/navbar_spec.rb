# frozen_string_literal: true

require 'spec_helper'

describe 'Project navbar' do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }

  let(:analytics_nav_item) do
    {
      nav_item: _('Analytics'),
      nav_sub_items: [
        _('CI / CD'),
        (_('Code Review') if Gitlab.ee?),
        _('Repository'),
        _('Value Stream')
      ]
    }
  end

  let(:requirements_nav_item) do
    {
      nav_item: _('Requirements'),
      nav_sub_items: [_('List')]
    }
  end

  let(:structure) do
    [
      {
        nav_item: _('Project overview'),
        nav_sub_items: [
          _('Details'),
          _('Activity'),
          _('Releases')
        ]
      },
      {
        nav_item: _('Repository'),
        nav_sub_items: [
          _('Files'),
          _('Commits'),
          _('Branches'),
          _('Tags'),
          _('Contributors'),
          _('Graph'),
          _('Compare'),
          (_('Locked Files') if Gitlab.ee?)
        ]
      },
      {
        nav_item: _('Issues'),
        nav_sub_items: [
          _('List'),
          _('Boards'),
          _('Labels'),
          _('Milestones')
        ]
      },
      {
        nav_item: _('Merge Requests'),
        nav_sub_items: []
      },
      (requirements_nav_item if Gitlab.ee?),
      {
        nav_item: _('CI / CD'),
        nav_sub_items: [
          _('Pipelines'),
          _('Jobs'),
          _('Artifacts'),
          _('Schedules')
        ]
      },
      {
        nav_item: _('Operations'),
        nav_sub_items: [
          _('Metrics'),
          _('Environments'),
          _('Error Tracking'),
          _('Serverless'),
          _('Logs'),
          _('Kubernetes')
        ]
      },
      analytics_nav_item,
      {
        nav_item: _('Wiki'),
        nav_sub_items: []
      },
      {
        nav_item: _('Snippets'),
        nav_sub_items: []
      },
      {
        nav_item: _('Settings'),
        nav_sub_items: [
          _('General'),
          _('Members'),
          _('Integrations'),
          _('Webhooks'),
          _('Repository'),
          _('CI / CD'),
          _('Operations'),
          (_('Audit Events') if Gitlab.ee?)
        ].compact
      }
    ]
  end

  before do
    stub_licensed_features(requirements: false)
    project.add_maintainer(user)
    sign_in(user)
  end

  it_behaves_like 'verified navigation bar' do
    before do
      visit project_path(project)
    end
  end

  if Gitlab.ee?
    context 'when issues analytics is available' do
      before do
        stub_licensed_features(issues_analytics: true)

        analytics_nav_item[:nav_sub_items] << _('Issues')
        analytics_nav_item[:nav_sub_items].sort!

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end

    context 'when requirements is available' do
      before do
        stub_licensed_features(requirements: true)

        visit project_path(project)
      end

      it_behaves_like 'verified navigation bar'
    end
  end
end

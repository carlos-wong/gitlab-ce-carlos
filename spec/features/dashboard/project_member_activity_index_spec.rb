# frozen_string_literal: true

require 'spec_helper'

describe 'Project member activity', :js do
  let(:user)            { create(:user) }
  let(:project)         { create(:project, :public, name: 'x', namespace: user.namespace) }

  before do
    project.add_maintainer(user)
  end

  def visit_activities_and_wait_with_event(event_type)
    Event.create(project: project, author_id: user.id, action: event_type)
    visit activity_project_path(project)
    wait_for_requests
  end

  context 'when a user joins the project' do
    before do
      visit_activities_and_wait_with_event(Event::JOINED)
    end

    it "presents the correct message" do
      expect(page.find('.event-user-info').text).to eq("#{user.name} #{user.to_reference}")
      expect(page.find('.event-title').text).to eq("joined project")
    end
  end

  context 'when a user leaves the project' do
    before do
      visit_activities_and_wait_with_event(Event::LEFT)
    end

    it "presents the correct message" do
      expect(page.find('.event-user-info').text).to eq("#{user.name} #{user.to_reference}")
      expect(page.find('.event-title').text).to eq("left project")
    end
  end

  context 'when a users membership expires for the project' do
    before do
      visit_activities_and_wait_with_event(Event::EXPIRED)
    end

    it "presents the correct message" do
      expect(page.find('.event-user-info').text).to eq("#{user.name} #{user.to_reference}")
      expect(page.find('.event-title').text).to eq("removed due to membership expiration from project")
    end
  end
end

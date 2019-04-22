# frozen_string_literal: true

require 'spec_helper'

describe MailScheduler::IssueDueWorker do
  describe '#perform' do
    let(:worker) { described_class.new }
    let(:project) { create(:project) }

    it 'sends emails for open issues due tomorrow in the project specified' do
      issue1 = create(:issue, :opened, project: project, due_date: Date.tomorrow)
      issue2 = create(:issue, :opened, project: project, due_date: Date.tomorrow)
      create(:issue, :closed, project: project, due_date: Date.tomorrow) # closed
      create(:issue, :opened, project: project, due_date: 2.days.from_now) # due on another day
      create(:issue, :opened, due_date: Date.tomorrow) # different project

      expect(worker.notification_service).to receive(:issue_due).with(issue1)
      expect(worker.notification_service).to receive(:issue_due).with(issue2)

      worker.perform(project.id)
    end
  end
end

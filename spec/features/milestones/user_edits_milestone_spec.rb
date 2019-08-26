# frozen_string_literal: true

require "rails_helper"

describe "User edits milestone", :js do
  set(:user) { create(:user) }
  set(:project) { create(:project) }
  set(:milestone) { create(:milestone, project: project, start_date: Date.today, due_date: 5.days.from_now) }

  before do
    project.add_developer(user)
    sign_in(user)

    visit(edit_project_milestone_path(project, milestone))
  end

  it "shows the right start date and due date" do
    start_date = milestone.start_date.strftime("%F")
    due_date = milestone.due_date.strftime("%F")

    expect(page).to have_field(with: start_date)
    expect(page).to have_field(with: due_date)
  end
end

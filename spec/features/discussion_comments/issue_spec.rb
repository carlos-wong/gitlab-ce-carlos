# frozen_string_literal: true

require 'spec_helper'

describe 'Thread Comments Issue', :js do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:issue) { create(:issue, project: project) }

  before do
    project.add_maintainer(user)
    sign_in(user)

    visit project_issue_path(project, issue)
  end

  it_behaves_like 'thread comments', 'issue'
end

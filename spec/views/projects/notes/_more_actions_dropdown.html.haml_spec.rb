require 'spec_helper'

describe 'projects/notes/_more_actions_dropdown' do
  let(:author_user) { create(:user) }
  let(:not_author_user) { create(:user) }

  let(:project) { create(:project) }
  let(:issue) { create(:issue, project: project) }
  let!(:note) { create(:note_on_issue, author: author_user, noteable: issue, project: project) }

  before do
    assign(:project, project)
  end

  it 'shows Report abuse to admin button if not editable and not current users comment' do
    render 'projects/notes/more_actions_dropdown', current_user: not_author_user, note_editable: false, note: note

    expect(rendered).to have_link('Report abuse to admin')
  end

  it 'does not show the More actions button if not editable and current users comment' do
    render 'projects/notes/more_actions_dropdown', current_user: author_user, note_editable: false, note: note

    expect(rendered).not_to have_selector('.dropdown.more-actions')
  end

  it 'shows Report abuse to admin and Delete buttons if editable and not current users comment' do
    render 'projects/notes/more_actions_dropdown', current_user: not_author_user, note_editable: true, note: note

    expect(rendered).to have_link('Report abuse to admin')
    expect(rendered).to have_link('Delete comment')
  end

  it 'shows Delete button if editable and current users comment' do
    render 'projects/notes/more_actions_dropdown', current_user: author_user, note_editable: true, note: note

    expect(rendered).to have_link('Delete comment')
  end
end

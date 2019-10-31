# frozen_string_literal: true

require 'spec_helper'

describe 'admin/dashboard/index.html.haml' do
  include Devise::Test::ControllerHelpers

  before do
    counts = Admin::DashboardController::COUNTED_ITEMS.each_with_object({}) do |item, hash|
      hash[item] = 100
    end

    assign(:counts, counts)
    assign(:projects, create_list(:project, 1))
    assign(:users, create_list(:user, 1))
    assign(:groups, create_list(:group, 1))

    allow(view).to receive(:admin?).and_return(true)
    allow(view).to receive(:current_application_settings).and_return(Gitlab::CurrentSettings.current_application_settings)
    allow(view).to receive(:show_license_breakdown?).and_return(false)
  end

  it "shows version of GitLab Workhorse" do
    render

    expect(rendered).to have_content 'GitLab Workhorse'
    expect(rendered).to have_content Gitlab::Workhorse.version
  end

  it "includes revision of GitLab" do
    render

    expect(rendered).to have_content "#{Gitlab::VERSION} (#{Gitlab.revision})"
  end
end

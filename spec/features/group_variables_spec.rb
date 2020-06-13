# frozen_string_literal: true

require 'spec_helper'

describe 'Group variables', :js do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let!(:variable) { create(:ci_group_variable, key: 'test_key', value: 'test_value', masked: true, group: group) }
  let(:page_path) { group_settings_ci_cd_path(group) }

  before do
    group.add_owner(user)
    gitlab_sign_in(user)
    stub_feature_flags(new_variables_ui: false)
    visit page_path
  end

  it_behaves_like 'variable list'
end

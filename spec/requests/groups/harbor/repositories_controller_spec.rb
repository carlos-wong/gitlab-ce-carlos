# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Harbor::RepositoriesController do
  it_behaves_like 'a harbor repositories controller', anonymous_status_code: '404' do
    let_it_be(:container, reload: true) { create(:group) }
    let_it_be(:harbor_integration) { create(:harbor_integration, group: container, project: nil) }
  end
end

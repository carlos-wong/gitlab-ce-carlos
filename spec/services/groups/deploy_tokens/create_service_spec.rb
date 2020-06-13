# frozen_string_literal: true

require 'spec_helper'

describe Groups::DeployTokens::CreateService do
  it_behaves_like 'a deploy token creation service' do
    let(:entity) { create(:group) }
    let(:deploy_token_class) { GroupDeployToken }
  end
end

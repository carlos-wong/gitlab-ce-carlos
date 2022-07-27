# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OauthAccessToken do
  let(:user) { create(:user) }
  let(:app_one) { create(:oauth_application) }
  let(:app_two) { create(:oauth_application) }
  let(:app_three) { create(:oauth_application) }
  let(:token) { create(:oauth_access_token, application_id: app_one.id) }

  describe 'scopes' do
    describe '.distinct_resource_owner_counts' do
      let(:tokens) { described_class.all }

      before do
        token
        create_list(:oauth_access_token, 2, resource_owner: user, application_id: app_two.id)
      end

      it 'returns unique owners' do
        expect(tokens.count).to eq(3)
        expect(tokens.distinct_resource_owner_counts([app_one])).to eq({ app_one.id => 1 })
        expect(tokens.distinct_resource_owner_counts([app_two])).to eq({ app_two.id => 1 })
        expect(tokens.distinct_resource_owner_counts([app_three])).to eq({})
        expect(tokens.distinct_resource_owner_counts([app_one, app_two]))
          .to eq({
                   app_one.id => 1,
                   app_two.id => 1
                 })
      end
    end

    describe '.latest_per_application' do
      let!(:app_two_token1) { create(:oauth_access_token, application: app_two) }
      let!(:app_two_token2) { create(:oauth_access_token, application: app_two) }
      let!(:app_three_token1) { create(:oauth_access_token, application: app_three) }
      let!(:app_three_token2) { create(:oauth_access_token, application: app_three) }

      it 'returns only the latest token for each application' do
        expect(described_class.latest_per_application.map(&:id))
          .to match_array([app_two_token2.id, app_three_token2.id])
      end
    end
  end
end

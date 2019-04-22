# frozen_string_literal: true

require 'spec_helper'

describe ProjectAuthorization do
  let(:user) { create(:user) }
  let(:project1) { create(:project) }
  let(:project2) { create(:project) }

  describe '.insert_authorizations' do
    it 'inserts the authorizations' do
      described_class
        .insert_authorizations([[user.id, project1.id, Gitlab::Access::MAINTAINER]])

      expect(user.project_authorizations.count).to eq(1)
    end

    it 'inserts rows in batches' do
      described_class.insert_authorizations([
        [user.id, project1.id, Gitlab::Access::MAINTAINER],
        [user.id, project2.id, Gitlab::Access::MAINTAINER]
      ], 1)

      expect(user.project_authorizations.count).to eq(2)
    end
  end
end

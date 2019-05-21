# frozen_string_literal: true

require 'spec_helper'

describe Boards::Lists::MoveService do
  describe '#execute' do
    context 'when board parent is a project' do
      let(:project) { create(:project) }
      let(:board)   { create(:board, project: project) }
      let(:user)    { create(:user) }

      let(:parent) { project }

      it_behaves_like 'lists move service'
    end

    context 'when board parent is a group' do
      let(:group) { create(:group) }
      let(:board)   { create(:board, group: group) }
      let(:user)    { create(:user) }

      let(:parent) { group }

      it_behaves_like 'lists move service'
    end
  end
end

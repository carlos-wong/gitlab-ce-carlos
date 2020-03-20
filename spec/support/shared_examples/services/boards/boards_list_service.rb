# frozen_string_literal: true

shared_examples 'boards list service' do
  context 'when parent does not have a board' do
    it 'creates a new parent board' do
      expect { service.execute }.to change(parent.boards, :count).by(1)
    end

    it 'delegates the parent board creation to Boards::CreateService' do
      expect_any_instance_of(Boards::CreateService).to receive(:execute).once

      service.execute
    end
  end

  context 'when parent has a board' do
    before do
      create(:board, resource_parent: parent)
    end

    it 'does not create a new board' do
      expect { service.execute }.not_to change(parent.boards, :count)
    end
  end

  it 'returns parent boards' do
    board = create(:board, resource_parent: parent)

    expect(service.execute).to eq [board]
  end
end

shared_examples 'multiple boards list service' do
  let(:service)  { described_class.new(parent, double) }
  let!(:board_B) { create(:board, resource_parent: parent, name: 'B-board') }
  let!(:board_c) { create(:board, resource_parent: parent, name: 'c-board') }
  let!(:board_a) { create(:board, resource_parent: parent, name: 'a-board') }

  describe '#execute' do
    it 'returns all issue boards' do
      expect(service.execute.size).to eq(3)
    end

    it 'returns boards ordered by name' do
      expect(service.execute).to eq [board_a, board_B, board_c]
    end
  end
end

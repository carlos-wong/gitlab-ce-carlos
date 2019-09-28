# frozen_string_literal: true

module Boards
  class CreateService < Boards::BaseService
    def execute
      create_board! if can_create_board?
    end

    private

    def can_create_board?
      parent.boards.empty? || parent.multiple_issue_boards_available?
    end

    def create_board!
      board = parent.boards.create(params)

      if board.persisted?
        board.lists.create(list_type: :backlog)
        board.lists.create(list_type: :closed)
      end

      board
    end
  end
end

Boards::CreateService.prepend_if_ee('EE::Boards::CreateService')

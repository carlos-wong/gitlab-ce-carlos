# frozen_string_literal: true

module Boards
  class ListService < Boards::BaseService
    def execute
      create_board! if parent.boards.empty?
      boards
    end

    private

    def boards
      parent.boards
    end

    def create_board!
      Boards::CreateService.new(parent, current_user).execute
    end
  end
end

Boards::ListService.prepend_if_ee('EE::Boards::ListService')

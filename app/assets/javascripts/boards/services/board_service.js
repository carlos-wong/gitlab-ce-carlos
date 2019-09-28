/* eslint-disable class-methods-use-this */
/**
 * This file is intended to be deleted.
 * The existing functions will removed one by one in favor of using the board store directly.
 * see https://gitlab.com/gitlab-org/gitlab-foss/issues/61621
 */

import boardsStore from '~/boards/stores/boards_store';

export default class BoardService {
  generateBoardsPath(id) {
    return boardsStore.generateBoardsPath(id);
  }

  generateIssuesPath(id) {
    return boardsStore.generateIssuesPath(id);
  }

  static generateIssuePath(boardId, id) {
    return boardsStore.generateIssuePath(boardId, id);
  }

  all() {
    return boardsStore.all();
  }

  generateDefaultLists() {
    return boardsStore.generateDefaultLists();
  }

  createList(entityId, entityType) {
    return boardsStore.createList(entityId, entityType);
  }

  updateList(id, position, collapsed) {
    return boardsStore.updateList(id, position, collapsed);
  }

  destroyList(id) {
    return boardsStore.destroyList(id);
  }

  getIssuesForList(id, filter = {}) {
    return boardsStore.getIssuesForList(id, filter);
  }

  moveIssue(id, fromListId = null, toListId = null, moveBeforeId = null, moveAfterId = null) {
    return boardsStore.moveIssue(id, fromListId, toListId, moveBeforeId, moveAfterId);
  }

  newIssue(id, issue) {
    return boardsStore.newIssue(id, issue);
  }

  getBacklog(data) {
    return boardsStore.getBacklog(data);
  }

  bulkUpdate(issueIds, extraData = {}) {
    return boardsStore.bulkUpdate(issueIds, extraData);
  }

  static getIssueInfo(endpoint) {
    return boardsStore.getIssueInfo(endpoint);
  }

  static toggleIssueSubscription(endpoint) {
    return boardsStore.toggleIssueSubscription(endpoint);
  }

  allBoards() {
    return boardsStore.allBoards();
  }

  recentBoards() {
    return boardsStore.recentBoards();
  }

  createBoard(board) {
    return boardsStore.createBoard(board);
  }

  deleteBoard({ id }) {
    return boardsStore.deleteBoard({ id });
  }
}

window.BoardService = BoardService;

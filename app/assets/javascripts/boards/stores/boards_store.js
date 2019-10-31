/* eslint-disable no-shadow */
/* global List */

import $ from 'jquery';
import _ from 'underscore';
import Vue from 'vue';
import Cookies from 'js-cookie';
import BoardsStoreEE from 'ee_else_ce/boards/stores/boards_store_ee';
import { getUrlParamsArray, parseBoolean } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import eventHub from '../eventhub';
import { ListType } from '../constants';

const boardsStore = {
  disabled: false,
  timeTracking: {
    limitToHours: false,
  },
  scopedLabels: {
    helpLink: '',
    enabled: false,
  },
  filter: {
    path: '',
  },
  state: {
    currentBoard: {
      labels: [],
    },
    currentPage: '',
    reload: false,
    endpoints: {},
  },
  detail: {
    issue: {},
  },
  moving: {
    issue: {},
    list: {},
  },
  multiSelect: { list: [] },

  setEndpoints({ boardsEndpoint, listsEndpoint, bulkUpdatePath, boardId, recentBoardsEndpoint }) {
    const listsEndpointGenerate = `${listsEndpoint}/generate.json`;
    this.state.endpoints = {
      boardsEndpoint,
      boardId,
      listsEndpoint,
      listsEndpointGenerate,
      bulkUpdatePath,
      recentBoardsEndpoint: `${recentBoardsEndpoint}.json`,
    };
  },
  create() {
    this.state.lists = [];
    this.filter.path = getUrlParamsArray().join('&');
    this.detail = {
      issue: {},
    };
  },
  showPage(page) {
    this.state.reload = false;
    this.state.currentPage = page;
  },
  addList(listObj, defaultAvatar) {
    const list = new List(listObj, defaultAvatar);
    this.state.lists = _.sortBy([...this.state.lists, list], 'position');

    return list;
  },
  new(listObj) {
    const list = this.addList(listObj);
    const backlogList = this.findList('type', 'backlog', 'backlog');

    list
      .save()
      .then(() => {
        // Remove any new issues from the backlog
        // as they will be visible in the new list
        list.issues.forEach(backlogList.removeIssue.bind(backlogList));
        this.state.lists = _.sortBy(this.state.lists, 'position');
      })
      .catch(() => {
        // https://gitlab.com/gitlab-org/gitlab-foss/issues/30821
      });
    this.removeBlankState();
  },
  updateNewListDropdown(listId) {
    $(`.js-board-list-${listId}`).removeClass('is-active');
  },
  shouldAddBlankState() {
    // Decide whether to add the blank state
    return !this.state.lists.filter(list => list.type !== 'backlog' && list.type !== 'closed')[0];
  },
  addBlankState() {
    if (!this.shouldAddBlankState() || this.welcomeIsHidden() || this.disabled) return;

    this.addList({
      id: 'blank',
      list_type: 'blank',
      title: __('Welcome to your Issue Board!'),
      position: 0,
    });
  },
  removeBlankState() {
    this.removeList('blank');

    Cookies.set('issue_board_welcome_hidden', 'true', {
      expires: 365 * 10,
      path: '',
    });
  },
  welcomeIsHidden() {
    return parseBoolean(Cookies.get('issue_board_welcome_hidden'));
  },
  removeList(id, type = 'blank') {
    const list = this.findList('id', id, type);

    if (!list) return;

    this.state.lists = this.state.lists.filter(list => list.id !== id);
  },
  moveList(listFrom, orderLists) {
    orderLists.forEach((id, i) => {
      const list = this.findList('id', parseInt(id, 10));

      list.position = i;
    });
    listFrom.update();
  },

  startMoving(list, issue) {
    Object.assign(this.moving, { list, issue });
  },

  moveMultipleIssuesToList({ listFrom, listTo, issues, newIndex }) {
    const issueTo = issues.map(issue => listTo.findIssue(issue.id));
    const issueLists = _.flatten(issues.map(issue => issue.getLists()));
    const listLabels = issueLists.map(list => list.label);

    const hasMoveableIssues = _.compact(issueTo).length > 0;

    if (!hasMoveableIssues) {
      // Check if target list assignee is already present in this issue
      if (
        listTo.type === ListType.assignee &&
        listFrom.type === ListType.assignee &&
        issues.some(issue => issue.findAssignee(listTo.assignee))
      ) {
        const targetIssues = issues.map(issue => listTo.findIssue(issue.id));
        targetIssues.forEach(targetIssue => targetIssue.removeAssignee(listFrom.assignee));
      } else if (listTo.type === 'milestone') {
        const currentMilestones = issues.map(issue => issue.milestone);
        const currentLists = this.state.lists
          .filter(list => list.type === 'milestone' && list.id !== listTo.id)
          .filter(list =>
            list.issues.some(listIssue => issues.some(issue => listIssue.id === issue.id)),
          );

        issues.forEach(issue => {
          currentMilestones.forEach(milestone => {
            issue.removeMilestone(milestone);
          });
        });

        issues.forEach(issue => {
          issue.addMilestone(listTo.milestone);
        });

        currentLists.forEach(currentList => {
          issues.forEach(issue => {
            currentList.removeIssue(issue);
          });
        });

        listTo.addMultipleIssues(issues, listFrom, newIndex);
      } else {
        // Add to new lists issues if it doesn't already exist
        listTo.addMultipleIssues(issues, listFrom, newIndex);
      }
    } else {
      listTo.updateMultipleIssues(issues, listFrom);
      issues.forEach(issue => {
        issue.removeLabel(listFrom.label);
      });
    }

    if (listTo.type === ListType.closed && listFrom.type !== ListType.backlog) {
      issueLists.forEach(list => {
        issues.forEach(issue => {
          list.removeIssue(issue);
        });
      });

      issues.forEach(issue => {
        issue.removeLabels(listLabels);
      });
    } else if (listTo.type === ListType.backlog && listFrom.type === ListType.assignee) {
      issues.forEach(issue => {
        issue.removeAssignee(listFrom.assignee);
      });
      issueLists.forEach(list => {
        issues.forEach(issue => {
          list.removeIssue(issue);
        });
      });
    } else if (listTo.type === ListType.backlog && listFrom.type === ListType.milestone) {
      issues.forEach(issue => {
        issue.removeMilestone(listFrom.milestone);
      });
      issueLists.forEach(list => {
        issues.forEach(issue => {
          list.removeIssue(issue);
        });
      });
    } else if (
      this.shouldRemoveIssue(listFrom, listTo) &&
      this.issuesAreContiguous(listFrom, issues)
    ) {
      listFrom.removeMultipleIssues(issues);
    }
  },

  issuesAreContiguous(list, issues) {
    // When there's only 1 issue selected, we can return early.
    if (issues.length === 1) return true;

    // Create list of ids for issues involved.
    const listIssueIds = list.issues.map(issue => issue.id);
    const movedIssueIds = issues.map(issue => issue.id);

    // Check if moved issue IDs is sub-array
    // of source list issue IDs (i.e. contiguous selection).
    return listIssueIds.join('|').includes(movedIssueIds.join('|'));
  },

  moveIssueToList(listFrom, listTo, issue, newIndex) {
    const issueTo = listTo.findIssue(issue.id);
    const issueLists = issue.getLists();
    const listLabels = issueLists.map(listIssue => listIssue.label);

    if (!issueTo) {
      // Check if target list assignee is already present in this issue
      if (
        listTo.type === 'assignee' &&
        listFrom.type === 'assignee' &&
        issue.findAssignee(listTo.assignee)
      ) {
        const targetIssue = listTo.findIssue(issue.id);
        targetIssue.removeAssignee(listFrom.assignee);
      } else if (listTo.type === 'milestone') {
        const currentMilestone = issue.milestone;
        const currentLists = this.state.lists
          .filter(list => list.type === 'milestone' && list.id !== listTo.id)
          .filter(list => list.issues.some(listIssue => issue.id === listIssue.id));

        issue.removeMilestone(currentMilestone);
        issue.addMilestone(listTo.milestone);
        currentLists.forEach(currentList => currentList.removeIssue(issue));
        listTo.addIssue(issue, listFrom, newIndex);
      } else {
        // Add to new lists issues if it doesn't already exist
        listTo.addIssue(issue, listFrom, newIndex);
      }
    } else {
      listTo.updateIssueLabel(issue, listFrom);
      issueTo.removeLabel(listFrom.label);
    }

    if (listTo.type === 'closed' && listFrom.type !== 'backlog') {
      issueLists.forEach(list => {
        list.removeIssue(issue);
      });
      issue.removeLabels(listLabels);
    } else if (listTo.type === 'backlog' && listFrom.type === 'assignee') {
      issue.removeAssignee(listFrom.assignee);
      listFrom.removeIssue(issue);
    } else if (listTo.type === 'backlog' && listFrom.type === 'milestone') {
      issue.removeMilestone(listFrom.milestone);
      listFrom.removeIssue(issue);
    } else if (this.shouldRemoveIssue(listFrom, listTo)) {
      listFrom.removeIssue(issue);
    }
  },
  shouldRemoveIssue(listFrom, listTo) {
    return (
      (listTo.type !== 'label' && listFrom.type === 'assignee') ||
      (listTo.type !== 'assignee' && listFrom.type === 'label') ||
      listFrom.type === 'backlog'
    );
  },
  moveIssueInList(list, issue, oldIndex, newIndex, idArray) {
    const beforeId = parseInt(idArray[newIndex - 1], 10) || null;
    const afterId = parseInt(idArray[newIndex + 1], 10) || null;

    list.moveIssue(issue, oldIndex, newIndex, beforeId, afterId);
  },
  moveMultipleIssuesInList({ list, issues, oldIndicies, newIndex, idArray }) {
    const beforeId = parseInt(idArray[newIndex - 1], 10) || null;
    const afterId = parseInt(idArray[newIndex + issues.length], 10) || null;
    list.moveMultipleIssues({
      issues,
      oldIndicies,
      newIndex,
      moveBeforeId: beforeId,
      moveAfterId: afterId,
    });
  },
  findList(key, val, type = 'label') {
    const filteredList = this.state.lists.filter(list => {
      const byType = type
        ? list.type === type || list.type === 'assignee' || list.type === 'milestone'
        : true;

      return list[key] === val && byType;
    });
    return filteredList[0];
  },
  findListByLabelId(id) {
    return this.state.lists.find(list => list.type === 'label' && list.label.id === id);
  },

  toggleFilter(filter) {
    const filterPath = this.filter.path.split('&');
    const filterIndex = filterPath.indexOf(filter);

    if (filterIndex === -1) {
      filterPath.push(filter);
    } else {
      filterPath.splice(filterIndex, 1);
    }

    this.filter.path = filterPath.join('&');

    this.updateFiltersUrl();

    eventHub.$emit('updateTokens');
  },

  setListDetail(newList) {
    this.detail.list = newList;
  },

  updateFiltersUrl() {
    window.history.pushState(null, null, `?${this.filter.path}`);
  },

  clearDetailIssue() {
    this.setIssueDetail({});
  },

  setIssueDetail(issueDetail) {
    this.detail.issue = issueDetail;
  },

  setTimeTrackingLimitToHours(limitToHours) {
    this.timeTracking.limitToHours = parseBoolean(limitToHours);
  },

  generateBoardsPath(id) {
    return `${this.state.endpoints.boardsEndpoint}${id ? `/${id}` : ''}.json`;
  },

  generateIssuesPath(id) {
    return `${this.state.endpoints.listsEndpoint}${id ? `/${id}` : ''}/issues`;
  },

  generateIssuePath(boardId, id) {
    return `${gon.relative_url_root}/-/boards/${boardId ? `${boardId}` : ''}/issues${
      id ? `/${id}` : ''
    }`;
  },

  generateMultiDragPath(boardId) {
    return `${gon.relative_url_root}/-/boards/${boardId ? `${boardId}` : ''}/issues/bulk_move`;
  },

  all() {
    return axios.get(this.state.endpoints.listsEndpoint);
  },

  generateDefaultLists() {
    return axios.post(this.state.endpoints.listsEndpointGenerate, {});
  },

  createList(entityId, entityType) {
    const list = {
      [entityType]: entityId,
    };

    return axios.post(this.state.endpoints.listsEndpoint, {
      list,
    });
  },

  updateList(id, position, collapsed) {
    return axios.put(`${this.state.endpoints.listsEndpoint}/${id}`, {
      list: {
        position,
        collapsed,
      },
    });
  },

  destroyList(id) {
    return axios.delete(`${this.state.endpoints.listsEndpoint}/${id}`);
  },

  getIssuesForList(id, filter = {}) {
    const data = { id };
    Object.keys(filter).forEach(key => {
      data[key] = filter[key];
    });

    return axios.get(mergeUrlParams(data, this.generateIssuesPath(id)));
  },

  moveIssue(id, fromListId = null, toListId = null, moveBeforeId = null, moveAfterId = null) {
    return axios.put(this.generateIssuePath(this.state.endpoints.boardId, id), {
      from_list_id: fromListId,
      to_list_id: toListId,
      move_before_id: moveBeforeId,
      move_after_id: moveAfterId,
    });
  },

  moveMultipleIssues({ ids, fromListId, toListId, moveBeforeId, moveAfterId }) {
    return axios.put(this.generateMultiDragPath(this.state.endpoints.boardId), {
      from_list_id: fromListId,
      to_list_id: toListId,
      move_before_id: moveBeforeId,
      move_after_id: moveAfterId,
      ids,
    });
  },

  newIssue(id, issue) {
    return axios.post(this.generateIssuesPath(id), {
      issue,
    });
  },

  getBacklog(data) {
    return axios.get(
      mergeUrlParams(
        data,
        `${gon.relative_url_root}/-/boards/${this.state.endpoints.boardId}/issues.json`,
      ),
    );
  },

  bulkUpdate(issueIds, extraData = {}) {
    const data = {
      update: Object.assign(extraData, {
        issuable_ids: issueIds.join(','),
      }),
    };

    return axios.post(this.state.endpoints.bulkUpdatePath, data);
  },

  getIssueInfo(endpoint) {
    return axios.get(endpoint);
  },

  toggleIssueSubscription(endpoint) {
    return axios.post(endpoint);
  },

  allBoards() {
    return axios.get(this.generateBoardsPath());
  },

  recentBoards() {
    return axios.get(this.state.endpoints.recentBoardsEndpoint);
  },

  createBoard(board) {
    const boardPayload = { ...board };
    boardPayload.label_ids = (board.labels || []).map(b => b.id);

    if (boardPayload.label_ids.length === 0) {
      boardPayload.label_ids = [''];
    }

    if (boardPayload.assignee) {
      boardPayload.assignee_id = boardPayload.assignee.id;
    }

    if (boardPayload.milestone) {
      boardPayload.milestone_id = boardPayload.milestone.id;
    }

    if (boardPayload.id) {
      return axios.put(this.generateBoardsPath(boardPayload.id), { board: boardPayload });
    }
    return axios.post(this.generateBoardsPath(), { board: boardPayload });
  },

  deleteBoard({ id }) {
    return axios.delete(this.generateBoardsPath(id));
  },

  setCurrentBoard(board) {
    this.state.currentBoard = board;
  },

  toggleMultiSelect(issue) {
    const selectedIssueIds = this.multiSelect.list.map(issue => issue.id);
    const index = selectedIssueIds.indexOf(issue.id);

    if (index === -1) {
      this.multiSelect.list.push(issue);
      return;
    }

    this.multiSelect.list = [
      ...this.multiSelect.list.slice(0, index),
      ...this.multiSelect.list.slice(index + 1),
    ];
  },

  clearMultiSelect() {
    this.multiSelect.list = [];
  },
};

BoardsStoreEE.initEESpecific(boardsStore);

// hacks added in order to allow milestone_select to function properly
// TODO: remove these

export function boardStoreIssueSet(...args) {
  Vue.set(boardsStore.detail.issue, ...args);
}

export function boardStoreIssueDelete(...args) {
  Vue.delete(boardsStore.detail.issue, ...args);
}

export default boardsStore;

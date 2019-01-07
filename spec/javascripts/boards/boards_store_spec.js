/* eslint-disable no-unused-vars */
/* global ListIssue */

import Vue from 'vue';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import Cookies from 'js-cookie';

import '~/vue_shared/models/label';
import '~/vue_shared/models/assignee';
import '~/boards/models/issue';
import '~/boards/models/list';
import '~/boards/services/board_service';
import boardsStore from '~/boards/stores/boards_store';
import { listObj, listObjDuplicate, boardsMockInterceptor, mockBoardService } from './mock_data';

describe('Store', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    mock.onAny().reply(boardsMockInterceptor);
    gl.boardService = mockBoardService();
    boardsStore.create();

    spyOn(gl.boardService, 'moveIssue').and.callFake(
      () =>
        new Promise(resolve => {
          resolve();
        }),
    );

    Cookies.set('issue_board_welcome_hidden', 'false', {
      expires: 365 * 10,
      path: '',
    });
  });

  afterEach(() => {
    mock.restore();
  });

  it('starts with a blank state', () => {
    expect(boardsStore.state.lists.length).toBe(0);
  });

  describe('lists', () => {
    it('creates new list without persisting to DB', () => {
      boardsStore.addList(listObj);

      expect(boardsStore.state.lists.length).toBe(1);
    });

    it('finds list by ID', () => {
      boardsStore.addList(listObj);
      const list = boardsStore.findList('id', listObj.id);

      expect(list.id).toBe(listObj.id);
    });

    it('finds list by type', () => {
      boardsStore.addList(listObj);
      const list = boardsStore.findList('type', 'label');

      expect(list).toBeDefined();
    });

    it('finds list by label ID', () => {
      boardsStore.addList(listObj);
      const list = boardsStore.findListByLabelId(listObj.label.id);

      expect(list.id).toBe(listObj.id);
    });

    it('gets issue when new list added', done => {
      boardsStore.addList(listObj);
      const list = boardsStore.findList('id', listObj.id);

      expect(boardsStore.state.lists.length).toBe(1);

      setTimeout(() => {
        expect(list.issues.length).toBe(1);
        expect(list.issues[0].id).toBe(1);
        done();
      }, 0);
    });

    it('persists new list', done => {
      boardsStore.new({
        title: 'Test',
        list_type: 'label',
        label: {
          id: 1,
          title: 'Testing',
          color: 'red',
          description: 'testing;',
        },
      });

      expect(boardsStore.state.lists.length).toBe(1);

      setTimeout(() => {
        const list = boardsStore.findList('id', listObj.id);

        expect(list).toBeDefined();
        expect(list.id).toBe(listObj.id);
        expect(list.position).toBe(0);
        done();
      }, 0);
    });

    it('check for blank state adding', () => {
      expect(boardsStore.shouldAddBlankState()).toBe(true);
    });

    it('check for blank state not adding', () => {
      boardsStore.addList(listObj);

      expect(boardsStore.shouldAddBlankState()).toBe(false);
    });

    it('check for blank state adding when closed list exist', () => {
      boardsStore.addList({
        list_type: 'closed',
      });

      expect(boardsStore.shouldAddBlankState()).toBe(true);
    });

    it('adds the blank state', () => {
      boardsStore.addBlankState();

      const list = boardsStore.findList('type', 'blank', 'blank');

      expect(list).toBeDefined();
    });

    it('removes list from state', () => {
      boardsStore.addList(listObj);

      expect(boardsStore.state.lists.length).toBe(1);

      boardsStore.removeList(listObj.id, 'label');

      expect(boardsStore.state.lists.length).toBe(0);
    });

    it('moves the position of lists', () => {
      const listOne = boardsStore.addList(listObj);
      const listTwo = boardsStore.addList(listObjDuplicate);

      expect(boardsStore.state.lists.length).toBe(2);

      boardsStore.moveList(listOne, [listObjDuplicate.id, listObj.id]);

      expect(listOne.position).toBe(1);
    });

    it('moves an issue from one list to another', done => {
      const listOne = boardsStore.addList(listObj);
      const listTwo = boardsStore.addList(listObjDuplicate);

      expect(boardsStore.state.lists.length).toBe(2);

      setTimeout(() => {
        expect(listOne.issues.length).toBe(1);
        expect(listTwo.issues.length).toBe(1);

        boardsStore.moveIssueToList(listOne, listTwo, listOne.findIssue(1));

        expect(listOne.issues.length).toBe(0);
        expect(listTwo.issues.length).toBe(1);

        done();
      }, 0);
    });

    it('moves an issue from backlog to a list', done => {
      const backlog = boardsStore.addList({
        ...listObj,
        list_type: 'backlog',
      });
      const listTwo = boardsStore.addList(listObjDuplicate);

      expect(boardsStore.state.lists.length).toBe(2);

      setTimeout(() => {
        expect(backlog.issues.length).toBe(1);
        expect(listTwo.issues.length).toBe(1);

        boardsStore.moveIssueToList(backlog, listTwo, backlog.findIssue(1));

        expect(backlog.issues.length).toBe(0);
        expect(listTwo.issues.length).toBe(1);

        done();
      }, 0);
    });

    it('moves issue to top of another list', done => {
      const listOne = boardsStore.addList(listObj);
      const listTwo = boardsStore.addList(listObjDuplicate);

      expect(boardsStore.state.lists.length).toBe(2);

      setTimeout(() => {
        listOne.issues[0].id = 2;

        expect(listOne.issues.length).toBe(1);
        expect(listTwo.issues.length).toBe(1);

        boardsStore.moveIssueToList(listOne, listTwo, listOne.findIssue(2), 0);

        expect(listOne.issues.length).toBe(0);
        expect(listTwo.issues.length).toBe(2);
        expect(listTwo.issues[0].id).toBe(2);
        expect(gl.boardService.moveIssue).toHaveBeenCalledWith(2, listOne.id, listTwo.id, null, 1);

        done();
      }, 0);
    });

    it('moves issue to bottom of another list', done => {
      const listOne = boardsStore.addList(listObj);
      const listTwo = boardsStore.addList(listObjDuplicate);

      expect(boardsStore.state.lists.length).toBe(2);

      setTimeout(() => {
        listOne.issues[0].id = 2;

        expect(listOne.issues.length).toBe(1);
        expect(listTwo.issues.length).toBe(1);

        boardsStore.moveIssueToList(listOne, listTwo, listOne.findIssue(2), 1);

        expect(listOne.issues.length).toBe(0);
        expect(listTwo.issues.length).toBe(2);
        expect(listTwo.issues[1].id).toBe(2);
        expect(gl.boardService.moveIssue).toHaveBeenCalledWith(2, listOne.id, listTwo.id, 1, null);

        done();
      }, 0);
    });

    it('moves issue in list', done => {
      const issue = new ListIssue({
        title: 'Testing',
        id: 2,
        iid: 2,
        confidential: false,
        labels: [],
        assignees: [],
      });
      const list = boardsStore.addList(listObj);

      setTimeout(() => {
        list.addIssue(issue);

        expect(list.issues.length).toBe(2);

        boardsStore.moveIssueInList(list, issue, 0, 1, [1, 2]);

        expect(list.issues[0].id).toBe(2);
        expect(gl.boardService.moveIssue).toHaveBeenCalledWith(2, null, null, 1, null);

        done();
      });
    });
  });
});

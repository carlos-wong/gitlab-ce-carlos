import $ from 'jquery';
import MockAdapter from 'axios-mock-adapter';
import Todos from '~/pages/dashboard/todos/index/todos';
import '~/lib/utils/common_utils';
import '~/gl_dropdown';
import axios from '~/lib/utils/axios_utils';
import { addDelimiter } from '~/lib/utils/text_utility';

const TEST_COUNT_BIG = 2000;
const TEST_DONE_COUNT_BIG = 7300;

describe('Todos', () => {
  preloadFixtures('todos/todos.html');
  let todoItem;
  let mock;

  beforeEach(() => {
    loadFixtures('todos/todos.html');
    todoItem = document.querySelector('.todos-list .todo');
    mock = new MockAdapter(axios);

    return new Todos();
  });

  afterEach(() => {
    mock.restore();
  });

  describe('goToTodoUrl', () => {
    it('opens the todo url', done => {
      const todoLink = todoItem.dataset.url;

      spyOnDependency(Todos, 'visitUrl').and.callFake(url => {
        expect(url).toEqual(todoLink);
        done();
      });

      todoItem.click();
    });

    describe('meta click', () => {
      let visitUrlSpy;
      let windowOpenSpy;
      let metakeyEvent;

      beforeEach(() => {
        metakeyEvent = $.Event('click', { keyCode: 91, ctrlKey: true });
        visitUrlSpy = spyOnDependency(Todos, 'visitUrl').and.callFake(() => {});
        windowOpenSpy = spyOn(window, 'open').and.callFake(() => {});
      });

      it('opens the todo url in another tab', () => {
        const todoLink = todoItem.dataset.url;

        $('.todos-list .todo').trigger(metakeyEvent);

        expect(visitUrlSpy).not.toHaveBeenCalled();
        expect(windowOpenSpy).toHaveBeenCalledWith(todoLink, '_blank');
      });

      it('run native funcionality when avatar is clicked', () => {
        $('.todos-list a').on('click', e => e.preventDefault());
        $('.todos-list img').trigger(metakeyEvent);

        expect(visitUrlSpy).not.toHaveBeenCalled();
        expect(windowOpenSpy).not.toHaveBeenCalled();
      });
    });

    describe('on done todo click', () => {
      let onToggleSpy;

      beforeEach(done => {
        const el = document.querySelector('.js-done-todo');
        const path = el.dataset.href;

        // Arrange
        mock
          .onDelete(path)
          .replyOnce(200, { count: TEST_COUNT_BIG, done_count: TEST_DONE_COUNT_BIG });
        onToggleSpy = jasmine.createSpy('onToggle');
        $(document).on('todo:toggle', onToggleSpy);

        // Act
        el.click();

        // Wait for axios and HTML to udpate
        setImmediate(done);
      });

      it('dispatches todo:toggle', () => {
        expect(onToggleSpy).toHaveBeenCalledWith(jasmine.anything(), TEST_COUNT_BIG);
      });

      it('updates pending text', () => {
        expect(document.querySelector('.todos-pending .badge').innerHTML).toEqual(
          addDelimiter(TEST_COUNT_BIG),
        );
      });

      it('updates done text', () => {
        expect(document.querySelector('.todos-done .badge').innerHTML).toEqual(
          addDelimiter(TEST_DONE_COUNT_BIG),
        );
      });
    });
  });
});

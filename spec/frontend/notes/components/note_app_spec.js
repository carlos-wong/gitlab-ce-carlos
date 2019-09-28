import $ from 'helpers/jquery';
import AxiosMockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import Vue from 'vue';
import { mount, createLocalVue } from '@vue/test-utils';
import NotesApp from '~/notes/components/notes_app.vue';
import service from '~/notes/services/notes_service';
import createStore from '~/notes/stores';
import '~/behaviors/markdown/render_gfm';
import { setTestTimeout } from 'helpers/timeout';
// TODO: use generated fixture (https://gitlab.com/gitlab-org/gitlab-foss/issues/62491)
import * as mockData from '../../../javascripts/notes/mock_data';

setTestTimeout(1000);

describe('note_app', () => {
  let axiosMock;
  let mountComponent;
  let wrapper;
  let store;

  /**
   * waits for fetchNotes() to complete
   */
  const waitForDiscussionsRequest = () =>
    new Promise(resolve => {
      const { vm } = wrapper.find(NotesApp);
      const unwatch = vm.$watch('isFetching', isFetching => {
        if (isFetching) {
          return;
        }

        unwatch();
        resolve();
      });
    });

  beforeEach(() => {
    $('body').attr('data-page', 'projects:merge_requests:show');

    axiosMock = new AxiosMockAdapter(axios);

    store = createStore();
    mountComponent = data => {
      const propsData = data || {
        noteableData: mockData.noteableDataMock,
        notesData: mockData.notesDataMock,
        userData: mockData.userDataMock,
      };
      const localVue = createLocalVue();

      return mount(
        {
          components: {
            NotesApp,
          },
          template: '<div class="js-vue-notes-event"><notes-app v-bind="$attrs" /></div>',
        },
        {
          attachToDocument: true,
          propsData,
          store,
          localVue,
          sync: false,
        },
      );
    };
  });

  afterEach(() => {
    wrapper.destroy();
    axiosMock.restore();
  });

  describe('set data', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(200, []);
      wrapper = mountComponent();
      return waitForDiscussionsRequest();
    });

    it('should set notes data', () => {
      expect(store.state.notesData).toEqual(mockData.notesDataMock);
    });

    it('should set issue data', () => {
      expect(store.state.noteableData).toEqual(mockData.noteableDataMock);
    });

    it('should set user data', () => {
      expect(store.state.userData).toEqual(mockData.userDataMock);
    });

    it('should fetch discussions', () => {
      expect(store.state.discussions).toEqual([]);
    });
  });

  describe('render', () => {
    beforeEach(() => {
      setFixtures('<div class="js-discussions-count"></div>');

      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForDiscussionsRequest();
    });

    it('should render list of notes', () => {
      const note =
        mockData.INDIVIDUAL_NOTE_RESPONSE_MAP.GET[
          '/gitlab-org/gitlab-foss/issues/26/discussions.json'
        ][0].notes[0];

      expect(
        wrapper
          .find('.main-notes-list .note-header-author-name')
          .text()
          .trim(),
      ).toEqual(note.author.name);

      expect(wrapper.find('.main-notes-list .note-text').html()).toContain(note.note_html);
    });

    it('should render form', () => {
      expect(wrapper.find('.js-main-target-form').name()).toEqual('form');
      expect(wrapper.find('.js-main-target-form textarea').attributes('placeholder')).toEqual(
        'Write a comment or drag your files here…',
      );
    });

    it('should render form comment button as disabled', () => {
      expect(wrapper.find('.js-note-new-discussion').attributes('disabled')).toEqual('disabled');
    });

    it('updates discussions badge', () => {
      expect(document.querySelector('.js-discussions-count').textContent).toEqual('2');
    });
  });

  describe('render with comments disabled', () => {
    beforeEach(() => {
      setFixtures('<div class="js-discussions-count"></div>');

      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      store.state.commentsDisabled = true;
      wrapper = mountComponent();
      return waitForDiscussionsRequest();
    });

    it('should not render form when commenting is disabled', () => {
      expect(wrapper.find('.js-main-target-form').exists()).toBe(false);
    });

    it('should render discussion filter note `commentsDisabled` is true', () => {
      expect(wrapper.find('.js-discussion-filter-note').exists()).toBe(true);
    });
  });

  describe('while fetching data', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(200, []);
      wrapper = mountComponent();
    });

    afterEach(() => waitForDiscussionsRequest());

    it('renders skeleton notes', () => {
      expect(wrapper.find('.animation-container').exists()).toBe(true);
    });

    it('should render form', () => {
      expect(wrapper.find('.js-main-target-form').name()).toEqual('form');
      expect(wrapper.find('.js-main-target-form textarea').attributes('placeholder')).toEqual(
        'Write a comment or drag your files here…',
      );
    });
  });

  describe('update note', () => {
    describe('individual note', () => {
      beforeEach(() => {
        axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
        jest.spyOn(service, 'updateNote');
        wrapper = mountComponent();
        return waitForDiscussionsRequest().then(() => {
          wrapper.find('.js-note-edit').trigger('click');
        });
      });

      it('renders edit form', () => {
        expect(wrapper.find('.js-vue-issue-note-form').exists()).toBe(true);
      });

      it('calls the service to update the note', () => {
        wrapper.find('.js-vue-issue-note-form').value = 'this is a note';
        wrapper.find('.js-vue-issue-save').trigger('click');

        expect(service.updateNote).toHaveBeenCalled();
      });
    });

    describe('discussion note', () => {
      beforeEach(() => {
        axiosMock.onAny().reply(mockData.getDiscussionNoteResponse);
        jest.spyOn(service, 'updateNote');
        wrapper = mountComponent();
        return waitForDiscussionsRequest().then(() => {
          wrapper.find('.js-note-edit').trigger('click');
        });
      });

      it('renders edit form', () => {
        expect(wrapper.find('.js-vue-issue-note-form').exists()).toBe(true);
      });

      it('updates the note and resets the edit form', () => {
        wrapper.find('.js-vue-issue-note-form').value = 'this is a note';
        wrapper.find('.js-vue-issue-save').trigger('click');

        expect(service.updateNote).toHaveBeenCalled();
      });
    });
  });

  describe('new note form', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForDiscussionsRequest();
    });

    it('should render markdown docs url', () => {
      const { markdownDocsPath } = mockData.notesDataMock;

      expect(
        wrapper
          .find(`a[href="${markdownDocsPath}"]`)
          .text()
          .trim(),
      ).toEqual('Markdown');
    });

    it('should render quick action docs url', () => {
      const { quickActionsDocsPath } = mockData.notesDataMock;

      expect(
        wrapper
          .find(`a[href="${quickActionsDocsPath}"]`)
          .text()
          .trim(),
      ).toEqual('quick actions');
    });
  });

  describe('edit form', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForDiscussionsRequest();
    });

    it('should render markdown docs url', () => {
      wrapper.find('.js-note-edit').trigger('click');
      const { markdownDocsPath } = mockData.notesDataMock;

      return Vue.nextTick().then(() => {
        expect(
          wrapper
            .find(`.edit-note a[href="${markdownDocsPath}"]`)
            .text()
            .trim(),
        ).toEqual('Markdown is supported');
      });
    });

    it('should not render quick actions docs url', () => {
      wrapper.find('.js-note-edit').trigger('click');
      const { quickActionsDocsPath } = mockData.notesDataMock;
      expect(wrapper.find(`.edit-note a[href="${quickActionsDocsPath}"]`).exists()).toBe(false);
    });
  });

  describe('emoji awards', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(200, []);
      wrapper = mountComponent();
      return waitForDiscussionsRequest();
    });

    it('dispatches toggleAward after toggleAward event', () => {
      const toggleAwardEvent = new CustomEvent('toggleAward', {
        detail: {
          awardName: 'test',
          noteId: 1,
        },
      });
      const toggleAwardAction = jest.fn().mockName('toggleAward');
      wrapper.vm.$store.hotUpdate({
        actions: {
          toggleAward: toggleAwardAction,
          stopPolling() {},
        },
      });

      wrapper.vm.$parent.$el.dispatchEvent(toggleAwardEvent);

      expect(toggleAwardAction).toHaveBeenCalledTimes(1);
      const [, payload] = toggleAwardAction.mock.calls[0];

      expect(payload).toEqual({
        awardName: 'test',
        noteId: 1,
      });
    });
  });
});

import { mount, shallowMount } from '@vue/test-utils';
import AxiosMockAdapter from 'axios-mock-adapter';
import $ from 'jquery';
import { nextTick } from 'vue';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import setWindowLocation from 'helpers/set_window_location_helper';
import { setTestTimeout } from 'helpers/timeout';
import waitForPromises from 'helpers/wait_for_promises';
import DraftNote from '~/batch_comments/components/draft_note.vue';
import batchComments from '~/batch_comments/stores/modules/batch_comments';
import axios from '~/lib/utils/axios_utils';
import * as urlUtility from '~/lib/utils/url_utility';
import CommentForm from '~/notes/components/comment_form.vue';
import NotesApp from '~/notes/components/notes_app.vue';
import * as constants from '~/notes/constants';
import createStore from '~/notes/stores';
import '~/behaviors/markdown/render_gfm';
// TODO: use generated fixture (https://gitlab.com/gitlab-org/gitlab-foss/issues/62491)
import OrderedLayout from '~/vue_shared/components/ordered_layout.vue';
import * as mockData from '../mock_data';

setTestTimeout(1000);

const TYPE_COMMENT_FORM = 'comment-form';
const TYPE_NOTES_LIST = 'notes-list';

const propsData = {
  noteableData: mockData.noteableDataMock,
  notesData: mockData.notesDataMock,
  userData: mockData.userDataMock,
};

describe('note_app', () => {
  let axiosMock;
  let mountComponent;
  let wrapper;
  let store;

  const findCommentButton = () => wrapper.find('[data-testid="comment-button"]');

  const getComponentOrder = () => {
    return wrapper
      .findAll('#notes-list,.js-comment-form')
      .wrappers.map((node) => (node.is(CommentForm) ? TYPE_COMMENT_FORM : TYPE_NOTES_LIST));
  };

  beforeEach(() => {
    $('body').attr('data-page', 'projects:merge_requests:show');

    axiosMock = new AxiosMockAdapter(axios);

    store = createStore();
    mountComponent = () => {
      return mount(
        {
          components: {
            NotesApp,
          },
          template: `<div class="js-vue-notes-event">
            <notes-app ref="notesApp" v-bind="$attrs" />
          </div>`,
        },
        {
          propsData,
          store,
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
      setHTMLFixture('<div class="js-discussions-count"></div>');

      axiosMock.onAny().reply(200, []);
      wrapper = mountComponent();
      return waitForPromises();
    });

    afterEach(() => {
      resetHTMLFixture();
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

    it('updates discussions badge', () => {
      expect(document.querySelector('.js-discussions-count').textContent).toEqual('0');
    });
  });

  describe('render', () => {
    beforeEach(() => {
      setHTMLFixture('<div class="js-discussions-count"></div>');

      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForPromises();
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('should render list of notes', () => {
      const note =
        mockData.INDIVIDUAL_NOTE_RESPONSE_MAP.GET[
          '/gitlab-org/gitlab-foss/issues/26/discussions.json'
        ][0].notes[0];

      expect(wrapper.find('.main-notes-list .note-header-author-name').text().trim()).toEqual(
        note.author.name,
      );

      expect(wrapper.find('.main-notes-list .note-text').html()).toContain(note.note_html);
    });

    it('should render form', () => {
      expect(wrapper.find('.js-main-target-form').element.tagName).toBe('FORM');
      expect(wrapper.find('.js-main-target-form textarea').attributes('placeholder')).toEqual(
        'Write a comment or drag your files here…',
      );
    });

    it('should render form comment button as disabled', () => {
      expect(findCommentButton().props('disabled')).toEqual(true);
    });

    it('updates discussions badge', () => {
      expect(document.querySelector('.js-discussions-count').textContent).toEqual('2');
    });
  });

  describe('render with comments disabled', () => {
    beforeEach(() => {
      setHTMLFixture('<div class="js-discussions-count"></div>');

      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      store.state.commentsDisabled = true;
      wrapper = mountComponent();
      return waitForPromises();
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('should not render form when commenting is disabled', () => {
      expect(wrapper.find('.js-main-target-form').exists()).toBe(false);
    });

    it('should render discussion filter note `commentsDisabled` is true', () => {
      expect(wrapper.find('.js-discussion-filter-note').exists()).toBe(true);
    });
  });

  describe('timeline view', () => {
    beforeEach(() => {
      setHTMLFixture('<div class="js-discussions-count"></div>');

      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      store.state.commentsDisabled = false;
      store.state.isTimelineEnabled = true;

      wrapper = mountComponent();
      return waitForPromises();
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('should not render comments form', () => {
      expect(wrapper.find('.js-main-target-form').exists()).toBe(false);
    });
  });

  describe('while fetching data', () => {
    beforeEach(async () => {
      setHTMLFixture('<div class="js-discussions-count"></div>');
      wrapper = mountComponent();
    });

    afterEach(() => {
      return waitForPromises().then(() => resetHTMLFixture());
    });

    it('renders skeleton notes', () => {
      expect(wrapper.find('.gl-skeleton-loader-default-container').exists()).toBe(true);
    });

    it('should render form', () => {
      expect(wrapper.find('.js-main-target-form').element.tagName).toBe('FORM');
      expect(wrapper.find('.js-main-target-form textarea').attributes('placeholder')).toEqual(
        'Write a comment or drag your files here…',
      );
    });

    it('should not update discussions badge (it should be blank)', () => {
      expect(document.querySelector('.js-discussions-count').textContent).toEqual('');
    });
  });

  describe('update note', () => {
    describe('individual note', () => {
      beforeEach(() => {
        axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
        wrapper = mountComponent();
        return waitForPromises().then(() => {
          wrapper.find('.js-note-edit').trigger('click');
        });
      });

      it('renders edit form', () => {
        expect(wrapper.find('.js-vue-issue-note-form').exists()).toBe(true);
      });

      it('calls the store action to update the note', () => {
        jest.spyOn(axios, 'put').mockImplementation(() => Promise.resolve({ data: {} }));
        wrapper.find('.js-vue-issue-note-form').value = 'this is a note';
        wrapper.find('.js-vue-issue-save').trigger('click');

        expect(axios.put).toHaveBeenCalled();
      });
    });

    describe('discussion note', () => {
      beforeEach(() => {
        axiosMock.onAny().reply(mockData.getDiscussionNoteResponse);
        wrapper = mountComponent();
        return waitForPromises().then(() => {
          wrapper.find('.js-note-edit').trigger('click');
        });
      });

      it('renders edit form', () => {
        expect(wrapper.find('.js-vue-issue-note-form').exists()).toBe(true);
      });

      it('updates the note and resets the edit form', () => {
        jest.spyOn(axios, 'put').mockImplementation(() => Promise.resolve({ data: {} }));
        wrapper.find('.js-vue-issue-note-form').value = 'this is a note';
        wrapper.find('.js-vue-issue-save').trigger('click');

        expect(axios.put).toHaveBeenCalled();
      });
    });
  });

  describe('new note form', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForPromises();
    });

    it('should render markdown docs url', () => {
      const { markdownDocsPath } = mockData.notesDataMock;

      expect(wrapper.find(`a[href="${markdownDocsPath}"]`).text().trim()).toEqual('Markdown');
    });

    it('should render quick action docs url', () => {
      const { quickActionsDocsPath } = mockData.notesDataMock;

      expect(wrapper.find(`a[href="${quickActionsDocsPath}"]`).text().trim()).toEqual(
        'quick actions',
      );
    });
  });

  describe('edit form', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForPromises();
    });

    it('should render markdown docs url', async () => {
      wrapper.find('.js-note-edit').trigger('click');
      const { markdownDocsPath } = mockData.notesDataMock;

      await nextTick();
      expect(wrapper.find(`.edit-note a[href="${markdownDocsPath}"]`).text().trim()).toEqual(
        'Markdown',
      );
    });

    it('should render quick actions docs url', async () => {
      wrapper.find('.js-note-edit').trigger('click');
      const { quickActionsDocsPath } = mockData.notesDataMock;

      await nextTick();
      expect(wrapper.find(`.edit-note a[href="${quickActionsDocsPath}"]`).text().trim()).toEqual(
        'quick actions',
      );
    });
  });

  describe('emoji awards', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(200, []);
      wrapper = mountComponent();
      return waitForPromises();
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

      jest.advanceTimersByTime(2);

      expect(toggleAwardAction).toHaveBeenCalledTimes(1);
      const [, payload] = toggleAwardAction.mock.calls[0];

      expect(payload).toEqual({
        awardName: 'test',
        noteId: 1,
      });
    });
  });

  describe('mounted', () => {
    beforeEach(() => {
      axiosMock.onAny().reply(mockData.getIndividualNoteResponse);
      wrapper = mountComponent();
      return waitForPromises();
    });

    it('should listen hashchange event', () => {
      const notesApp = wrapper.find(NotesApp);
      const hash = 'some dummy hash';
      jest.spyOn(urlUtility, 'getLocationHash').mockReturnValueOnce(hash);
      const setTargetNoteHash = jest.spyOn(notesApp.vm, 'setTargetNoteHash');

      window.dispatchEvent(new Event('hashchange'), hash);

      expect(setTargetNoteHash).toHaveBeenCalled();
    });
  });

  describe('when sort direction is desc', () => {
    beforeEach(() => {
      store = createStore();
      store.state.discussionSortOrder = constants.DESC;
      store.state.isLoading = true;
      store.state.discussions = [mockData.discussionMock];

      wrapper = shallowMount(NotesApp, {
        propsData,
        store,
        stubs: {
          'ordered-layout': OrderedLayout,
        },
      });
    });

    it('finds CommentForm before notes list', () => {
      expect(getComponentOrder()).toStrictEqual([TYPE_COMMENT_FORM, TYPE_NOTES_LIST]);
    });

    it('shows skeleton notes before the loaded discussions', () => {
      expect(wrapper.find('#notes-list').html()).toMatchSnapshot();
    });
  });

  describe('when sort direction is asc', () => {
    beforeEach(() => {
      store = createStore();
      store.state.isLoading = true;
      store.state.discussions = [mockData.discussionMock];

      wrapper = shallowMount(NotesApp, {
        propsData,
        store,
        stubs: {
          'ordered-layout': OrderedLayout,
        },
      });
    });

    it('finds CommentForm after notes list', () => {
      expect(getComponentOrder()).toStrictEqual([TYPE_NOTES_LIST, TYPE_COMMENT_FORM]);
    });

    it('shows skeleton notes after the loaded discussions', () => {
      expect(wrapper.find('#notes-list').html()).toMatchSnapshot();
    });
  });

  describe('when multiple draft types are present', () => {
    beforeEach(() => {
      store = createStore();
      store.registerModule('batchComments', batchComments());
      store.state.batchComments.drafts = [
        mockData.draftDiffDiscussion,
        mockData.draftReply,
        ...mockData.draftComments,
      ];
      store.state.isLoading = false;
      wrapper = shallowMount(NotesApp, {
        propsData,
        store,
        stubs: {
          OrderedLayout,
        },
      });
    });

    it('correctly finds only draft comments', () => {
      const drafts = wrapper.findAll(DraftNote).wrappers;

      expect(drafts.map((x) => x.props('draft'))).toEqual(
        mockData.draftComments.map(({ note }) => expect.objectContaining({ note })),
      );
    });
  });

  describe('fetching discussions', () => {
    describe('when note anchor is not present', () => {
      it('does not include extra query params', async () => {
        wrapper = shallowMount(NotesApp, { propsData, store: createStore() });
        await waitForPromises();

        expect(axiosMock.history.get[0].params).toEqual({ per_page: 20 });
      });
    });

    describe('when note anchor is present', () => {
      const mountWithNotesFilter = (notesFilter) =>
        shallowMount(NotesApp, {
          propsData: {
            ...propsData,
            notesData: {
              ...propsData.notesData,
              notesFilter,
            },
          },
          store: createStore(),
        });

      beforeEach(() => {
        setWindowLocation('#note_1');
      });

      it('does not include extra query params when filter is undefined', async () => {
        wrapper = mountWithNotesFilter(undefined);
        await waitForPromises();

        expect(axiosMock.history.get[0].params).toEqual({ per_page: 20 });
      });

      it('does not include extra query params when filter is already set to default', async () => {
        wrapper = mountWithNotesFilter(constants.DISCUSSION_FILTERS_DEFAULT_VALUE);
        await waitForPromises();

        expect(axiosMock.history.get[0].params).toEqual({ per_page: 20 });
      });

      it('includes extra query params when filter is not set to default', async () => {
        wrapper = mountWithNotesFilter(constants.COMMENTS_ONLY_FILTER_VALUE);
        await waitForPromises();

        expect(axiosMock.history.get[0].params).toEqual({
          notes_filter: constants.DISCUSSION_FILTERS_DEFAULT_VALUE,
          per_page: 20,
          persist_filter: false,
        });
      });
    });
  });
});

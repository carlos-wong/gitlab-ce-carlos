import { shallowMount, createLocalVue } from '@vue/test-utils';
import '~/behaviors/markdown/render_gfm';
import { SYSTEM_NOTE } from '~/notes/constants';
import DiscussionNotes from '~/notes/components/discussion_notes.vue';
import NoteableNote from '~/notes/components/noteable_note.vue';
import PlaceholderNote from '~/vue_shared/components/notes/placeholder_note.vue';
import PlaceholderSystemNote from '~/vue_shared/components/notes/placeholder_system_note.vue';
import SystemNote from '~/vue_shared/components/notes/system_note.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import createStore from '~/notes/stores';
import { noteableDataMock, discussionMock, notesDataMock } from '../../notes/mock_data';

const localVue = createLocalVue();

describe('DiscussionNotes', () => {
  let wrapper;

  const createComponent = props => {
    const store = createStore();
    store.dispatch('setNoteableData', noteableDataMock);
    store.dispatch('setNotesData', notesDataMock);

    wrapper = shallowMount(DiscussionNotes, {
      localVue,
      store,
      propsData: {
        discussion: discussionMock,
        isExpanded: false,
        shouldGroupReplies: false,
        ...props,
      },
      scopedSlots: {
        footer: '<p slot-scope="{ showReplies }">showReplies:{{showReplies}}</p>',
      },
      slots: {
        'avatar-badge': '<span class="avatar-badge-slot-content" />',
      },
      sync: false,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('rendering', () => {
    it('renders an element for each note in the discussion', () => {
      createComponent();
      const notesCount = discussionMock.notes.length;
      const els = wrapper.findAll(TimelineEntryItem);
      expect(els.length).toBe(notesCount);
    });

    it('renders one element if replies groupping is enabled', () => {
      createComponent({ shouldGroupReplies: true });
      const els = wrapper.findAll(TimelineEntryItem);
      expect(els.length).toBe(1);
    });

    it('uses proper component to render each note type', () => {
      const discussion = { ...discussionMock };
      const notesData = [
        // PlaceholderSystemNote
        {
          id: 1,
          isPlaceholderNote: true,
          placeholderType: SYSTEM_NOTE,
          notes: [{ body: 'PlaceholderSystemNote' }],
        },
        // PlaceholderNote
        {
          id: 2,
          isPlaceholderNote: true,
          notes: [{ body: 'PlaceholderNote' }],
        },
        // SystemNote
        {
          id: 3,
          system: true,
          note: 'SystemNote',
        },
        // NoteableNote
        discussion.notes[0],
      ];
      discussion.notes = notesData;
      createComponent({ discussion, shouldRenderDiffs: true });
      const notes = wrapper.findAll('.notes > li');

      expect(notes.at(0).is(PlaceholderSystemNote)).toBe(true);
      expect(notes.at(1).is(PlaceholderNote)).toBe(true);
      expect(notes.at(2).is(SystemNote)).toBe(true);
      expect(notes.at(3).is(NoteableNote)).toBe(true);
    });

    it('renders footer scoped slot with showReplies === true when expanded', () => {
      createComponent({ isExpanded: true });
      expect(wrapper.text()).toMatch('showReplies:true');
    });

    it('renders footer scoped slot with showReplies === false when collapsed', () => {
      createComponent({ isExpanded: false });
      expect(wrapper.text()).toMatch('showReplies:false');
    });

    it('passes down avatar-badge slot content', () => {
      createComponent();
      expect(wrapper.find('.avatar-badge-slot-content').exists()).toBe(true);
    });
  });

  describe('events', () => {
    describe('with groupped notes and replies expanded', () => {
      const findNoteAtIndex = index => wrapper.find(`.note:nth-of-type(${index + 1}`);

      beforeEach(() => {
        createComponent({ shouldGroupReplies: true, isExpanded: true });
      });

      it('emits deleteNote when first note emits handleDeleteNote', () => {
        findNoteAtIndex(0).vm.$emit('handleDeleteNote');
        expect(wrapper.emitted().deleteNote).toBeTruthy();
      });

      it('emits startReplying when first note emits startReplying', () => {
        findNoteAtIndex(0).vm.$emit('startReplying');
        expect(wrapper.emitted().startReplying).toBeTruthy();
      });

      it('emits deleteNote when second note emits handleDeleteNote', () => {
        findNoteAtIndex(1).vm.$emit('handleDeleteNote');
        expect(wrapper.emitted().deleteNote).toBeTruthy();
      });
    });

    describe('with ungroupped notes', () => {
      let note;
      beforeEach(() => {
        createComponent();
        note = wrapper.find('.note');
      });

      it('emits deleteNote when first note emits handleDeleteNote', () => {
        note.vm.$emit('handleDeleteNote');
        expect(wrapper.emitted().deleteNote).toBeTruthy();
      });
    });
  });

  describe('componentData', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should return first note object for placeholder note', () => {
      const data = {
        isPlaceholderNote: true,
        notes: [{ body: 'hello world!' }],
      };
      const note = wrapper.vm.componentData(data);

      expect(note).toEqual(data.notes[0]);
    });

    it('should return given note for nonplaceholder notes', () => {
      const data = {
        notes: [{ id: 12 }],
      };
      const note = wrapper.vm.componentData(data);

      expect(note).toEqual(data);
    });
  });
});

import { GlLoadingIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { ApolloMutation } from 'vue-apollo';
import { nextTick } from 'vue';
import DesignDiscussion from '~/design_management/components/design_notes/design_discussion.vue';
import DesignNote from '~/design_management/components/design_notes/design_note.vue';
import DesignNoteSignedOut from '~/design_management/components/design_notes/design_note_signed_out.vue';
import DesignReplyForm from '~/design_management/components/design_notes/design_reply_form.vue';
import ToggleRepliesWidget from '~/design_management/components/design_notes/toggle_replies_widget.vue';
import createNoteMutation from '~/design_management/graphql/mutations/create_note.mutation.graphql';
import toggleResolveDiscussionMutation from '~/design_management/graphql/mutations/toggle_resolve_discussion.mutation.graphql';
import ReplyPlaceholder from '~/notes/components/discussion_reply_placeholder.vue';
import mockDiscussion from '../../mock_data/discussion';
import notes from '../../mock_data/notes';

const defaultMockDiscussion = {
  id: '0',
  resolved: false,
  resolvable: true,
  notes,
};

const DEFAULT_TODO_COUNT = 2;

describe('Design discussions component', () => {
  const originalGon = window.gon;
  let wrapper;

  const findDesignNotes = () => wrapper.findAll(DesignNote);
  const findReplyPlaceholder = () => wrapper.find(ReplyPlaceholder);
  const findReplyForm = () => wrapper.find(DesignReplyForm);
  const findRepliesWidget = () => wrapper.find(ToggleRepliesWidget);
  const findResolveButton = () => wrapper.find('[data-testid="resolve-button"]');
  const findResolvedMessage = () => wrapper.find('[data-testid="resolved-message"]');
  const findResolveLoadingIcon = () => wrapper.find(GlLoadingIcon);
  const findResolveCheckbox = () => wrapper.find('[data-testid="resolve-checkbox"]');
  const findApolloMutation = () => wrapper.findComponent(ApolloMutation);

  const mutationVariables = {
    mutation: createNoteMutation,
    variables: {
      input: {
        noteableId: 'noteable-id',
        body: 'test',
        discussionId: '0',
      },
    },
  };
  const registerPath = '/users/sign_up?redirect_to_referer=yes';
  const signInPath = '/users/sign_in?redirect_to_referer=yes';
  const mutate = jest.fn().mockResolvedValue({ data: { createNote: { errors: [] } } });
  const readQuery = jest.fn().mockReturnValue({
    project: {
      issue: { designCollection: { designs: { nodes: [{ currentUserTodos: { nodes: [] } }] } } },
    },
  });
  const $apollo = {
    mutate,
    provider: { clients: { defaultClient: { readQuery } } },
  };

  function createComponent(props = {}, data = {}) {
    wrapper = mount(DesignDiscussion, {
      propsData: {
        resolvedDiscussionsExpanded: true,
        discussion: defaultMockDiscussion,
        noteableId: 'noteable-id',
        designId: 'design-id',
        discussionIndex: 1,
        discussionWithOpenForm: '',
        registerPath,
        signInPath,
        ...props,
      },
      data() {
        return {
          ...data,
        };
      },
      provide: {
        projectPath: 'project-path',
        issueIid: '1',
      },
      mocks: {
        $apollo,
        $route: {
          hash: '#note_1',
          params: {
            id: 1,
          },
          query: {
            version: null,
          },
        },
      },
    });
  }

  beforeEach(() => {
    window.gon = { current_user_id: 1 };
  });

  afterEach(() => {
    wrapper.destroy();
    window.gon = originalGon;
  });

  describe('when discussion is not resolvable', () => {
    beforeEach(() => {
      createComponent({
        discussion: {
          ...defaultMockDiscussion,
          resolvable: false,
        },
      });
    });

    it('does not render an icon to resolve a thread', () => {
      expect(findResolveButton().exists()).toBe(false);
    });

    it('does not render a checkbox in reply form', async () => {
      findReplyPlaceholder().vm.$emit('focus');

      await nextTick();
      expect(findResolveCheckbox().exists()).toBe(false);
    });
  });

  describe('when discussion is unresolved', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct amount of discussion notes', () => {
      expect(findDesignNotes()).toHaveLength(2);
      expect(findDesignNotes().wrappers.every((w) => w.isVisible())).toBe(true);
    });

    it('renders reply placeholder', () => {
      expect(findReplyPlaceholder().isVisible()).toBe(true);
    });

    it('does not render toggle replies widget', () => {
      expect(findRepliesWidget().exists()).toBe(false);
    });

    it('renders a correct icon to resolve a thread', () => {
      expect(findResolveButton().props('icon')).toBe('check-circle');
    });

    it('renders a checkbox with Resolve thread text in reply form', async () => {
      findReplyPlaceholder().vm.$emit('focus');
      wrapper.setProps({ discussionWithOpenForm: defaultMockDiscussion.id });

      await nextTick();
      expect(findResolveCheckbox().text()).toBe('Resolve thread');
    });

    it('does not render resolved message', () => {
      expect(findResolvedMessage().exists()).toBe(false);
    });
  });

  describe('when discussion is resolved', () => {
    let dispatchEventSpy;

    beforeEach(() => {
      dispatchEventSpy = jest.spyOn(document, 'dispatchEvent');
      jest.spyOn(document, 'querySelector').mockReturnValue({
        innerText: DEFAULT_TODO_COUNT,
      });
      createComponent({
        discussion: {
          ...defaultMockDiscussion,
          resolved: true,
          resolvedBy: notes[0].author,
          resolvedAt: '2020-05-08T07:10:45Z',
        },
      });
    });

    it('shows only the first note', () => {
      expect(findDesignNotes().at(0).isVisible()).toBe(true);
      expect(findDesignNotes().at(1).isVisible()).toBe(false);
    });

    it('renders resolved message', () => {
      expect(findResolvedMessage().exists()).toBe(true);
    });

    it('does not show renders reply placeholder', () => {
      expect(findReplyPlaceholder().isVisible()).toBe(false);
    });

    it('renders toggle replies widget with correct props', () => {
      expect(findRepliesWidget().exists()).toBe(true);
      expect(findRepliesWidget().props()).toEqual({
        collapsed: true,
        replies: notes.slice(1),
      });
    });

    it('renders a correct icon to resolve a thread', () => {
      expect(findResolveButton().props('icon')).toBe('check-circle-filled');
    });

    it('emit todo:toggle when discussion is resolved', async () => {
      createComponent(
        { discussionWithOpenForm: defaultMockDiscussion.id },
        { discussionComment: 'test', isFormRendered: true },
      );
      findResolveButton().trigger('click');
      findReplyForm().vm.$emit('submitForm');

      await mutate();
      await nextTick();

      const dispatchedEvent = dispatchEventSpy.mock.calls[0][0];

      expect(dispatchEventSpy).toHaveBeenCalledTimes(1);
      expect(dispatchedEvent.detail).toEqual({ count: DEFAULT_TODO_COUNT });
      expect(dispatchedEvent.type).toBe('todo:toggle');
    });

    describe('when replies are expanded', () => {
      beforeEach(async () => {
        findRepliesWidget().vm.$emit('toggle');
        await nextTick();
      });

      it('renders replies widget with collapsed prop equal to false', () => {
        expect(findRepliesWidget().props('collapsed')).toBe(false);
      });

      it('renders the second note', () => {
        expect(findDesignNotes().at(1).isVisible()).toBe(true);
      });

      it('renders a reply placeholder', () => {
        expect(findReplyPlaceholder().isVisible()).toBe(true);
      });

      it('renders a checkbox with Unresolve thread text in reply form', async () => {
        findReplyPlaceholder().vm.$emit('focus');
        wrapper.setProps({ discussionWithOpenForm: defaultMockDiscussion.id });

        await nextTick();
        expect(findResolveCheckbox().text()).toBe('Unresolve thread');
      });
    });
  });

  it('hides reply placeholder and opens form on placeholder click', async () => {
    createComponent();
    findReplyPlaceholder().vm.$emit('focus');
    wrapper.setProps({ discussionWithOpenForm: defaultMockDiscussion.id });

    await nextTick();
    expect(findReplyPlaceholder().exists()).toBe(false);
    expect(findReplyForm().exists()).toBe(true);
  });

  it('calls mutation on submitting form and closes the form', async () => {
    createComponent(
      { discussionWithOpenForm: defaultMockDiscussion.id },
      { discussionComment: 'test', isFormRendered: true },
    );

    findReplyForm().vm.$emit('submit-form');
    expect(mutate).toHaveBeenCalledWith(mutationVariables);

    await mutate();
    await nextTick();

    expect(findReplyForm().exists()).toBe(false);
  });

  it('clears the discussion comment on closing comment form', async () => {
    createComponent(
      { discussionWithOpenForm: defaultMockDiscussion.id },
      { discussionComment: 'test', isFormRendered: true },
    );

    await nextTick();
    findReplyForm().vm.$emit('cancel-form');

    expect(wrapper.vm.discussionComment).toBe('');

    await nextTick();
    expect(findReplyForm().exists()).toBe(false);
  });

  describe('when any note from a discussion is active', () => {
    it.each([notes[0], notes[0].discussion.notes.nodes[1]])(
      'applies correct class to all notes in the active discussion',
      (note) => {
        createComponent(
          { discussion: mockDiscussion },
          {
            activeDiscussion: {
              id: note.id,
              source: 'pin',
            },
          },
        );

        expect(
          wrapper
            .findAll(DesignNote)
            .wrappers.every((designNote) => designNote.classes('gl-bg-blue-50')),
        ).toBe(true);
      },
    );
  });

  it('calls toggleResolveDiscussion mutation on resolve thread button click', async () => {
    createComponent();
    findResolveButton().trigger('click');
    expect(mutate).toHaveBeenCalledWith({
      mutation: toggleResolveDiscussionMutation,
      variables: {
        id: defaultMockDiscussion.id,
        resolve: true,
      },
    });
    await nextTick();
    expect(findResolveLoadingIcon().exists()).toBe(true);
  });

  it('calls toggleResolveDiscussion mutation after adding a note if checkbox was checked', () => {
    createComponent(
      { discussionWithOpenForm: defaultMockDiscussion.id },
      { discussionComment: 'test', isFormRendered: true },
    );
    findResolveButton().trigger('click');
    findReplyForm().vm.$emit('submitForm');

    return mutate().then(() => {
      expect(mutate).toHaveBeenCalledWith({
        mutation: toggleResolveDiscussionMutation,
        variables: {
          id: defaultMockDiscussion.id,
          resolve: true,
        },
      });
    });
  });

  it('emits openForm event on opening the form', () => {
    createComponent();
    findReplyPlaceholder().vm.$emit('focus');

    expect(wrapper.emitted('open-form')).toBeTruthy();
  });

  describe('when user is not logged in', () => {
    const findDesignNoteSignedOut = () => wrapper.findComponent(DesignNoteSignedOut);

    beforeEach(() => {
      window.gon = { current_user_id: null };
      createComponent(
        {
          discussion: {
            ...defaultMockDiscussion,
          },
          discussionWithOpenForm: defaultMockDiscussion.id,
        },
        { discussionComment: 'test', isFormRendered: true },
      );
    });

    it('does not render resolve discussion button', () => {
      expect(findResolveButton().exists()).toBe(false);
    });

    it('does not render replace-placeholder component', () => {
      expect(findReplyPlaceholder().exists()).toBe(false);
    });

    it('does not render apollo-mutation component', () => {
      expect(findApolloMutation().exists()).toBe(false);
    });

    it('renders design-note-signed-out component', () => {
      expect(findDesignNoteSignedOut().exists()).toBe(true);
      expect(findDesignNoteSignedOut().props()).toMatchObject({
        registerPath,
        signInPath,
      });
    });
  });
});

import { BubbleMenu } from '@tiptap/vue-2';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FormattingBubbleMenu from '~/content_editor/components/bubble_menus/formatting.vue';

import {
  BUBBLE_MENU_TRACKING_ACTION,
  CONTENT_EDITOR_TRACKING_LABEL,
} from '~/content_editor/constants';
import { createTestEditor } from '../../test_utils';

describe('content_editor/components/bubble_menus/formatting', () => {
  let wrapper;
  let trackingSpy;
  let tiptapEditor;

  const buildEditor = () => {
    tiptapEditor = createTestEditor();

    jest.spyOn(tiptapEditor, 'isActive');
  };

  const buildWrapper = () => {
    wrapper = shallowMountExtended(FormattingBubbleMenu, {
      provide: {
        tiptapEditor,
      },
    });
  };

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, null, jest.spyOn);
    buildEditor();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders bubble menu component', () => {
    buildWrapper();
    const bubbleMenu = wrapper.findComponent(BubbleMenu);

    expect(bubbleMenu.props().editor).toBe(tiptapEditor);
    expect(bubbleMenu.classes()).toEqual(['gl-shadow', 'gl-rounded-base', 'gl-bg-white']);
  });

  describe.each`
    testId           | controlProps
    ${'bold'}        | ${{ contentType: 'bold', iconName: 'bold', label: 'Bold text', editorCommand: 'toggleBold' }}
    ${'italic'}      | ${{ contentType: 'italic', iconName: 'italic', label: 'Italic text', editorCommand: 'toggleItalic' }}
    ${'strike'}      | ${{ contentType: 'strike', iconName: 'strikethrough', label: 'Strikethrough', editorCommand: 'toggleStrike' }}
    ${'code'}        | ${{ contentType: 'code', iconName: 'code', label: 'Code', editorCommand: 'toggleCode' }}
    ${'superscript'} | ${{ contentType: 'superscript', iconName: 'superscript', label: 'Superscript', editorCommand: 'toggleSuperscript' }}
    ${'subscript'}   | ${{ contentType: 'subscript', iconName: 'subscript', label: 'Subscript', editorCommand: 'toggleSubscript' }}
    ${'link'}        | ${{ contentType: 'link', iconName: 'link', label: 'Insert link', editorCommand: 'toggleLink', editorCommandParams: { href: '' } }}
  `('given a $testId toolbar control', ({ testId, controlProps }) => {
    beforeEach(() => {
      buildWrapper();
    });

    it('renders the toolbar control with the provided properties', () => {
      expect(wrapper.findByTestId(testId).exists()).toBe(true);

      expect(wrapper.findByTestId(testId).props()).toEqual(
        expect.objectContaining({
          ...controlProps,
          size: 'medium',
          category: 'tertiary',
        }),
      );
    });

    it('tracks the execution of toolbar controls', () => {
      const eventData = { contentType: 'italic', value: 1 };
      const { contentType, value } = eventData;

      wrapper.findByTestId(testId).vm.$emit('execute', eventData);

      expect(trackingSpy).toHaveBeenCalledWith(undefined, BUBBLE_MENU_TRACKING_ACTION, {
        label: CONTENT_EDITOR_TRACKING_LABEL,
        property: contentType,
        value,
      });
    });
  });
});

import $ from 'jquery';
import axios from '~/lib/utils/axios_utils';
import initGFMInput from '~/behaviors/markdown/gfm_auto_complete';
import initDeprecatedNotes from '~/init_deprecated_notes';
import { loadHTMLFixture } from 'helpers/fixtures';

describe('Integration Snippets notes', () => {
  beforeEach(async () => {
    loadHTMLFixture('snippets/show.html');

    // Check if we have to Load GFM Input
    const $gfmInputs = $('.js-gfm-input:not(.js-gfm-input-initialized)');
    initGFMInput($gfmInputs);

    initDeprecatedNotes();
  });

  describe('emoji autocomplete', () => {
    const findNoteTextarea = () => document.getElementById('note_note');
    const findAtViewEmojiMenu = () => document.getElementById('at-view-58');
    const findAtwhoResult = () => {
      return Array.from(findAtViewEmojiMenu().querySelectorAll('li')).map((x) =>
        x.innerText.trim(),
      );
    };
    const fillNoteTextarea = (val) => {
      const textarea = findNoteTextarea();

      textarea.dispatchEvent(new Event('focus'));
      textarea.value = val;
      textarea.dispatchEvent(new Event('input'));
      textarea.dispatchEvent(new Event('click'));
    };

    it.each([
      [
        ':heart',
        ['heart', 'heart decoration', 'heart with arrow', 'heart with ribbon', 'heart_exclamation'],
      ],
      [':red', ['red apple', 'red_car', 'red_circle', 'credit card', 'tired face']],
      [
        ':circle',
        // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/347549
        // These autocompleted results aren't very good. The autocompletion should be improved.
        [
          'circled ideograph accept',
          'circled ideograph advantage',
          'circled ideograph congratulation',
          'circled ideograph secret',
          'circled latin capital letter m',
        ],
      ],
    ])('shows a correct list of matching emojis when user enters %s', async (input, expected) => {
      fillNoteTextarea(input);

      await axios.waitForAll();

      const result = findAtwhoResult();
      expect(result).toEqual(expected);
    });
  });
});

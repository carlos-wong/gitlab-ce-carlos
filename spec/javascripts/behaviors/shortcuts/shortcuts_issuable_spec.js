/* eslint-disable
  no-underscore-dangle
*/

import $ from 'jquery';
import initCopyAsGFM, { CopyAsGFM } from '~/behaviors/markdown/copy_as_gfm';
import ShortcutsIssuable from '~/behaviors/shortcuts/shortcuts_issuable';

const FORM_SELECTOR = '.js-main-target-form .js-vue-comment-form';

describe('ShortcutsIssuable', function() {
  const fixtureName = 'snippets/show.html';
  preloadFixtures(fixtureName);

  beforeAll(done => {
    initCopyAsGFM();

    // Fake call to nodeToGfm so the import of lazy bundle happened
    CopyAsGFM.nodeToGFM(document.createElement('div'))
      .then(() => {
        done();
      })
      .catch(done.fail);
  });

  beforeEach(() => {
    loadFixtures(fixtureName);
    $('body').append(
      `<div class="js-main-target-form">
        <textare class="js-vue-comment-form"></textare>
      </div>`,
    );
    document.querySelector('.js-new-note-form').classList.add('js-main-target-form');
    this.shortcut = new ShortcutsIssuable(true);
  });

  afterEach(() => {
    $(FORM_SELECTOR).remove();
  });

  describe('replyWithSelectedText', () => {
    // Stub window.gl.utils.getSelectedFragment to return a node with the provided HTML.
    const stubSelection = (html, invalidNode) => {
      ShortcutsIssuable.__Rewire__('getSelectedFragment', () => {
        const documentFragment = document.createDocumentFragment();
        const node = document.createElement('div');

        node.innerHTML = html;
        if (!invalidNode) node.className = 'md';

        documentFragment.appendChild(node);
        return documentFragment;
      });
    };

    describe('with empty selection', () => {
      it('does not return an error', () => {
        ShortcutsIssuable.replyWithSelectedText(true);

        expect($(FORM_SELECTOR).val()).toBe('');
      });

      it('triggers `focus`', () => {
        const spy = spyOn(document.querySelector(FORM_SELECTOR), 'focus');
        ShortcutsIssuable.replyWithSelectedText(true);

        expect(spy).toHaveBeenCalled();
      });
    });

    describe('with any selection', () => {
      beforeEach(() => {
        stubSelection('<p>Selected text.</p>');
      });

      it('leaves existing input intact', done => {
        $(FORM_SELECTOR).val('This text was already here.');

        expect($(FORM_SELECTOR).val()).toBe('This text was already here.');

        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe(
            'This text was already here.\n\n> Selected text.\n\n',
          );
          done();
        });
      });

      it('triggers `input`', done => {
        let triggered = false;
        $(FORM_SELECTOR).on('input', () => {
          triggered = true;
        });

        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(triggered).toBe(true);
          done();
        });
      });

      it('triggers `focus`', done => {
        const spy = spyOn(document.querySelector(FORM_SELECTOR), 'focus');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(spy).toHaveBeenCalled();
          done();
        });
      });
    });

    describe('with a one-line selection', () => {
      it('quotes the selection', done => {
        stubSelection('<p>This text has been selected.</p>');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe('> This text has been selected.\n\n');
          done();
        });
      });
    });

    describe('with a multi-line selection', () => {
      it('quotes the selected lines as a group', done => {
        stubSelection(
          '<p>Selected line one.</p>\n<p>Selected line two.</p>\n<p>Selected line three.</p>',
        );
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe(
            '> Selected line one.\n>\n> Selected line two.\n>\n> Selected line three.\n\n',
          );
          done();
        });
      });
    });

    describe('with an invalid selection', () => {
      beforeEach(() => {
        stubSelection('<p>Selected text.</p>', true);
      });

      it('does not add anything to the input', done => {
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe('');
          done();
        });
      });

      it('triggers `focus`', done => {
        const spy = spyOn(document.querySelector(FORM_SELECTOR), 'focus');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(spy).toHaveBeenCalled();
          done();
        });
      });
    });

    describe('with a semi-valid selection', () => {
      beforeEach(() => {
        stubSelection('<div class="md">Selected text.</div><p>Invalid selected text.</p>', true);
      });

      it('only adds the valid part to the input', done => {
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe('> Selected text.\n\n');
          done();
        });
      });

      it('triggers `focus`', done => {
        const spy = spyOn(document.querySelector(FORM_SELECTOR), 'focus');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(spy).toHaveBeenCalled();
          done();
        });
      });

      it('triggers `input`', done => {
        let triggered = false;
        $(FORM_SELECTOR).on('input', () => {
          triggered = true;
        });

        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(triggered).toBe(true);
          done();
        });
      });
    });

    describe('with a selection in a valid block', () => {
      beforeEach(() => {
        ShortcutsIssuable.__Rewire__('getSelectedFragment', () => {
          const documentFragment = document.createDocumentFragment();
          const node = document.createElement('div');
          const originalNode = document.createElement('body');
          originalNode.innerHTML = `<div class="issue">
            <div class="otherElem">Text...</div>
            <div class="md"><p><em>Selected text.</em></p></div>
          </div>`;
          documentFragment.originalNodes = [originalNode.querySelector('em')];

          node.innerHTML = '<em>Selected text.</em>';

          documentFragment.appendChild(node);

          return documentFragment;
        });
      });

      it('adds the quoted selection to the input', done => {
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe('> *Selected text.*\n\n');
          done();
        });
      });

      it('triggers `focus`', done => {
        const spy = spyOn(document.querySelector(FORM_SELECTOR), 'focus');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(spy).toHaveBeenCalled();
          done();
        });
      });

      it('triggers `input`', done => {
        let triggered = false;
        $(FORM_SELECTOR).on('input', () => {
          triggered = true;
        });

        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(triggered).toBe(true);
          done();
        });
      });
    });

    describe('with a selection in an invalid block', () => {
      beforeEach(() => {
        ShortcutsIssuable.__Rewire__('getSelectedFragment', () => {
          const documentFragment = document.createDocumentFragment();
          const node = document.createElement('div');
          const originalNode = document.createElement('body');
          originalNode.innerHTML = `<div class="issue">
            <div class="otherElem"><div><b>Selected text.</b></div></div>
            <div class="md"><p><em>Valid text</em></p></div>
          </div>`;
          documentFragment.originalNodes = [originalNode.querySelector('b')];

          node.innerHTML = '<b>Selected text.</b>';

          documentFragment.appendChild(node);

          return documentFragment;
        });
      });

      it('does not add anything to the input', done => {
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe('');
          done();
        });
      });

      it('triggers `focus`', done => {
        const spy = spyOn(document.querySelector(FORM_SELECTOR), 'focus');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect(spy).toHaveBeenCalled();
          done();
        });
      });
    });

    describe('with a valid selection with no text content', () => {
      it('returns the proper markdown', done => {
        stubSelection('<img src="foo" alt="image" />');
        ShortcutsIssuable.replyWithSelectedText(true);

        setTimeout(() => {
          expect($(FORM_SELECTOR).val()).toBe('> ![image](http://localhost:9876/foo)\n\n');

          done();
        });
      });
    });
  });
});

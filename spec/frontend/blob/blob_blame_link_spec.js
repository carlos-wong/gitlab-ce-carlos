import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import addBlameLink from '~/blob/blob_blame_link';

describe('Blob links', () => {
  const mouseoverEvent = new MouseEvent('mouseover', {
    view: window,
    bubbles: true,
    cancelable: true,
  });

  beforeEach(() => {
    setHTMLFixture(`
    <div id="blob-content-holder">
      <div class="line-numbers" data-blame-path="/blamePath">
        <a id="L5" href="#L5" data-line-number="5" class="file-line-num js-line-links">5</a>
      </div>
      <pre id="LC5">Line 5 content</pre>
    </div>
    `);

    addBlameLink('#blob-content-holder', 'js-line-links');
    document.querySelector('.file-line-num').dispatchEvent(mouseoverEvent);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('adds wrapper elements with correct classes', () => {
    const wrapper = document.querySelector('.line-links');

    expect(wrapper).toBeTruthy();
    expect(wrapper.classList).toContain('diff-line-num');
  });

  it('adds blame link with correct classes and path', () => {
    const blameLink = document.querySelector('.file-line-blame');
    expect(blameLink).toBeTruthy();
    expect(blameLink.getAttribute('href')).toBe('/blamePath#L5');
  });

  it('adds line link within wraper with correct classes and path', () => {
    const lineLink = document.querySelector('.file-line-num');
    expect(lineLink).toBeTruthy();
    expect(lineLink.getAttribute('href')).toBe('#L5');
  });
});

import * as createDefaultClient from '~/lib/graphql';
import { setHTMLFixture } from '../helpers/fixtures';
import initMRPopovers from '~/mr_popover/index';

createDefaultClient.default = jest.fn();

describe('initMRPopovers', () => {
  let mr1;
  let mr2;

  beforeEach(() => {
    setHTMLFixture(`
      <div id="one" class="gfm-merge_request">MR1</div>
      <div id="two" class="gfm-merge_request">MR2</div>
    `);

    mr1 = document.querySelector('#one');
    mr2 = document.querySelector('#two');

    mr1.addEventListener = jest.fn();
    mr2.addEventListener = jest.fn();
  });

  it('does not add the same event listener twice', () => {
    initMRPopovers([mr1, mr1, mr2]);

    expect(mr1.addEventListener).toHaveBeenCalledTimes(1);
    expect(mr2.addEventListener).toHaveBeenCalledTimes(1);
  });
});

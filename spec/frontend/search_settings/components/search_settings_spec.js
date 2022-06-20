import { GlSearchBoxByType } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { setHTMLFixture } from 'helpers/fixtures';
import SearchSettings from '~/search_settings/components/search_settings.vue';
import { HIGHLIGHT_CLASS, HIDE_CLASS } from '~/search_settings/constants';
import { isExpanded, expandSection, closeSection } from '~/settings_panels';

describe('search_settings/components/search_settings.vue', () => {
  const ROOT_ID = 'content-body';
  const SECTION_SELECTOR = 'section.settings';
  const SEARCH_TERM = 'Delete project';
  const GENERAL_SETTINGS_ID = 'js-general-settings';
  const ADVANCED_SETTINGS_ID = 'js-advanced-settings';
  const EXTRA_SETTINGS_ID = 'js-extra-settings';
  const TEXT_CONTAIN_SEARCH_TERM = `This text contain ${SEARCH_TERM}.`;
  const TEXT_WITH_SIBLING_ELEMENTS = `${SEARCH_TERM} <a data-testid="sibling" href="#">Learn more</a>.`;

  let wrapper;

  const buildWrapper = () => {
    wrapper = shallowMount(SearchSettings, {
      propsData: {
        searchRoot: document.querySelector(`#${ROOT_ID}`),
        sectionSelector: SECTION_SELECTOR,
        isExpandedFn: isExpanded,
      },
      // Add real listeners so we can simplify and strengthen some tests.
      listeners: {
        expand: expandSection,
        collapse: closeSection,
      },
    });
  };
  const sections = () => Array.from(document.querySelectorAll(SECTION_SELECTOR));
  const sectionsCount = () => sections().length;
  const visibleSectionsCount = () =>
    document.querySelectorAll(`${SECTION_SELECTOR}:not(.${HIDE_CLASS})`).length;
  const highlightedElementsCount = () => document.querySelectorAll(`.${HIGHLIGHT_CLASS}`).length;

  const highlightedTextNodes = () => {
    const highlightedList = Array.from(document.querySelectorAll(`.${HIGHLIGHT_CLASS}`));
    return highlightedList.every((element) => {
      return element.textContent.toLowerCase() === SEARCH_TERM.toLowerCase();
    });
  };

  const findMatchSiblingElement = () => document.querySelector(`[data-testid="sibling"]`);
  const findSearchBox = () => wrapper.find(GlSearchBoxByType);
  const search = (term) => {
    findSearchBox().vm.$emit('input', term);
  };
  const clearSearch = () => search('');

  beforeEach(() => {
    setHTMLFixture(`
    <div>
      <div class="js-search-app"></div>
      <div id="${ROOT_ID}">
        <section id="${GENERAL_SETTINGS_ID}" class="settings">
          <span>General</span>
        </section>
        <section id="${ADVANCED_SETTINGS_ID}" class="settings expanded">
          <span>Advanced</span>
        </section>
        <section id="${EXTRA_SETTINGS_ID}" class="settings">
          <span>${SEARCH_TERM}</span>
          <span>${TEXT_CONTAIN_SEARCH_TERM}</span>
          <span>${TEXT_WITH_SIBLING_ELEMENTS}</span>
        </section>
      </div>
    </div>
    `);
    buildWrapper();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('hides sections that do not match the search term', () => {
    const hiddenSection = document.querySelector(`#${GENERAL_SETTINGS_ID}`);
    search(SEARCH_TERM);

    expect(visibleSectionsCount()).toBe(1);
    expect(hiddenSection.classList).toContain(HIDE_CLASS);
  });

  it('expands section that matches the search term', () => {
    const section = document.querySelector(`#${EXTRA_SETTINGS_ID}`);

    search(SEARCH_TERM);

    expect(wrapper.emitted('expand')).toEqual([[section]]);
  });

  it('highlight elements that match the search term', () => {
    search(SEARCH_TERM);

    expect(highlightedElementsCount()).toBe(3);
  });

  it('highlight only search term and not the whole line', () => {
    search(SEARCH_TERM);

    expect(highlightedTextNodes()).toBe(true);
  });

  // Regression test for https://gitlab.com/gitlab-org/gitlab/-/issues/350494
  it('preserves elements that are siblings of matches', () => {
    const snapshot = `
      <a
        data-testid="sibling"
        href="#"
      >
        Learn more
      </a>
      `;

    expect(findMatchSiblingElement()).toMatchInlineSnapshot(snapshot);

    search(SEARCH_TERM);

    expect(findMatchSiblingElement()).toMatchInlineSnapshot(snapshot);

    clearSearch();

    expect(findMatchSiblingElement()).toMatchInlineSnapshot(snapshot);
  });

  describe('default', () => {
    it('test setup starts with expansion state', () => {
      expect(sections().map(isExpanded)).toEqual([false, true, false]);
    });

    describe('when searched and cleared', () => {
      beforeEach(() => {
        search('Test');
        clearSearch();
      });

      it('displays all sections', () => {
        expect(visibleSectionsCount()).toBe(sectionsCount());
      });

      it('removes the highlight from all elements', () => {
        expect(highlightedElementsCount()).toBe(0);
      });

      it('should preserve original expansion state', () => {
        expect(sections().map(isExpanded)).toEqual([false, true, false]);
      });

      it('should preserve state by emitting events', () => {
        const [first, mid, last] = sections();

        expect(wrapper.emitted()).toEqual({
          expand: [[mid]],
          collapse: [[first], [last]],
        });
      });

      describe('after multiple searches and clear', () => {
        beforeEach(() => {
          search('Test');
          search(SEARCH_TERM);
          clearSearch();
        });

        it('should preserve last expansion state', () => {
          expect(sections().map(isExpanded)).toEqual([false, true, false]);
        });
      });

      describe('after user expands and collapses, search, and clear', () => {
        beforeEach(() => {
          const [first, mid] = sections();
          closeSection(mid);
          expandSection(first);

          search(SEARCH_TERM);
          clearSearch();
        });

        it('should preserve last expansion state', () => {
          expect(sections().map(isExpanded)).toEqual([true, false, false]);
        });
      });
    });
  });
});

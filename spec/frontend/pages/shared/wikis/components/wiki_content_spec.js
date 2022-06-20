import { GlSkeletonLoader, GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import WikiContent from '~/pages/shared/wikis/components/wiki_content.vue';
import { renderGFM } from '~/pages/shared/wikis/render_gfm_facade';
import axios from '~/lib/utils/axios_utils';
import httpStatus from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/pages/shared/wikis/render_gfm_facade');

describe('pages/shared/wikis/components/wiki_content', () => {
  const PATH = '/test';
  let wrapper;
  let mock;

  function buildWrapper(propsData = {}) {
    wrapper = shallowMount(WikiContent, {
      propsData: { getWikiContentUrl: PATH, ...propsData },
      stubs: {
        GlSkeletonLoader,
        GlAlert,
      },
    });
  }

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findGlSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findContent = () => wrapper.find('[data-testid="wiki_page_content"]');

  describe('when loading content', () => {
    beforeEach(() => {
      buildWrapper();
    });

    it('renders skeleton loader', () => {
      expect(findGlSkeletonLoader().exists()).toBe(true);
    });

    it('does not render content container or error alert', () => {
      expect(findGlAlert().exists()).toBe(false);
      expect(findContent().exists()).toBe(false);
    });
  });

  describe('when content loads successfully', () => {
    const content = 'content';

    beforeEach(() => {
      mock.onGet(PATH, { params: { render_html: true } }).replyOnce(httpStatus.OK, { content });
      buildWrapper();
      return waitForPromises();
    });

    it('renders content container', () => {
      expect(findContent().text()).toBe(content);
    });

    it('does not render skeleton loader or error alert', () => {
      expect(findGlAlert().exists()).toBe(false);
      expect(findGlSkeletonLoader().exists()).toBe(false);
    });

    it('calls renderGFM after nextTick', async () => {
      await nextTick();

      expect(renderGFM).toHaveBeenCalledWith(wrapper.element);
    });
  });

  describe('when loading content fails', () => {
    beforeEach(() => {
      mock.onGet(PATH).replyOnce(httpStatus.INTERNAL_SERVER_ERROR, '');
      buildWrapper();
      return waitForPromises();
    });

    it('renders error alert', () => {
      expect(findGlAlert().exists()).toBe(true);
    });

    it('does not render skeleton loader or content container', () => {
      expect(findContent().exists()).toBe(false);
      expect(findGlSkeletonLoader().exists()).toBe(false);
    });
  });
});

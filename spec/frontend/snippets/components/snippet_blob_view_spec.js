import { mount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import SnippetBlobView from '~/snippets/components/snippet_blob_view.vue';
import BlobHeader from '~/blob/components/blob_header.vue';
import BlobEmbeddable from '~/blob/components/blob_embeddable.vue';
import BlobContent from '~/blob/components/blob_content.vue';
import { RichViewer, SimpleViewer } from '~/vue_shared/components/blob_viewers';
import {
  SNIPPET_VISIBILITY_PRIVATE,
  SNIPPET_VISIBILITY_INTERNAL,
  SNIPPET_VISIBILITY_PUBLIC,
} from '~/snippets/constants';

import { Blob as BlobMock, SimpleViewerMock, RichViewerMock } from 'jest/blob/components/mock_data';

describe('Blob Embeddable', () => {
  let wrapper;
  const snippet = {
    id: 'gid://foo.bar/snippet',
    webUrl: 'https://foo.bar',
    visibilityLevel: SNIPPET_VISIBILITY_PUBLIC,
  };
  const dataMock = {
    blob: BlobMock,
    activeViewerType: SimpleViewerMock.type,
  };

  function createComponent(
    props = {},
    data = dataMock,
    blobLoading = false,
    contentLoading = false,
  ) {
    const $apollo = {
      queries: {
        blob: {
          loading: blobLoading,
        },
        blobContent: {
          loading: contentLoading,
        },
      },
    };

    wrapper = mount(SnippetBlobView, {
      propsData: {
        snippet: {
          ...snippet,
          ...props,
        },
      },
      data() {
        return {
          ...data,
        };
      },
      mocks: { $apollo },
    });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  describe('rendering', () => {
    it('renders correct components', () => {
      createComponent();
      expect(wrapper.find(BlobEmbeddable).exists()).toBe(true);
      expect(wrapper.find(BlobHeader).exists()).toBe(true);
      expect(wrapper.find(BlobContent).exists()).toBe(true);
    });

    it.each([SNIPPET_VISIBILITY_INTERNAL, SNIPPET_VISIBILITY_PRIVATE, 'foo'])(
      'does not render blob-embeddable by default',
      visibilityLevel => {
        createComponent({
          visibilityLevel,
        });
        expect(wrapper.find(BlobEmbeddable).exists()).toBe(false);
      },
    );

    it('does render blob-embeddable for public snippet', () => {
      createComponent({
        visibilityLevel: SNIPPET_VISIBILITY_PUBLIC,
      });
      expect(wrapper.find(BlobEmbeddable).exists()).toBe(true);
    });

    it('shows loading icon while blob data is in flight', () => {
      createComponent({}, dataMock, true);
      expect(wrapper.find(GlLoadingIcon).exists()).toBe(true);
      expect(wrapper.find('.snippet-file-content').exists()).toBe(false);
    });

    it('sets simple viewer correctly', () => {
      createComponent();
      expect(wrapper.find(SimpleViewer).exists()).toBe(true);
    });

    it('sets rich viewer correctly', () => {
      const data = Object.assign({}, dataMock, {
        activeViewerType: RichViewerMock.type,
      });
      createComponent({}, data);
      expect(wrapper.find(RichViewer).exists()).toBe(true);
    });

    it('correctly switches viewer type', () => {
      createComponent();
      expect(wrapper.find(SimpleViewer).exists()).toBe(true);

      wrapper.vm.switchViewer(RichViewerMock.type);

      return wrapper.vm
        .$nextTick()
        .then(() => {
          expect(wrapper.find(RichViewer).exists()).toBe(true);
          wrapper.vm.switchViewer(SimpleViewerMock.type);
        })
        .then(() => {
          expect(wrapper.find(SimpleViewer).exists()).toBe(true);
        });
    });

    describe('URLS with hash', () => {
      beforeEach(() => {
        window.location.hash = '#LC2';
      });

      afterEach(() => {
        window.location.hash = '';
      });

      it('renders simple viewer by default if URL contains hash', () => {
        createComponent();

        expect(wrapper.vm.activeViewerType).toBe(SimpleViewerMock.type);
        expect(wrapper.find(SimpleViewer).exists()).toBe(true);
      });

      describe('switchViewer()', () => {
        it('by default switches to the passed viewer', () => {
          createComponent();

          wrapper.vm.switchViewer(RichViewerMock.type);
          return wrapper.vm
            .$nextTick()
            .then(() => {
              expect(wrapper.vm.activeViewerType).toBe(RichViewerMock.type);
              expect(wrapper.find(RichViewer).exists()).toBe(true);

              wrapper.vm.switchViewer(SimpleViewerMock.type);
            })
            .then(() => {
              expect(wrapper.vm.activeViewerType).toBe(SimpleViewerMock.type);
              expect(wrapper.find(SimpleViewer).exists()).toBe(true);
            });
        });

        it('respects hash over richViewer in the blob when corresponding parameter is passed', () => {
          createComponent(
            {},
            {
              blob: BlobMock,
            },
          );
          expect(wrapper.vm.blob.richViewer).toEqual(expect.any(Object));

          wrapper.vm.switchViewer(RichViewerMock.type, true);
          return wrapper.vm.$nextTick().then(() => {
            expect(wrapper.vm.activeViewerType).toBe(SimpleViewerMock.type);
            expect(wrapper.find(SimpleViewer).exists()).toBe(true);
          });
        });
      });
    });
  });
});

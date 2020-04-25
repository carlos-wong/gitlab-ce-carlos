import { shallowMount } from '@vue/test-utils';
import BlobHeaderFilepath from '~/blob/components/blob_header_filepath.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { Blob as MockBlob } from './mock_data';
import { numberToHumanSize } from '~/lib/utils/number_utils';

const mockHumanReadableSize = 'a lot';
jest.mock('~/lib/utils/number_utils', () => ({
  numberToHumanSize: jest.fn(() => mockHumanReadableSize),
}));

describe('Blob Header Filepath', () => {
  let wrapper;

  function createComponent(blobProps = {}, options = {}) {
    wrapper = shallowMount(BlobHeaderFilepath, {
      propsData: {
        blob: Object.assign({}, MockBlob, blobProps),
      },
      ...options,
    });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  describe('rendering', () => {
    it('matches the snapshot', () => {
      createComponent();
      expect(wrapper.element).toMatchSnapshot();
    });

    it('renders regular name', () => {
      createComponent();
      expect(
        wrapper
          .find('.js-blob-header-filepath')
          .text()
          .trim(),
      ).toBe(MockBlob.name);
    });

    it('does not fail if the name is empty', () => {
      const emptyName = '';
      createComponent({ name: emptyName });
      expect(wrapper.find('.js-blob-header-filepath').exists()).toBe(false);
    });

    it('renders copy-to-clipboard icon that copies path of the Blob', () => {
      createComponent();
      const btn = wrapper.find(ClipboardButton);
      expect(btn.exists()).toBe(true);
      expect(btn.vm.text).toBe(MockBlob.path);
    });

    it('renders filesize in a human-friendly format', () => {
      createComponent();
      expect(numberToHumanSize).toHaveBeenCalled();
      expect(wrapper.vm.blobSize).toBe(mockHumanReadableSize);
    });

    it('renders a slot and prepends its contents to the existing one', () => {
      const slotContent = 'Foo Bar';
      createComponent(
        {},
        {
          scopedSlots: {
            filepathPrepend: `<span>${slotContent}</span>`,
          },
        },
      );

      expect(wrapper.text()).toContain(slotContent);
      expect(
        wrapper
          .text()
          .trim()
          .substring(0, slotContent.length),
      ).toBe(slotContent);
    });
  });

  describe('functionality', () => {
    it('sets gfm value correctly on the clipboard-button', () => {
      createComponent();
      expect(wrapper.vm.gfmCopyText).toBe('`dummy.md`');
    });
  });
});

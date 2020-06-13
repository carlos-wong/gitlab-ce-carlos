import $ from 'jquery';
import BlobFileDropzone from '~/blob/blob_file_dropzone';

describe('BlobFileDropzone', () => {
  preloadFixtures('blob/show.html');
  let dropzone;
  let replaceFileButton;
  const jQueryMock = {
    enable: jest.fn(),
    disable: jest.fn(),
  };

  beforeEach(() => {
    loadFixtures('blob/show.html');
    const form = $('.js-upload-blob-form');
    // eslint-disable-next-line no-new
    new BlobFileDropzone(form, 'POST');
    dropzone = $('.js-upload-blob-form .dropzone').get(0).dropzone;
    dropzone.processQueue = jest.fn();
    replaceFileButton = $('#submit-all');
    $.fn.extend(jQueryMock);
  });

  describe('submit button', () => {
    it('requires file', () => {
      jest.spyOn(window, 'alert').mockImplementation(() => {});

      replaceFileButton.click();

      expect(window.alert).toHaveBeenCalled();
    });

    it('is disabled while uploading', () => {
      jest.spyOn(window, 'alert').mockImplementation(() => {});

      const file = new File([], 'some-file.jpg');
      const fakeEvent = $.Event('drop', {
        dataTransfer: { files: [file] },
      });

      dropzone.listeners[0].events.drop(fakeEvent);

      replaceFileButton.click();

      expect(window.alert).not.toHaveBeenCalled();
      expect(jQueryMock.enable).toHaveBeenCalled();
      expect(dropzone.processQueue).toHaveBeenCalled();
    });
  });
});

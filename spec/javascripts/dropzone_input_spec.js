import $ from 'jquery';
import dropzoneInput from '~/dropzone_input';
import { TEST_HOST } from 'spec/test_constants';

const TEST_FILE = new File([], 'somefile.jpg');
TEST_FILE.upload = {};

const TEST_UPLOAD_PATH = `${TEST_HOST}/upload/file`;
const TEST_ERROR_MESSAGE = 'A big error occurred!';
const TEMPLATE = `<form class="gfm-form" data-uploads-path="${TEST_UPLOAD_PATH}">
  <textarea class="js-gfm-input"></textarea>
  <div class="uploading-error-message"></div>
</form>`;

describe('dropzone_input', () => {
  it('returns null when failed to initialize', () => {
    const dropzone = dropzoneInput($('<form class="gfm-form"></form>'));

    expect(dropzone).toBeNull();
  });

  it('returns valid dropzone when successfully initialize', () => {
    const dropzone = dropzoneInput($(TEMPLATE));

    expect(dropzone.version).toBeTruthy();
  });

  describe('shows error message', () => {
    let form;
    let dropzone;
    let xhr;
    let oldXMLHttpRequest;

    beforeEach(() => {
      form = $(TEMPLATE);

      dropzone = dropzoneInput(form);

      xhr = jasmine.createSpyObj(Object.keys(XMLHttpRequest.prototype));
      oldXMLHttpRequest = window.XMLHttpRequest;
      window.XMLHttpRequest = () => xhr;
    });

    afterEach(() => {
      window.XMLHttpRequest = oldXMLHttpRequest;
    });

    it('when AJAX fails with json', () => {
      xhr = {
        ...xhr,
        statusCode: 400,
        readyState: 4,
        responseText: JSON.stringify({ message: TEST_ERROR_MESSAGE }),
        getResponseHeader: () => 'application/json',
      };

      dropzone.processFile(TEST_FILE);

      xhr.onload();

      expect(form.find('.uploading-error-message').text()).toEqual(TEST_ERROR_MESSAGE);
    });

    it('when AJAX fails with text', () => {
      xhr = {
        ...xhr,
        statusCode: 400,
        readyState: 4,
        responseText: TEST_ERROR_MESSAGE,
        getResponseHeader: () => 'text/plain',
      };

      dropzone.processFile(TEST_FILE);

      xhr.onload();

      expect(form.find('.uploading-error-message').text()).toEqual(TEST_ERROR_MESSAGE);
    });
  });
});

import MockAdapter from 'axios-mock-adapter';
import $ from 'jquery';
import ProjectFindFile from '~/project_find_file';
import axios from '~/lib/utils/axios_utils';
import { TEST_HOST } from 'helpers/test_constants';

const BLOB_URL_TEMPLATE = `${TEST_HOST}/namespace/project/blob/master`;
const FILE_FIND_URL = `${TEST_HOST}/namespace/project/files/master?format=json`;
const FIND_TREE_URL = `${TEST_HOST}/namespace/project/tree/master`;
const TEMPLATE = `<div class="file-finder-holder tree-holder js-file-finder" data-blob-url-template="${BLOB_URL_TEMPLATE}" data-file-find-url="${FILE_FIND_URL}"  data-find-tree-url="${FIND_TREE_URL}">
  <input class="file-finder-input" id="file_find" />
  <div class="tree-content-holder">
    <div class="table-holder">
      <table class="files-slider tree-table">
        <tbody />
      </table>
    </div>
  </div>
</div>`;

describe('ProjectFindFile', () => {
  let element;
  let mock;

  const getProjectFindFileInstance = () =>
    new ProjectFindFile(element, {
      url: FILE_FIND_URL,
      treeUrl: FIND_TREE_URL,
      blobUrlTemplate: BLOB_URL_TEMPLATE,
    });

  const findFiles = () =>
    element
      .find('.tree-table tr')
      .toArray()
      .map(el => ({
        text: el.textContent,
        href: el.querySelector('a').href,
      }));

  beforeEach(() => {
    // Create a mock adapter for stubbing axios API requests
    mock = new MockAdapter(axios);

    element = $(TEMPLATE);
  });

  afterEach(() => {
    // Reset the mock adapter
    mock.restore();
  });

  it('loads and renders elements from remote server', done => {
    const files = [
      'fileA.txt',
      'fileB.txt',
      'fi#leC.txt',
      'folderA/fileD.txt',
      'folder#B/fileE.txt',
      'folde?rC/fil#F.txt',
    ];
    mock.onGet(FILE_FIND_URL).replyOnce(200, files);

    getProjectFindFileInstance(); // This triggers a load / axios call + subsequent render in the constructor

    setImmediate(() => {
      expect(findFiles()).toEqual(
        files.map(text => ({
          text,
          href: `${BLOB_URL_TEMPLATE}/${encodeURIComponent(text)}`,
        })),
      );

      done();
    });
  });
});

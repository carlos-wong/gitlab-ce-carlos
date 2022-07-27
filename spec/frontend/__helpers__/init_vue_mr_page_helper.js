import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import initMRPage from '~/mr_notes';
import { getDiffFileMock } from '../diffs/mock_data/diff_file';
import { userDataMock, notesDataMock, noteableDataMock } from '../notes/mock_data';

export default function initVueMRPage() {
  const mrTestEl = document.createElement('div');
  mrTestEl.className = 'js-merge-request-test';
  document.body.appendChild(mrTestEl);

  const diffsAppEndpoint = '/diffs/app/endpoint';
  const diffsAppProjectPath = 'testproject';
  const mrEl = document.createElement('div');
  mrEl.className = 'merge-request fixture-mr';
  mrEl.dataset.mrAction = 'diffs';
  mrTestEl.appendChild(mrEl);

  const mrDiscussionsEl = document.createElement('div');
  mrDiscussionsEl.id = 'js-vue-mr-discussions';
  mrDiscussionsEl.dataset.currentUserData = JSON.stringify(userDataMock);
  mrDiscussionsEl.dataset.noteableData = JSON.stringify(noteableDataMock);
  mrDiscussionsEl.dataset.notesData = JSON.stringify(notesDataMock);
  mrDiscussionsEl.dataset.noteableType = 'merge-request';
  mrDiscussionsEl.dataset.isLocked = 'false';
  mrTestEl.appendChild(mrDiscussionsEl);

  const discussionCounterEl = document.createElement('div');
  discussionCounterEl.id = 'js-vue-discussion-counter';
  mrTestEl.appendChild(discussionCounterEl);

  const diffsAppEl = document.createElement('div');
  diffsAppEl.id = 'js-diffs-app';
  diffsAppEl.dataset.endpoint = diffsAppEndpoint;
  diffsAppEl.dataset.projectPath = diffsAppProjectPath;
  diffsAppEl.dataset.currentUserData = JSON.stringify(userDataMock);
  mrTestEl.appendChild(diffsAppEl);

  const mock = new MockAdapter(axios);
  mock.onGet(diffsAppEndpoint).reply(200, {
    branch_name: 'foo',
    diff_files: [getDiffFileMock()],
  });

  initMRPage();
  return mock;
}

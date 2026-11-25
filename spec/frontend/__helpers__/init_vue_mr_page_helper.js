import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import initMRPage from '~/mr_notes';
import { userDataMock, notesDataMock, noteableDataMock } from '../notes/mock_data';

export default function initVueMRPage() {
  const contentWrapperEl = document.createElement('div');
  contentWrapperEl.className = 'content-wrapper';
  document.body.appendChild(contentWrapperEl);

  const containerEl = document.createElement('div');
  containerEl.className = 'container-fluid';
  contentWrapperEl.appendChild(containerEl);

  const mrTestEl = document.createElement('div');
  mrTestEl.className = 'js-merge-request-test';
  containerEl.appendChild(mrTestEl);

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

  // Tab switches fire requests that the specs don't assert on; the adapter answers them with 404s.
  const mock = new MockAdapter(axios);

  initMRPage();
  return mock;
}

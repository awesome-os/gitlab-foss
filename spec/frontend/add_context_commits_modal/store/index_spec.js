import { createTestingPinia } from '@pinia/testing';
import MockAdapter from 'axios-mock-adapter';
import getDiffWithCommit from 'test_fixtures/merge_request_diffs/with_commit.json';
import { TEST_HOST } from 'helpers/test_constants';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { useAddContextCommits } from '~/add_context_commits_modal/store';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_NO_CONTENT,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AddContextCommits store', () => {
  const { commit } = getDiffWithCommit;
  const contextCommitEndpoint = '/api/v4/projects/1/merge_requests/1/context_commits';
  const mergeRequestIid = 1;
  const projectId = 1;
  const contextCommitsPath = `${TEST_HOST}/gitlab-org/gitlab/-/merge_requests/1/context_commits.json`;
  const dummyCommit = {
    id: 1,
    title: 'dummy commit',
    short_id: 'abcdef',
    committed_date: '2020-06-12',
  };
  let store;
  let mock;

  useMockLocationHelper();

  beforeEach(() => {
    gon.api_version = 'v4';
    mock = new MockAdapter(axios);
    createTestingPinia({ stubActions: false });
    store = useAddContextCommits();
  });

  afterEach(() => {
    mock.restore();
  });

  it('has the expected default state', () => {
    expect(store.$state).toStrictEqual({
      projectId: null,
      mergeRequestIid: null,
      contextCommitsPath: '',
      tabIndex: 0,
      isLoadingCommits: false,
      commits: [],
      commitsLoadingError: false,
      selectedCommits: [],
      isLoadingContextCommits: false,
      contextCommits: [],
      contextCommitsLoadingError: false,
      toRemoveCommits: [],
    });
  });

  describe('setBaseConfig', () => {
    it('sets contextCommitsPath, mergeRequestIid and projectId', () => {
      store.setBaseConfig({ contextCommitsPath, mergeRequestIid, projectId });

      expect(store.contextCommitsPath).toBe(contextCommitsPath);
      expect(store.mergeRequestIid).toBe(mergeRequestIid);
      expect(store.projectId).toBe(projectId);
    });
  });

  describe('setTabIndex', () => {
    it('sets tabIndex to specific index', () => {
      store.setTabIndex(1);

      expect(store.tabIndex).toBe(1);
    });
  });

  describe('searchCommits', () => {
    beforeEach(() => {
      store.setBaseConfig({ contextCommitsPath, mergeRequestIid, projectId });
    });

    it('starts loading and resets the loading error', () => {
      store.commitsLoadingError = true;
      mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, []);

      store.searchCommits();

      expect(store.isLoadingCommits).toBe(true);
      expect(store.commitsLoadingError).toBe(false);
    });

    it('requests the commits with the search params', async () => {
      mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, []);

      await store.searchCommits({ searchText: 'abcd', author: 'abhi' });

      expect(mock.history.get[0].params).toStrictEqual({
        searchText: 'abcd',
        author: 'abhi',
      });
    });

    describe('without a search', () => {
      it('requests the commits without params', async () => {
        mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, []);

        await store.searchCommits();

        expect(mock.history.get[0].params).toStrictEqual({});
      });
    });

    it('sets the commits and stops loading', async () => {
      mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, [dummyCommit]);

      await store.searchCommits({});

      expect(store.commits).toStrictEqual([{ ...dummyCommit, isSelected: false }]);
      expect(store.isLoadingCommits).toBe(false);
    });

    it('keeps the commits that are already selected as selected', async () => {
      store.selectedCommits = [{ ...dummyCommit, isSelected: true }];
      mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, [dummyCommit]);

      await store.searchCommits({});

      expect(store.commits).toStrictEqual([{ ...dummyCommit, isSelected: true }]);
    });

    it('does not keep the commits that were deselected as selected', async () => {
      store.selectedCommits = [{ ...dummyCommit, isSelected: false }];
      mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, [dummyCommit]);

      await store.searchCommits({});

      expect(store.commits).toStrictEqual([{ ...dummyCommit, isSelected: false }]);
    });

    describe('when the search is null', () => {
      it('appends the context commits', async () => {
        const contextCommit = { ...commit, isSelected: true };
        store.contextCommits = [contextCommit];
        mock.onGet(contextCommitsPath).reply(HTTP_STATUS_OK, [dummyCommit]);

        await store.searchCommits(null);

        expect(store.commits).toHaveLength(2);
        expect(store.commits).toEqual(
          expect.arrayContaining([{ ...dummyCommit, isSelected: false }, contextCommit]),
        );
      });
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        mock.onGet(contextCommitsPath).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('sets the loading error and stops loading', async () => {
        await store.searchCommits({});

        expect(store.commitsLoadingError).toBe(true);
        expect(store.isLoadingCommits).toBe(false);
      });
    });
  });

  describe('setCommits', () => {
    it('sets the commits, stops loading and resets the loading error', () => {
      store.isLoadingCommits = true;
      store.commitsLoadingError = true;

      store.setCommits({ commits: [commit], silentAddition: false });

      expect(store.commits).toStrictEqual([commit]);
      expect(store.isLoadingCommits).toBe(false);
      expect(store.commitsLoadingError).toBe(false);
    });

    describe('when the addition is silent', () => {
      it('sets the commits and keeps loading', () => {
        store.isLoadingCommits = true;

        store.setCommits({ commits: [commit], silentAddition: true });

        expect(store.commits).toStrictEqual([commit]);
        expect(store.isLoadingCommits).toBe(true);
      });
    });

    it('orders the commits by committed date, newest first', () => {
      const older = { ...dummyCommit, short_id: 'older', committed_date: '2020-01-01' };
      const newer = { ...dummyCommit, short_id: 'newer', committed_date: '2021-01-01' };

      store.setCommits({ commits: [older, newer] });

      expect(store.commits).toStrictEqual([newer, older]);
    });

    it('removes duplicated commits', () => {
      store.setCommits({ commits: [dummyCommit, { ...dummyCommit }] });

      expect(store.commits).toStrictEqual([dummyCommit]);
    });
  });

  describe('createContextCommits', () => {
    beforeEach(() => {
      store.setBaseConfig({ contextCommitsPath, mergeRequestIid, projectId });
    });

    describe('when the request succeeds', () => {
      beforeEach(() => {
        mock.onPost(contextCommitEndpoint).reply(HTTP_STATUS_OK, {});
      });

      it('calls the API with the short ids of the commits and resolves with true', async () => {
        const result = await store.createContextCommits({ commits: [dummyCommit] });

        expect(JSON.parse(mock.history.post[0].data)).toStrictEqual({
          commits: [dummyCommit.short_id],
        });
        expect(result).toBe(true);
        expect(window.location.reload).not.toHaveBeenCalled();
      });

      describe('with forceReload', () => {
        it('reloads the page', async () => {
          await store.createContextCommits({ commits: [], forceReload: true });

          expect(window.location.reload).toHaveBeenCalledTimes(1);
        });
      });
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        mock.onPost(contextCommitEndpoint).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('resolves with false and does not alert', async () => {
        const result = await store.createContextCommits({ commits: [] });

        expect(result).toBe(false);
        expect(createAlert).not.toHaveBeenCalled();
      });

      describe('with forceReload', () => {
        it('resolves with false, alerts and does not reload', async () => {
          const result = await store.createContextCommits({ commits: [], forceReload: true });

          expect(result).toBe(false);
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Failed to create context commits. Please try again.',
          });
          expect(window.location.reload).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('fetchContextCommits', () => {
    beforeEach(() => {
      store.setBaseConfig({ contextCommitsPath, mergeRequestIid, projectId });
    });

    it('starts loading and resets the loading error', () => {
      store.contextCommitsLoadingError = true;
      mock.onGet(contextCommitEndpoint).reply(HTTP_STATUS_OK, []);

      store.fetchContextCommits();

      expect(store.isLoadingContextCommits).toBe(true);
      expect(store.contextCommitsLoadingError).toBe(false);
    });

    it('sets the context, commits and selected commits as selected', async () => {
      const contextCommit = { ...dummyCommit, isSelected: true };
      mock.onGet(contextCommitEndpoint).reply(HTTP_STATUS_OK, [dummyCommit]);

      await store.fetchContextCommits();

      expect(store.contextCommits).toStrictEqual([contextCommit]);
      expect(store.commits).toStrictEqual([contextCommit]);
      expect(store.selectedCommits).toStrictEqual([contextCommit]);
      expect(store.isLoadingContextCommits).toBe(false);
    });

    it('does not stop the commits loading when adding the context commits', async () => {
      store.isLoadingCommits = true;
      mock.onGet(contextCommitEndpoint).reply(HTTP_STATUS_OK, [dummyCommit]);

      await store.fetchContextCommits();

      expect(store.isLoadingCommits).toBe(true);
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        mock.onGet(contextCommitEndpoint).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('sets the loading error and stops loading', async () => {
        await store.fetchContextCommits();

        expect(store.contextCommitsLoadingError).toBe(true);
        expect(store.isLoadingContextCommits).toBe(false);
      });
    });
  });

  describe('setContextCommits', () => {
    it('sets the context commits and stops loading', () => {
      store.isLoadingContextCommits = true;
      store.contextCommitsLoadingError = true;

      store.setContextCommits([commit]);

      expect(store.contextCommits).toStrictEqual([commit]);
      expect(store.isLoadingContextCommits).toBe(false);
      expect(store.contextCommitsLoadingError).toBe(false);
    });
  });

  describe('removeContextCommits', () => {
    beforeEach(() => {
      store.setBaseConfig({ contextCommitsPath, mergeRequestIid, projectId });
      store.toRemoveCommits = [dummyCommit.short_id];
    });

    describe('when the request succeeds', () => {
      beforeEach(() => {
        mock.onDelete(contextCommitEndpoint).reply(HTTP_STATUS_NO_CONTENT);
      });

      it('calls the API with the commits to remove and resolves with true', async () => {
        const result = await store.removeContextCommits();

        expect(JSON.parse(mock.history.delete[0].data)).toStrictEqual({
          commits: [dummyCommit.short_id],
        });
        expect(result).toBe(true);
        expect(window.location.reload).not.toHaveBeenCalled();
      });

      describe('with forceReload', () => {
        it('reloads the page', async () => {
          await store.removeContextCommits(true);

          expect(window.location.reload).toHaveBeenCalledTimes(1);
        });
      });
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        mock.onDelete(contextCommitEndpoint).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('resolves with false and does not alert', async () => {
        const result = await store.removeContextCommits();

        expect(result).toBe(false);
        expect(createAlert).not.toHaveBeenCalled();
      });

      describe('with forceReload', () => {
        it('resolves with false, alerts and does not reload', async () => {
          const result = await store.removeContextCommits(true);

          expect(result).toBe(false);
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Failed to delete context commits. Please try again.',
          });
          expect(window.location.reload).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('setSelectedCommits', () => {
    it('sets selectedCommits to specified value', () => {
      store.setSelectedCommits([commit]);

      expect(store.selectedCommits).toStrictEqual([commit]);
    });

    it('orders the selected commits by committed date, newest first', () => {
      const older = { ...dummyCommit, short_id: 'older', committed_date: '2020-01-01' };
      const newer = { ...dummyCommit, short_id: 'newer', committed_date: '2021-01-01' };

      store.setSelectedCommits([older, newer]);

      expect(store.selectedCommits).toStrictEqual([newer, older]);
    });

    it('removes duplicated commits', () => {
      store.setSelectedCommits([dummyCommit, { ...dummyCommit }]);

      expect(store.selectedCommits).toStrictEqual([dummyCommit]);
    });
  });

  describe('fetchAuthors', () => {
    const authors = [{ id: 1, username: 'root' }];

    beforeEach(() => {
      store.setBaseConfig({ contextCommitsPath, mergeRequestIid, projectId });
    });

    it('resolves with the authors matching the search', async () => {
      mock.onGet().reply(HTTP_STATUS_OK, authors);

      const result = await store.fetchAuthors('roo');

      expect(mock.history.get[0].params).toMatchObject({ project_id: projectId, search: 'roo' });
      expect(result).toStrictEqual(authors);
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        mock.onGet().reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('reports the error to Sentry and resolves with undefined', async () => {
        const result = await store.fetchAuthors();

        expect(result).toBeUndefined();
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      });
    });
  });

  describe('setToRemoveCommits', () => {
    it('sets toRemoveCommits to specified value', () => {
      store.setToRemoveCommits([commit.short_id]);

      expect(store.toRemoveCommits).toStrictEqual([commit.short_id]);
    });
  });

  describe('resetModalState', () => {
    it('resets the modal state', () => {
      store.$patch({
        tabIndex: 1,
        commits: [commit],
        contextCommits: [commit],
        selectedCommits: [commit],
        toRemoveCommits: [commit.short_id],
      });

      store.resetModalState();

      expect(store.tabIndex).toBe(0);
      expect(store.commits).toStrictEqual([]);
      expect(store.contextCommits).toStrictEqual([]);
      expect(store.selectedCommits).toStrictEqual([]);
      expect(store.toRemoveCommits).toStrictEqual([]);
    });
  });
});

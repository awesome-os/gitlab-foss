import { createTestingPinia } from '@pinia/testing';
import MockAdapter from 'axios-mock-adapter';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { useAwardsApp } from '~/emoji/awards_app/store';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { EMOJI_THUMBS_UP, EMOJI_THUMBS_DOWN } from '~/emoji/constants';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/vue_shared/plugins/global_toast');

describe('Awards app store', () => {
  let store;

  beforeEach(() => {
    createTestingPinia({ stubActions: false });
    store = useAwardsApp();
  });

  describe('setInitialData', () => {
    it('sets initial data', () => {
      store.setInitialData({ path: 'https://gitlab.com', currentUserId: 1, canAwardEmoji: true });

      expect(store.path).toBe('https://gitlab.com');
      expect(store.currentUserId).toBe(1);
      expect(store.canAwardEmoji).toBe(true);
    });
  });

  describe('fetchAwards', () => {
    let mock;

    beforeEach(() => {
      mock = new MockAdapter(axios);
      store.path = '/awards';
    });

    afterEach(() => {
      mock.restore();
    });

    describe('success', () => {
      describe.each`
        relativeRootUrl
        ${null}
        ${'/gitlab'}
      `('with relative_root_url as $relativeRootUrl', ({ relativeRootUrl }) => {
        beforeEach(() => {
          window.gon = { relative_url_root: relativeRootUrl };
          mock
            .onGet(`${relativeRootUrl || ''}/awards`, { params: { per_page: 100, page: '1' } })
            .reply(HTTP_STATUS_OK, [EMOJI_THUMBS_UP], { 'x-next-page': '2' });
          mock
            .onGet(`${relativeRootUrl || ''}/awards`, { params: { per_page: 100, page: '2' } })
            .reply(HTTP_STATUS_OK, [EMOJI_THUMBS_DOWN]);
        });

        it('sets awards and fetches the next page', async () => {
          await store.fetchAwards('1');
          await new Promise(process.nextTick);

          expect(store.awards).toEqual([EMOJI_THUMBS_UP, EMOJI_THUMBS_DOWN]);
        });

        it('does not overwrite previously set awards', async () => {
          store.awards = [EMOJI_THUMBS_DOWN];

          await store.fetchAwards('2');

          expect(store.awards).toEqual([EMOJI_THUMBS_DOWN, EMOJI_THUMBS_DOWN]);
        });
      });
    });

    describe('error', () => {
      beforeEach(() => {
        mock.onGet('/awards').reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('calls Sentry.captureException', async () => {
        await store.fetchAwards();

        expect(Sentry.captureException).toHaveBeenCalled();
        expect(store.awards).toEqual([]);
      });
    });
  });

  describe('toggleAward', () => {
    let mock;

    const optimisticAwardId = Number.MAX_SAFE_INTEGER - 1;

    beforeEach(() => {
      mock = new MockAdapter(axios);
      store.path = '/awards';
    });

    afterEach(() => {
      mock.restore();
    });

    describe.each`
      relativeRootUrl
      ${null}
      ${'/gitlab'}
    `('with relative_root_url as $relativeRootUrl', ({ relativeRootUrl }) => {
      beforeEach(() => {
        window.gon = { relative_url_root: relativeRootUrl };
      });

      describe('adding new award', () => {
        describe('success', () => {
          beforeEach(() => {
            mock.onPost(`${relativeRootUrl || ''}/awards`).reply(HTTP_STATUS_OK, { id: 1 });
          });

          it('adds an optimistic award, removes it, and then adds the new award', async () => {
            const promise = store.toggleAward(EMOJI_THUMBS_UP);

            expect(store.awards).toEqual([
              expect.objectContaining({ id: optimisticAwardId, name: EMOJI_THUMBS_UP }),
            ]);

            await promise;

            expect(store.awards).toEqual([{ id: 1 }]);
          });
        });

        describe('error', () => {
          beforeEach(() => {
            mock.onPost(`${relativeRootUrl || ''}/awards`).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
          });

          it('removes the optimistic award and calls Sentry.captureException', async () => {
            await store.toggleAward(EMOJI_THUMBS_UP);

            expect(store.awards).toEqual([]);
            expect(Sentry.captureException).toHaveBeenCalled();
          });
        });
      });

      describe('adding another tone of an emoji the user reacted with', () => {
        const ownAward = { id: 7, name: EMOJI_THUMBS_UP, user: { id: 1 } };
        const otherUsersAward = { id: 8, name: 'thumbsup_tone1', user: { id: 2 } };

        beforeEach(() => {
          window.gon = { relative_url_root: relativeRootUrl, emoji_skin_tone: 'medium' };
          store.currentUserId = 1;
          store.awards = [ownAward, otherUsersAward];
        });

        it("drops the user's other tones with the add, as the server does", async () => {
          mock.onPost(`${relativeRootUrl || ''}/awards`).reply(HTTP_STATUS_OK, { id: 9 });

          const promise = store.toggleAward('thumbsup_tone3');

          expect(store.awards).toEqual([
            otherUsersAward,
            expect.objectContaining({ id: 6, name: 'thumbsup_tone3' }),
          ]);

          await promise;

          expect(store.awards).toEqual([otherUsersAward, { id: 9 }]);
        });

        it("restores the user's other tones when the add fails", async () => {
          mock.onPost(`${relativeRootUrl || ''}/awards`).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

          await store.toggleAward('thumbsup_tone3');

          expect(store.awards).toEqual([otherUsersAward, ownAward]);
          expect(Sentry.captureException).toHaveBeenCalled();
        });
      });

      describe('removing an award', () => {
        const mockData = { id: 1, name: EMOJI_THUMBS_UP, user: { id: 1 } };

        beforeEach(() => {
          store.currentUserId = 1;
          store.awards = [mockData];
        });

        describe('success', () => {
          beforeEach(() => {
            mock.onDelete(`${relativeRootUrl || ''}/awards/1`).reply(HTTP_STATUS_OK);
          });

          it('removes the award', async () => {
            await store.toggleAward(EMOJI_THUMBS_UP);

            expect(store.awards).toEqual([]);
          });
        });

        describe('error', () => {
          beforeEach(() => {
            mock
              .onDelete(`${relativeRootUrl || ''}/awards/1`)
              .reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
          });

          it('restores the award and calls Sentry.captureException', async () => {
            await store.toggleAward(EMOJI_THUMBS_UP);

            expect(store.awards).toEqual([mockData]);
            expect(Sentry.captureException).toHaveBeenCalled();
          });
        });
      });
    });
  });
});

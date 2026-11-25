import MockAdapter from 'axios-mock-adapter';
import { createTestingPinia } from '@pinia/testing';
import { useContributors } from '~/contributors/stores';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_OK } from '~/lib/utils/http_status';

jest.mock('~/alert');

describe('Contributors store', () => {
  let store;

  beforeEach(() => {
    createTestingPinia({ stubActions: false });
    store = useContributors();
  });

  describe('getters', () => {
    describe('showChart', () => {
      it('should NOT show chart if loading', () => {
        store.loading = true;

        expect(store.showChart).toBe(false);
      });

      it('should NOT show chart there is not data', () => {
        store.loading = false;
        store.chartData = null;

        expect(store.showChart).toBe(false);
      });

      it('should show the chart in case loading completed and there is data', () => {
        store.loading = false;
        store.chartData = true;

        expect(store.showChart).toBe(true);
      });
    });

    describe('parsedData', () => {
      let parsed;

      beforeEach(() => {
        store.chartData = [
          { author_name: 'John Smith', author_email: 'jawnnypoo@gmail.com', date: '2019-05-05' },
          { author_name: 'John', author_email: 'jawnnypoo@gmail.com', date: '2019-05-05' },
          { author_name: 'Carlson', author_email: 'carlson123@gitlab.com', date: '2019-03-03' },
          { author_name: 'Carlson', author_email: 'carlson123@gmail.com', date: '2019-05-05' },
          { author_name: 'John', author_email: 'jawnnypoo@gmail.com', date: '2019-04-04' },
          { author_name: 'Johan', author_email: 'jawnnypoo@gmail.com', date: '2019-04-04' },
          { author_name: 'John', author_email: 'JAWNNYPOO@gmail.com', date: '2019-03-03' },
        ];
        parsed = store.parsedData;
      });

      it('should group contributions by date', () => {
        expect(parsed.total).toMatchObject({ '2019-05-05': 3, '2019-03-03': 2, '2019-04-04': 2 });
      });

      it('should group contributions by email and use most recent name', () => {
        expect(parsed.byAuthorEmail).toMatchObject({
          'carlson123@gmail.com': {
            name: 'Carlson',
            commits: 1,
            dates: {
              '2019-05-05': 1,
            },
          },
          'carlson123@gitlab.com': {
            name: 'Carlson',
            commits: 1,
            dates: {
              '2019-03-03': 1,
            },
          },
          'jawnnypoo@gmail.com': {
            name: 'John Smith',
            commits: 5,
            dates: {
              '2019-03-03': 1,
              '2019-04-04': 2,
              '2019-05-05': 2,
            },
          },
        });
      });
    });

    describe('parsedData without chart data', () => {
      it('returns empty totals', () => {
        store.chartData = null;

        expect(store.parsedData).toEqual({
          total: {},
          byAuthorEmail: {},
        });
      });
    });
  });

  describe('actions', () => {
    describe('setLoadingState', () => {
      it('should set loading flag', () => {
        store.setLoadingState(true);

        expect(store.loading).toBe(true);
      });
    });

    describe('setChartData', () => {
      const chartData = { '2017-11': 0, '2017-12': 2 };

      it('should set chart data', () => {
        store.setChartData(chartData);

        expect(store.chartData).toEqual(chartData);
      });
    });

    describe('fetchChartData', () => {
      let mock;
      const endpoint = '/contributors';
      const chartData = { '2017-11': 0, '2017-12': 2 };

      beforeEach(() => {
        mock = new MockAdapter(axios);
        createAlert.mockClear();
      });

      afterEach(() => {
        mock.restore();
        jest.restoreAllMocks();
      });

      it('should set chart data with received response', async () => {
        jest.spyOn(axios, 'get');
        mock.onGet().reply(HTTP_STATUS_OK, chartData);

        const promise = store.fetchChartData(endpoint);

        expect(store.loading).toBe(true);

        await promise;

        expect(axios.get).toHaveBeenCalledWith(endpoint);
        expect(store.chartData).toEqual(chartData);
        expect(store.loading).toBe(false);
      });

      it('should show alert on API error', async () => {
        mock.onGet().reply(HTTP_STATUS_BAD_REQUEST, 'Not Found');

        await store.fetchChartData(endpoint);

        expect(store.chartData).toBeNull();
        expect(createAlert).toHaveBeenCalledWith({
          message: expect.stringMatching('error'),
        });
      });
    });
  });
});

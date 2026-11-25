import { GlEmptyState, GlLoadingIcon, GlTableLite } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { createAlert } from '~/alert';
import OfflineTransferExportHistoryApp from '~/import/offline_transfer/export/history/app.vue';
import ExportStatusBadge from '~/import/offline_transfer/export/history/components/export_status_badge.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import PaginationBar from '~/vue_shared/components/pagination_bar/pagination_bar.vue';
import { mockOfflineExports } from '../../mock_data';

jest.mock('~/alert');

describe('OfflineTransferExportHistoryApp', () => {
  const API_URL = '/api/v4/offline_exports';
  const PAGINATION_HEADERS = {
    'x-page': '1',
    'x-per-page': '20',
    'x-total': '2',
    'x-total-pages': '1',
    'x-next-page': '',
    'x-prev-page': '',
  };

  let wrapper;
  let mock;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findPaginationBar = () => wrapper.findComponent(PaginationBar);
  const findStatusBadges = () => wrapper.findAllComponents(ExportStatusBadge);
  const findRowCells = (row) => findTable().findAll('tbody tr').at(row).findAll('td');

  const createComponent = ({ mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(OfflineTransferExportHistoryApp);
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = { api_version: 'v4', uf_error_prefix: 'UF:' };
  });

  afterEach(() => {
    mock.restore();
  });

  describe('while requesting exports', () => {
    beforeEach(() => {
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, []);
      createComponent();
    });

    it('renders only the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
      expect(findTable().exists()).toBe(false);
      expect(findPaginationBar().exists()).toBe(false);
    });
  });

  describe('when there are no exports', () => {
    beforeEach(async () => {
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, []);
      createComponent();
      await waitForPromises();
    });

    it('renders the empty state', () => {
      expect(findTable().exists()).toBe(false);
      expect(findEmptyState().props('title')).toBe('No history is available yet');
      expect(findEmptyState().props('description')).toBe(
        'Groups exported through offline transfer appear here.',
      );
      expect(findPaginationBar().exists()).toBe(false);
    });
  });

  describe('when exports exist', () => {
    beforeEach(async () => {
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, mockOfflineExports, PAGINATION_HEADERS);
      createComponent({ mountFn: mountExtended });
      await waitForPromises();
    });

    it('requests the first page with the default page size', () => {
      expect(mock.history.get[0].params).toEqual({ page: 1, per_page: 20 });
    });

    it('does not render the empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('renders a row per export', () => {
      expect(findTable().findAll('tbody tr')).toHaveLength(2);
    });

    it('renders the column headers', () => {
      expect(
        findTable()
          .findAll('thead th')
          .wrappers.map((th) => th.text()),
      ).toEqual(['Destination bucket', 'Export prefix', 'Start date', 'Status']);
    });

    it('renders the bucket and export prefix cells', () => {
      expect(findRowCells(0).at(0).text()).toBe('gitlab-exports');
      expect(findRowCells(0).at(1).text()).toBe('2026-09-11_10-00-00_export_ab12cd34');
    });

    it('renders the start date as a time ago', () => {
      expect(findTable().findComponent(TimeAgo).props('time')).toBe('2026-09-11T10:00:00.000Z');
    });

    it('renders a status badge per export', () => {
      expect(findStatusBadges()).toHaveLength(2);
      expect(findStatusBadges().at(0).props()).toMatchObject({
        status: 'finished',
        hasFailures: false,
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, mockOfflineExports, PAGINATION_HEADERS);
      createComponent();
      await waitForPromises();
    });

    it('passes pagination metadata from the response headers to the pagination bar', () => {
      expect(findPaginationBar().props('pageInfo')).toMatchObject({
        page: 1,
        perPage: 20,
        total: 2,
        totalPages: 1,
      });
    });

    it('loads the last page and lets users return to the first page', async () => {
      const nextPageExports = [{ ...mockOfflineExports[0], id: 3, export_prefix: 'next-page' }];
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, nextPageExports, {
        ...PAGINATION_HEADERS,
        'x-page': '2',
        'x-total': '21',
        'x-total-pages': '2',
        'x-prev-page': '1',
      });

      findPaginationBar().vm.$emit('set-page', 2);
      await waitForPromises();

      expect(mock.history.get).toHaveLength(2);
      expect(mock.history.get[1].params).toEqual({ page: 2, per_page: 20 });
      expect(findTable().props('items')).toEqual(nextPageExports);
      expect(findPaginationBar().props('pageInfo')).toMatchObject({ page: 2, previousPage: 1 });

      mock.onGet(API_URL).reply(HTTP_STATUS_OK, mockOfflineExports, PAGINATION_HEADERS);

      findPaginationBar().vm.$emit('set-page', 1);
      await waitForPromises();

      expect(mock.history.get).toHaveLength(3);
      expect(mock.history.get[2].params).toEqual({ page: 1, per_page: 20 });
      expect(findTable().props('items')).toEqual(mockOfflineExports);
    });

    it('resets to the first page when the page size changes', async () => {
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, mockOfflineExports, {
        ...PAGINATION_HEADERS,
        'x-page': '2',
        'x-total': '21',
        'x-total-pages': '2',
        'x-prev-page': '1',
      });
      findPaginationBar().vm.$emit('set-page', 2);
      await waitForPromises();
      mock.resetHistory();
      mock.onGet(API_URL).reply(HTTP_STATUS_OK, mockOfflineExports, {
        ...PAGINATION_HEADERS,
        'x-per-page': '50',
      });

      findPaginationBar().vm.$emit('set-page-size', 50);
      await waitForPromises();

      expect(mock.history.get).toHaveLength(1);
      expect(mock.history.get[0].params).toEqual({ page: 1, per_page: 50 });
      expect(findPaginationBar().props('pageInfo')).toMatchObject({ page: 1, perPage: 50 });
    });

    it('uses the selected page size for subsequent page requests', async () => {
      findPaginationBar().vm.$emit('set-page-size', 50);
      await waitForPromises();
      mock.resetHistory();

      findPaginationBar().vm.$emit('set-page', 2);
      await waitForPromises();

      expect(mock.history.get).toHaveLength(1);
      expect(mock.history.get[0].params).toEqual({ page: 2, per_page: 50 });
    });
  });

  describe('when the request fails', () => {
    beforeEach(async () => {
      mock.onGet(API_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      createComponent();
      await waitForPromises();
    });

    it('renders an alert with a generic message', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Something went wrong while fetching offline export history.',
          captureError: true,
        }),
      );
    });

    it('stops loading', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });
  });
});

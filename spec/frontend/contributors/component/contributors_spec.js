import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Contributors from '~/contributors/components/contributors.vue';
import { useContributors } from '~/contributors/stores';
import { MASTER_CHART_HEIGHT } from '~/contributors/constants';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { visitUrl } from '~/lib/utils/url_utility';
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import { REF_TYPE_BRANCHES, REF_TYPE_TAGS } from '~/vue_shared/components/ref/constants';
import ContributorAreaChart from '~/contributors/components/contributor_area_chart.vue';
import IndividualChart from '~/contributors/components/individual_chart.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  visitUrl: jest.fn(),
  joinPaths: jest.fn(),
  setUrlFragment: jest.fn(),
}));

Vue.use(PiniaVuePlugin);

let wrapper;
let mock;
let pinia;
const endpoint = 'contributors/-/graphs';
const branch = 'main';
const chartData = [
  { author_name: 'John', author_email: 'jawnnypoo@gmail.com', date: '2019-05-05' },
  { author_name: 'John', author_email: 'jawnnypoo@gmail.com', date: '2019-03-03' },
];
const projectId = '23';
const commitsPath = 'some/path';

const createWrapper = () => {
  mock = new MockAdapter(axios);
  jest.spyOn(axios, 'get');
  mock.onGet(endpoint).reply(HTTP_STATUS_OK, chartData);
  pinia = createTestingPinia({ stubActions: false });
  useContributors();

  wrapper = shallowMountExtended(Contributors, {
    propsData: {
      endpoint,
      branch,
      projectId,
      commitsPath,
    },
    pinia,
  });
};

const findLoadingIcon = () => wrapper.findByTestId('loading-app-icon');
const findRefSelector = () => wrapper.findComponent(RefSelector);
const findHistoryButton = () => wrapper.findByTestId('history-button');
const findMasterChart = () => wrapper.findComponent(ContributorAreaChart);
const findIndividualCharts = () => wrapper.findAllComponents(IndividualChart);

describe('Contributors', () => {
  beforeEach(() => {
    createWrapper();
  });

  afterEach(async () => {
    await waitForPromises();
    mock.restore();
    jest.restoreAllMocks();
  });

  it('should fetch chart data when mounted', () => {
    expect(axios.get).toHaveBeenCalledWith(endpoint);
  });

  it('should display loader while loading data', () => {
    expect(findLoadingIcon().exists()).toBe(true);
  });

  describe('loading complete', () => {
    beforeEach(async () => {
      await waitForPromises();
    });

    it('does not display loading spinner', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the RefSelector', () => {
      expect(findRefSelector().props()).toMatchObject({
        enabledRefTypes: [REF_TYPE_BRANCHES, REF_TYPE_TAGS],
        value: branch,
        projectId,
        translations: { dropdownHeader: 'Switch branch/tag' },
        useSymbolicRefNames: false,
        state: true,
        name: '',
      });
    });

    it('should have a history button with a set href attribute', () => {
      const historyButton = findHistoryButton();
      expect(historyButton.exists()).toBe(true);
      expect(historyButton.attributes('href')).toBe(commitsPath);
    });

    it('visits a URL when clicking on a branch/tag', () => {
      findRefSelector().vm.$emit('input', branch);

      expect(visitUrl).toHaveBeenCalledWith(`${endpoint}/${branch}`);
    });

    it('renders the master chart', () => {
      expect(findMasterChart().props()).toMatchObject({
        data: [{ name: 'Commits', data: expect.any(Array) }],
        height: MASTER_CHART_HEIGHT,
        option: {
          xAxis: {
            data: expect.any(Array),
            splitNumber: 24,
            min: '2019-03-03',
            max: '2019-05-05',
          },
          yAxis: { name: 'Number of commits' },
          grid: { bottom: 64, left: 64, right: 20, top: 20 },
        },
      });
    });

    it('renders the individual charts', () => {
      expect(findIndividualCharts()).toHaveLength(1);
      expect(findIndividualCharts().at(0).props()).toMatchObject({
        contributor: {
          name: 'John',
          email: 'jawnnypoo@gmail.com',
          commits: 2,
          dates: [{ name: 'Commits', data: expect.any(Array) }],
        },
        chartOptions: {
          xAxis: {
            data: expect.any(Array),
            splitNumber: 18,
            min: '2019-03-03',
            max: '2019-05-05',
          },
          yAxis: { name: 'Commits', max: 1 },
          grid: { bottom: 27, left: 64, right: 20, top: 8 },
        },
        zoom: {},
      });
    });

    describe('master chart was zoomed', () => {
      const zoom = { startValue: 100, endValue: 200 };

      beforeEach(() => {
        findMasterChart().vm.$emit('created', {
          setOption: jest.fn(),
          on: jest.fn().mockImplementation((_, callback) => callback()),
          getOption: jest.fn().mockImplementation(() => ({ dataZoom: [zoom] })),
        });
      });

      it('sets the individual chart zoom', () => {
        expect(findIndividualCharts().at(0).props('zoom')).toEqual(zoom);
      });
    });
  });
});

import { nextTick } from 'vue';
import { GlSkeletonLoader } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import waitForPromises from 'helpers/wait_for_promises';
import SchemaCheckerApp from '~/admin/database_diagnostics/components/schema_checker_app.vue';
import SchemaResultsContainer from '~/admin/database_diagnostics/components/schema_results_container.vue';
import { schemaIssuesResults, noSchemaIssuesResults } from '../mock_data';

describe('SchemaCheckerApp component', () => {
  let wrapper;
  let mockAxios;

  const findTitle = () => wrapper.findByTestId('title');
  const findRunButton = () => wrapper.findComponentByTestId('run-diagnostics-button');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findLastRun = () => wrapper.findByTestId('last-run');
  const findSchemaResultsContainer = () => wrapper.findComponent(SchemaResultsContainer);

  const runSchemaCheckUrl = '/admin/database_diagnostics/run_schema_check.json';
  const schemaCheckResultsUrl = '/admin/database_diagnostics/schema_check_results.json';
  const schemaCheckErrorResult = {
    error: true,
    message: 'PG::QueryCanceled: canceling statement due to statement timeout',
    metadata: { last_run_at: '2025-07-23T10:00:00Z' },
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(SchemaCheckerApp, {
      provide: {
        runSchemaCheckUrl,
        schemaCheckResultsUrl,
      },
    });
  };

  const clickRunDiagnosticsButton = async () => {
    findRunButton().vm.$emit('click');
    await nextTick();
  };

  beforeEach(() => {
    jest.useFakeTimers();
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
    jest.clearAllTimers();
  });

  describe('initial state', () => {
    beforeEach(() => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(404);
      createComponent();
    });

    it('shows a loading indicator initially', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('renders the title', () => {
      expect(findTitle().text()).toBe('Schema health check');
      expect(wrapper.text()).toContain(
        'Detect database schema inconsistencies and structural issues.',
      );
    });

    it('shows no results message after loading', async () => {
      await waitForPromises();
      expect(findLastRun().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('enables the run button after loading completes', async () => {
      expect(findRunButton().props('disabled')).toBe(true);

      await waitForPromises();

      expect(findRunButton().props('disabled')).toBe(false);
    });
  });

  describe('with results showing schema issues', () => {
    beforeEach(async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(200, schemaIssuesResults);
      createComponent();
      await waitForPromises();
    });

    it('renders schema results container with correct props', () => {
      expect(findSchemaResultsContainer().props('schemaDiagnostics')).toEqual(schemaIssuesResults);
    });

    it('displays the last run timestamp', () => {
      expect(findLastRun().text()).toMatchInterpolatedText('Last checked: Jul 23, 2025, 10:00 AM');
    });
  });

  describe('with no issues', () => {
    beforeEach(async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(200, noSchemaIssuesResults);
      createComponent();
      await waitForPromises();
    });

    it('renders schema results container for the database', () => {
      expect(findSchemaResultsContainer().props('schemaDiagnostics')).toEqual(
        noSchemaIssuesResults,
      );
    });
  });

  describe('running diagnostics', () => {
    beforeEach(async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(404);
      mockAxios.onPost(runSchemaCheckUrl).reply(200);
      createComponent();
      await waitForPromises();
    });

    it('shows loading state and disables button when run button is clicked', async () => {
      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findRunButton().props('disabled')).toBe(true);
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('makes the correct API call when run button is clicked', async () => {
      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(mockAxios.history.post).toHaveLength(1);
      expect(mockAxios.history.post[0].url).toBe(runSchemaCheckUrl);
    });

    it('updates the view when results are available after fetching', async () => {
      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(true);

      mockAxios.onGet(schemaCheckResultsUrl).reply(200, schemaIssuesResults);

      jest.runOnlyPendingTimers();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findSchemaResultsContainer().exists()).toBe(true);
    });
  });

  describe('when a run replaces an earlier result', () => {
    const withJobId = (results, jobId) => ({
      ...results,
      metadata: { ...results.metadata, job_id: jobId },
    });
    const earlierResult = withJobId(schemaIssuesResults, 'earlier-job');
    const freshResult = withJobId(noSchemaIssuesResults, 'new-job');

    beforeEach(async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(200, earlierResult);
      mockAxios.onPost(runSchemaCheckUrl).reply(200, { status: 'scheduled', job_id: 'new-job' });
      createComponent();
      await waitForPromises();
    });

    it('keeps polling while the cache holds the earlier result', async () => {
      expect(findSchemaResultsContainer().props('schemaDiagnostics')).toEqual(earlierResult);

      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(true);

      mockAxios.onGet(schemaCheckResultsUrl).reply(200, freshResult);
      jest.runOnlyPendingTimers();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findSchemaResultsContainer().props('schemaDiagnostics')).toEqual(freshResult);
    });

    it('gives each run its own retry budget', async () => {
      const runUntilResult = async (jobId, stalePolls) => {
        mockAxios.onPost(runSchemaCheckUrl).reply(200, { status: 'scheduled', job_id: jobId });
        await clickRunDiagnosticsButton();
        await waitForPromises();

        // The click made the first stale poll.
        await [...Array(stalePolls - 1)].reduce(async (promise) => {
          await promise;
          jest.runOnlyPendingTimers();
          await waitForPromises();
        }, Promise.resolve());

        mockAxios.onGet(schemaCheckResultsUrl).reply(200, withJobId(freshResult, jobId));
        jest.runOnlyPendingTimers();
        await waitForPromises();
      };

      // The first run spends its whole budget on the earlier result, and the second
      // run then polls the first run's result.
      await runUntilResult('new-job', 60);
      await runUntilResult('later-job', 1);

      expect(findErrorAlert().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('takes a result without a job ID, which an earlier worker wrote', async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(200, noSchemaIssuesResults);

      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(mockAxios.history.get.filter((req) => req.url === schemaCheckResultsUrl)).toHaveLength(
        2,
      );
    });
  });

  describe('error handling', () => {
    it('displays error alert when initial API request fails', async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(500, {
        error: 'Internal server error',
      });

      createComponent();
      await waitForPromises();

      expect(findErrorAlert().text()).toBe('Internal server error');
    });

    it('displays error alert when run diagnostic request fails', async () => {
      // The component uses error.message when the post request fails
      mockAxios.onPost(runSchemaCheckUrl).replyOnce(500);

      createComponent();
      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findErrorAlert().text()).toBe('Request failed with status code 500');
    });

    it('surfaces the message when the worker cached an error result', async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(200, schemaCheckErrorResult);

      createComponent();
      await waitForPromises();

      expect(findErrorAlert().text()).toBe(
        'PG::QueryCanceled: canceling statement due to statement timeout',
      );
      expect(findSchemaResultsContainer().exists()).toBe(false);
      expect(findLastRun().exists()).toBe(false);
    });

    it('surfaces the message when a run ends with a cached error result', async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(404);
      mockAxios.onPost(runSchemaCheckUrl).reply(200);

      createComponent();
      await clickRunDiagnosticsButton();
      await waitForPromises();

      mockAxios.onGet(schemaCheckResultsUrl).reply(200, schemaCheckErrorResult);
      jest.runOnlyPendingTimers();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findErrorAlert().text()).toBe(
        'PG::QueryCanceled: canceling statement due to statement timeout',
      );
    });

    it('replaces earlier results when a run ends with a cached error result', async () => {
      mockAxios.onGet(schemaCheckResultsUrl).replyOnce(200, schemaIssuesResults);
      mockAxios.onPost(runSchemaCheckUrl).reply(200);

      createComponent();
      await waitForPromises();
      expect(findSchemaResultsContainer().exists()).toBe(true);

      mockAxios.onGet(schemaCheckResultsUrl).reply(200, schemaCheckErrorResult);
      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findSchemaResultsContainer().exists()).toBe(false);
      expect(findLastRun().exists()).toBe(false);
    });
  });

  describe('schema diagnostics retry', () => {
    it('stops retries after reaching the maximum attempts', async () => {
      mockAxios.onGet(schemaCheckResultsUrl).reply(404);
      mockAxios.onPost(runSchemaCheckUrl).reply(200);

      createComponent();
      await waitForPromises();

      await clickRunDiagnosticsButton();
      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(true);

      // We need to run runOnlyPendingTimers 60 times so that we exhaust maxRetryAttempts
      await [...Array(60)].reduce(async (promise) => {
        await promise;
        jest.runOnlyPendingTimers();
        await waitForPromises();
      }, Promise.resolve());

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findErrorAlert().text()).toBe(
        'The database diagnostic job is taking longer than expected. You can check back later or try running it again.',
      );

      // We expect 62 calls to schemaCheckResultsUrl:
      // 1 (initial call) + 1 (first try after post call) + 60 (retries after post call) = 62
      expect(mockAxios.history.get.filter((req) => req.url === schemaCheckResultsUrl)).toHaveLength(
        62,
      );
    });
  });
});

import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { ApolloClient } from '@apollo/client/core';
import { createMockSubscription } from 'mock-apollo-client';
import { cloneDeep } from 'lodash-es';
import mockPipelineSummaryQueryResponse from 'test_fixtures/graphql/pipelines/get_pipeline_summary.query.graphql.json';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { reportToSentry } from '~/ci/utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import PipelineMiniGraph from '~/ci/pipeline_mini_graph/pipeline_mini_graph.vue';
import PipelineSummary from '~/ci/common/pipeline_summary/pipeline_summary.vue';

import getPipelineSummaryQuery from '~/ci/common/pipeline_summary/graphql/queries/get_pipeline_summary.query.graphql';
import pipelineSummaryStatusUpdatedSubscription from '~/ci/common/pipeline_summary/graphql/subscriptions/pipeline_summary_status_updated.subscription.graphql';
import pipelineSummaryDownstreamStatusUpdatedSubscription from '~/ci/common/pipeline_summary/graphql/subscriptions/pipeline_summary_downstream_status_updated.subscription.graphql';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/ci/utils', () => ({
  ...jest.requireActual('~/ci/utils'),
  reportToSentry: jest.fn(),
}));

describe('PipelineSummary', () => {
  let wrapper;
  let mockSubscription;
  const pipelineSummaryHandler = jest.fn().mockResolvedValue(mockPipelineSummaryQueryResponse);
  const subscriptionHandler = jest.fn(() => {
    mockSubscription = createMockSubscription();
    return mockSubscription;
  });
  const downstreamSubscriptions = {};
  const downstreamSubscriptionHandler = jest.fn(({ pipelineId }) => {
    downstreamSubscriptions[pipelineId] = createMockSubscription();
    return downstreamSubscriptions[pipelineId];
  });

  const {
    data: {
      project: { pipeline },
    },
  } = mockPipelineSummaryQueryResponse;

  const defaultProps = {
    fullPath: 'project/path',
    iid: '12',
    pipelineEtag: '/etag',
    includeCommitInfo: true,
  };

  const createComponent = ({ props = {}, cachedResponse } = {}) => {
    const handlers = [
      [getPipelineSummaryQuery, pipelineSummaryHandler],
      [pipelineSummaryStatusUpdatedSubscription, subscriptionHandler],
      [pipelineSummaryDownstreamStatusUpdatedSubscription, downstreamSubscriptionHandler],
    ];
    const mockApollo = createMockApollo(handlers);

    if (cachedResponse) {
      const { fullPath, iid, includeCommitInfo } = { ...defaultProps, ...props };
      mockApollo.clients.defaultClient.cache.writeQuery({
        query: getPipelineSummaryQuery,
        variables: { fullPath, iid, includeCommitInfo },
        data: cachedResponse.data,
      });
    }

    wrapper = mountExtended(PipelineSummary, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider: mockApollo,
    });

    return waitForPromises();
  };

  // Stands in for ActionCable confirming the subscription, which the mock client never does
  const confirmSubscription = (pipelineId) =>
    ApolloClient.prototype.subscribe.mock.calls
      .findLast(([{ variables }]) => variables.pipelineId === pipelineId)[0]
      .context.onSubscriptionConfirmed();

  beforeEach(() => {
    jest.spyOn(ApolloClient.prototype, 'subscribe');
  });

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPipelineMiniGraph = () => wrapper.findComponent(PipelineMiniGraph);
  const findStatusIcon = () => wrapper.findComponent(CiIcon);
  const findTimeAgo = () => wrapper.findComponent(TimeAgoTooltip);
  const findPipelineText = () => wrapper.findByTestId('pipeline-path');
  const findCommitInfo = () => wrapper.findByTestId('commit-info');
  const findCommitPath = () => wrapper.findByTestId('commit-path');

  describe('mounted', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the loading state', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('loaded', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders the pipeline status icon', () => {
      expect(findStatusIcon().exists()).toBe(true);

      expect(findStatusIcon().props()).toMatchObject({
        status: pipeline.detailedStatus,
      });
    });

    it('renders the pipeline link text', () => {
      expect(findPipelineText().exists()).toBe(true);

      expect(findPipelineText().text()).toBe(`#${getIdFromGraphQLId(pipeline.id)}`);
    });

    it('assigns correct link to pipeline', () => {
      expect(findPipelineText().attributes().href).toBe(pipeline.detailedStatus.detailsPath);
    });

    it('renders the pipeline mini graph', () => {
      expect(findPipelineMiniGraph().exists()).toBe(true);

      expect(findPipelineMiniGraph().props()).toMatchObject({
        downstreamPipelines: pipeline.downstream.nodes,
        pipelinePath: pipeline.detailedStatus.detailsPath,
        pipelineStages: pipeline.stages.nodes,
        upstreamPipeline: expect.any(Object),
      });
    });

    it('renders when the pipeline completed', () => {
      expect(findTimeAgo().exists()).toBe(true);
    });
  });

  describe('commit info', () => {
    describe('when commit info is included', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('renders the commit info', () => {
        expect(findCommitInfo().exists()).toBe(true);
      });

      it('links to the correct commit path', () => {
        expect(findCommitPath().exists()).toBe(true);
        expect(findCommitPath().attributes().href).toBe(pipeline.commit.webPath);
      });
    });

    describe('when commit info is not included', () => {
      beforeEach(async () => {
        await createComponent({ props: { includeCommitInfo: false } });
      });

      it('does not render the commit info', () => {
        expect(findCommitInfo().exists()).toBe(false);
      });

      it('does not render the commit path', () => {
        expect(findCommitPath().exists()).toBe(false);
      });
    });
  });

  describe('pipeline status subscription', () => {
    const updatedStatus = {
      ...pipeline.detailedStatus,
      id: 'running-111-111',
      label: 'running',
      icon: 'status_running',
      text: 'Running',
    };
    const updatedStage = {
      __typename: 'CiStage',
      id: 'gid://gitlab/Ci::Stage/1',
      name: 'build',
      detailedStatus: {
        __typename: 'DetailedStatus',
        id: 'running-1-1',
        icon: 'status_running',
        label: 'running',
        tooltip: 'running',
      },
    };

    beforeEach(async () => {
      await createComponent();
    });

    it('subscribes to status updates for the pipeline', () => {
      expect(subscriptionHandler).toHaveBeenCalledWith({ pipelineId: pipeline.id });
    });

    it('does not poll for the pipeline summary', () => {
      jest.advanceTimersByTime(60000);

      expect(pipelineSummaryHandler).toHaveBeenCalledTimes(1);
    });

    it('reports subscription errors to Sentry', async () => {
      mockSubscription.error(new Error('Subscription failed'));
      await waitForPromises();

      expect(reportToSentry).toHaveBeenCalledWith('PipelineSummary', expect.any(Error));
    });

    describe('when the subscription is confirmed', () => {
      beforeEach(() => {
        global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = DEFAULT_DEBOUNCE_AND_THROTTLE_MS;
        confirmSubscription(pipeline.id);
      });

      afterEach(() => {
        global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = undefined;
      });

      it('does not refetch the pipeline summary before the debounce elapses', async () => {
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS - 1);
        await waitForPromises();

        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(1);
      });

      it('refetches the pipeline summary once the debounce elapses', async () => {
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(2);
      });

      it('does not refetch the pipeline summary after it is destroyed', async () => {
        wrapper.destroy();
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(1);
      });
    });

    describe('when the subscription receives an update', () => {
      beforeEach(async () => {
        mockSubscription.next({
          data: {
            ciPipelineStatusUpdated: {
              __typename: 'Pipeline',
              id: pipeline.id,
              detailedStatus: updatedStatus,
              downstream: pipeline.downstream,
              finishedAt: null,
              stages: { ...pipeline.stages, nodes: [updatedStage] },
            },
          },
        });
        await waitForPromises();
      });

      it('updates the pipeline status', () => {
        expect(findStatusIcon().props('status')).toMatchObject(updatedStatus);
        expect(findPipelineText().text()).toBe(`#${getIdFromGraphQLId(pipeline.id)}`);
      });

      it('updates the pipeline stages', () => {
        expect(findPipelineMiniGraph().props('pipelineStages')).toEqual([updatedStage]);
      });

      it('updates the finished time', () => {
        expect(findTimeAgo().exists()).toBe(false);
      });

      it('does not refetch the pipeline summary', () => {
        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(1);
      });
    });
  });

  // The cached result arrives during vue-apollo's launch, before the component's created()
  describe('when the pipeline is already in the Apollo cache', () => {
    beforeEach(async () => {
      global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = DEFAULT_DEBOUNCE_AND_THROTTLE_MS;
      await createComponent({ cachedResponse: mockPipelineSummaryQueryResponse });
      pipelineSummaryHandler.mockClear();
    });

    afterEach(() => {
      global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = undefined;
    });

    it('refetches the pipeline summary when the subscription is confirmed', async () => {
      confirmSubscription(pipeline.id);
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      expect(pipelineSummaryHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('downstream pipeline status subscriptions', () => {
    const makeDownstream = (id, status) => ({
      __typename: 'Pipeline',
      id: `gid://gitlab/Ci::Pipeline/${id}`,
      iid: `${id}`,
      name: `child ${id}`,
      detailedStatus: {
        __typename: 'DetailedStatus',
        id: `${status.toLowerCase()}-${id}-${id}`,
        detailsPath: `/pipelines/${id}`,
        icon: `status_${status.toLowerCase()}`,
        label: status.toLowerCase(),
        name: status,
        tooltip: status.toLowerCase(),
      },
      path: `/pipelines/${id}`,
      project: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        name: 'project',
        fullPath: 'project/path',
      },
    });
    const runningDownstream = makeDownstream(201, 'RUNNING');
    const finishedDownstream = makeDownstream(202, 'SUCCESS');

    beforeEach(async () => {
      const response = cloneDeep(mockPipelineSummaryQueryResponse);
      response.data.project.pipeline.downstream.nodes = [runningDownstream, finishedDownstream];
      pipelineSummaryHandler.mockResolvedValueOnce(response);
      await createComponent();
    });

    it('subscribes only to running downstream pipelines', () => {
      expect(downstreamSubscriptionHandler).toHaveBeenCalledTimes(1);
      expect(downstreamSubscriptionHandler).toHaveBeenCalledWith({
        pipelineId: runningDownstream.id,
      });
    });

    it('unsubscribes from downstream pipelines when destroyed', () => {
      wrapper.destroy();
      // Apollo tears down the subscription on a timer
      jest.runOnlyPendingTimers();

      expect(downstreamSubscriptions[runningDownstream.id].closed).toBe(true);
    });

    describe('when the subscriptions are confirmed', () => {
      beforeEach(() => {
        global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = DEFAULT_DEBOUNCE_AND_THROTTLE_MS;
      });

      afterEach(() => {
        global.JEST_DEBOUNCE_THROTTLE_TIMEOUT = undefined;
      });

      it('refetches the pipeline summary when a downstream subscription is confirmed', async () => {
        confirmSubscription(runningDownstream.id);
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(2);
      });

      // Staggered, because Apollo already merges identical requests that are in flight together
      it('refetches the pipeline summary once when they confirm in quick succession', async () => {
        confirmSubscription(pipeline.id);
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS / 2);
        await waitForPromises();
        confirmSubscription(runningDownstream.id);
        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(2);
      });
    });

    describe('when a downstream pipeline finishes', () => {
      const { detailedStatus: successStatus } = makeDownstream(201, 'SUCCESS');

      beforeEach(async () => {
        downstreamSubscriptions[runningDownstream.id].next({
          data: {
            ciPipelineStatusUpdated: {
              __typename: 'Pipeline',
              id: runningDownstream.id,
              detailedStatus: successStatus,
            },
          },
        });
        await waitForPromises();
      });

      it('updates the downstream pipeline status in the mini graph', () => {
        expect(findPipelineMiniGraph().props('downstreamPipelines')[0].detailedStatus).toEqual(
          successStatus,
        );
      });

      it('unsubscribes from the finished downstream pipeline', () => {
        // Apollo tears down the subscription on a timer
        jest.runOnlyPendingTimers();

        expect(downstreamSubscriptions[runningDownstream.id].closed).toBe(true);
      });
    });

    describe('when a job action is executed', () => {
      let loadingWhileRefetching;

      beforeEach(async () => {
        findPipelineMiniGraph().vm.$emit('job-action-executed');
        await nextTick();
        loadingWhileRefetching = findLoadingIcon().exists();
        await waitForPromises();
      });

      it('subscribes to finished downstream pipelines', () => {
        expect(downstreamSubscriptionHandler).toHaveBeenCalledWith({
          pipelineId: finishedDownstream.id,
        });
      });

      it('does not resubscribe to downstream pipelines that are already subscribed', () => {
        expect(downstreamSubscriptionHandler).toHaveBeenCalledTimes(2);
      });

      it('refetches the pipeline summary without showing the loading state', () => {
        expect(pipelineSummaryHandler).toHaveBeenCalledTimes(2);
        expect(loadingWhileRefetching).toBe(false);
      });
    });
  });

  describe('when there is no iid', () => {
    beforeEach(async () => {
      pipelineSummaryHandler.mockClear();
      await createComponent({ props: { iid: '' } });
    });

    it('does not query the pipeline summary', () => {
      expect(pipelineSummaryHandler).not.toHaveBeenCalled();
    });

    it('does not subscribe to status updates', () => {
      expect(subscriptionHandler).not.toHaveBeenCalled();
    });

    it('renders nothing', () => {
      expect(wrapper.text()).toBe('');
    });
  });

  describe('when the query fails', () => {
    describe('with a GraphQL error', () => {
      beforeEach(async () => {
        pipelineSummaryHandler.mockResolvedValueOnce({
          errors: [{ message: 'Variable $iid of type ID! was provided invalid value' }],
        });
        await createComponent();
      });

      it('shows an alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was a problem fetching the pipeline summary.',
        });
      });

      it('does not render the pipeline summary', () => {
        expect(findPipelineText().exists()).toBe(false);
        expect(findPipelineMiniGraph().exists()).toBe(false);
      });
    });

    describe('with a network error', () => {
      beforeEach(async () => {
        pipelineSummaryHandler.mockRejectedValueOnce(new Error('Network error'));
        await createComponent();
      });

      it('shows an alert', () => {
        expect(createAlert).toHaveBeenCalled();
      });
    });
  });
});

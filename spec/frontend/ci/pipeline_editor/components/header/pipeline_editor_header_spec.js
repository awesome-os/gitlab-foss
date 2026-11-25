import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlCard, GlLoadingIcon } from '@gitlab/ui';
import Visibility from 'visibilityjs';
import { createMockSubscription } from 'mock-apollo-client';
import { cloneDeep } from 'lodash-es';
import mockPipelineIidQueryResponse from 'test_fixtures/graphql/pipelines/get_pipeline_iid.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { reportToSentry } from '~/ci/utils';
import PipelineEditorHeader from '~/ci/pipeline_editor/components/header/pipeline_editor_header.vue';
import PipelineSummary from '~/ci/common/pipeline_summary/pipeline_summary.vue';
import ValidationSegment from '~/ci/pipeline_editor/components/header/validation_segment.vue';
import getPipelineIidQuery from '~/ci/pipeline_editor/graphql/queries/get_pipeline_iid.query.graphql';
import getPipelineEtagQuery from '~/ci/pipeline_editor/graphql/queries/client/pipeline_etag.query.graphql';
import pipelineStatusesUpdatedSubscription from '~/ci/pipeline_editor/graphql/subscriptions/pipeline_editor_pipeline_statuses_updated.subscription.graphql';

import { mockLintResponse } from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/ci/utils');

const POLL_INTERVAL = 60 * 1000;

describe('Pipeline editor header', () => {
  let wrapper;
  let mockSubscription;
  const pipelineIidHandler = jest.fn().mockResolvedValue(mockPipelineIidQueryResponse);
  const subscriptionHandler = jest.fn(() => {
    mockSubscription = createMockSubscription();
    return mockSubscription;
  });

  const {
    data: {
      project: { pipeline },
    },
  } = mockPipelineIidQueryResponse;

  const defaultProps = {
    ciConfigData: mockLintResponse,
    commitSha: 'befcc427239b2e6206097b10639f7c95a86a84cf',
    isNewCiConfigFile: false,
  };

  const defaultProvide = {
    projectFullPath: '/full/path',
  };

  const createComponent = ({ props = {} } = {}) => {
    const handlers = [
      [getPipelineIidQuery, pipelineIidHandler],
      [pipelineStatusesUpdatedSubscription, subscriptionHandler],
    ];
    const mockApollo = createMockApollo(handlers);
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getPipelineEtagQuery,
      data: {
        etags: {
          __typename: 'EtagValues',
          pipeline: 'pipelines/1',
        },
      },
    });

    wrapper = shallowMount(PipelineEditorHeader, {
      provide: defaultProvide,
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider: mockApollo,
      stubs: {
        GlCard,
      },
    });

    return waitForPromises();
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPipelineSummary = () => wrapper.findComponent(PipelineSummary);
  const findValidationSegment = () => wrapper.findComponent(ValidationSegment);

  describe('loaded', () => {
    it('renders the validation segment', () => {
      createComponent();

      expect(findValidationSegment().exists()).toBe(true);
    });

    describe('pipeline summary', () => {
      it('hides the pipeline summary for new projects without a CI file', () => {
        createComponent({ props: { isNewCiConfigFile: true } });

        expect(findPipelineSummary().exists()).toBe(false);
      });

      it('renders the pipeline summary when CI file exists', async () => {
        pipelineIidHandler.mockResolvedValue(mockPipelineIidQueryResponse);
        await createComponent();

        expect(findPipelineSummary().exists()).toBe(true);
      });

      it('sends the correct props to the pipeline summary', async () => {
        pipelineIidHandler.mockResolvedValue(mockPipelineIidQueryResponse);
        await createComponent();

        expect(findPipelineSummary().props()).toMatchObject({
          fullPath: defaultProvide.projectFullPath,
          iid: pipeline.iid,
          includeCommitInfo: true,
          pipelineEtag: 'pipelines/1',
        });
      });
    });

    describe('pipeline subscription', () => {
      describe('with pipeline id', () => {
        beforeEach(async () => {
          pipelineIidHandler.mockResolvedValue(mockPipelineIidQueryResponse);
          await createComponent();
        });

        it('closes the pipeline subscription once the pipeline is found', () => {
          // Apollo tears down the subscription on a timer
          jest.runOnlyPendingTimers();

          expect(subscriptionHandler).toHaveBeenCalledTimes(1);
          expect(mockSubscription.closed).toBe(true);
        });

        it('does not poll for the pipeline iid', () => {
          jest.advanceTimersByTime(POLL_INTERVAL);

          expect(pipelineIidHandler).toHaveBeenCalledTimes(1);
        });

        describe('when the commit sha changes', () => {
          const newCommitSha = 'a'.repeat(40);

          beforeEach(async () => {
            // Keep the new commit's query pending to show the subscription doesn't wait for it
            pipelineIidHandler.mockReturnValueOnce(new Promise(() => {}));
            await wrapper.setProps({ commitSha: newCommitSha });
            await waitForPromises();
          });

          it('subscribes for the new commit while its query is in flight', () => {
            expect(pipelineIidHandler).toHaveBeenLastCalledWith({
              fullPath: defaultProvide.projectFullPath,
              sha: newCommitSha,
            });
            expect(subscriptionHandler).toHaveBeenLastCalledWith({
              fullPath: defaultProvide.projectFullPath,
              sha: newCommitSha,
            });
            expect(mockSubscription.closed).toBe(false);
          });

          it('renders the loading icon', () => {
            expect(findLoadingIcon().exists()).toBe(true);
          });
        });
      });

      describe('with no pipeline id', () => {
        let onVisibilityChange;

        beforeEach(async () => {
          jest.spyOn(Visibility, 'change').mockImplementation((callback) => {
            onVisibilityChange = callback;
            return 1;
          });
          const responseWithoutPipeline = cloneDeep(mockPipelineIidQueryResponse);
          responseWithoutPipeline.data.project.pipeline = null;
          pipelineIidHandler.mockResolvedValue(responseWithoutPipeline);
          await createComponent();
        });

        it('subscribes to pipeline updates for the commit sha', () => {
          expect(subscriptionHandler).toHaveBeenCalledWith({
            fullPath: defaultProvide.projectFullPath,
            sha: defaultProps.commitSha,
          });
          expect(mockSubscription.closed).toBe(false);
        });

        it('renders the loading icon', () => {
          expect(findLoadingIcon().exists()).toBe(true);
        });

        it('polls for the pipeline iid as a fallback for missed subscription events', async () => {
          jest.advanceTimersByTime(POLL_INTERVAL);
          await waitForPromises();

          expect(pipelineIidHandler).toHaveBeenCalledTimes(2);
        });

        describe('when the tab is hidden', () => {
          beforeEach(() => {
            jest.spyOn(Visibility, 'hidden').mockReturnValue(true);
            onVisibilityChange();
          });

          it('stops polling for the pipeline iid', () => {
            jest.advanceTimersByTime(POLL_INTERVAL);

            expect(pipelineIidHandler).toHaveBeenCalledTimes(1);
          });

          it('resumes polling when the tab is visible again', () => {
            Visibility.hidden.mockReturnValue(false);
            onVisibilityChange();
            jest.advanceTimersByTime(POLL_INTERVAL);

            expect(pipelineIidHandler).toHaveBeenCalledTimes(2);
          });
        });

        it('reports subscription errors to Sentry', async () => {
          mockSubscription.error(new Error('Subscription failed'));
          await waitForPromises();

          expect(reportToSentry).toHaveBeenCalledWith('PipelineEditorHeader', expect.any(Error));
        });

        describe('when the subscription receives a pipeline', () => {
          beforeEach(async () => {
            pipelineIidHandler.mockResolvedValue(mockPipelineIidQueryResponse);
            mockSubscription.next({
              data: {
                ciPipelineStatusesUpdated: {
                  __typename: 'Pipeline',
                  id: 'gid://gitlab/Ci::Pipeline/999',
                },
              },
            });
            await waitForPromises();
          });

          it('refetches the pipeline iid', () => {
            expect(pipelineIidHandler).toHaveBeenCalledTimes(2);
          });

          it('renders the pipeline summary with the iid from the query', () => {
            expect(findLoadingIcon().exists()).toBe(false);
            expect(findPipelineSummary().props('iid')).toBe(pipeline.iid);
          });

          it('closes the pipeline subscription', () => {
            // Apollo tears down the subscription on a timer
            jest.runOnlyPendingTimers();

            expect(mockSubscription.closed).toBe(true);
          });

          it('stops polling for the pipeline iid', () => {
            jest.advanceTimersByTime(POLL_INTERVAL);

            expect(pipelineIidHandler).toHaveBeenCalledTimes(2);
          });

          it('does not resume polling when the tab becomes visible', () => {
            onVisibilityChange();
            jest.advanceTimersByTime(POLL_INTERVAL);

            expect(pipelineIidHandler).toHaveBeenCalledTimes(2);
          });
        });
      });
    });
  });
});

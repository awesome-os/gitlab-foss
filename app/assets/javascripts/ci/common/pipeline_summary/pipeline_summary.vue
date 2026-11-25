<script>
import { GlLink, GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { createSubscriptionsCollection, reportToSentry } from '~/ci/utils';
import { PIPELINE_ALIVE_STATUSES } from '~/ci/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { getQueryHeaders } from '~/ci/pipeline_details/graph/utils';
import { MAX_RENDERED_DOWNSTREAM_PIPELINES } from '~/ci/pipeline_mini_graph/constants';
import PipelineMiniGraph from '~/ci/pipeline_mini_graph/pipeline_mini_graph.vue';
import getPipelineSummaryQuery from './graphql/queries/get_pipeline_summary.query.graphql';
import pipelineSummaryStatusUpdatedSubscription from './graphql/subscriptions/pipeline_summary_status_updated.subscription.graphql';
import pipelineSummaryDownstreamStatusUpdatedSubscription from './graphql/subscriptions/pipeline_summary_downstream_status_updated.subscription.graphql';

export default {
  name: 'PipelineSummary',
  components: {
    CiIcon,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
    PipelineMiniGraph,
    TimeAgoTooltip,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    iid: {
      type: String,
      required: true,
    },
    includeCommitInfo: {
      type: Boolean,
      required: false,
      default: false,
    },
    pipelineEtag: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      pipeline: {},
      forcedAliveDownstreamIds: [],
    };
  },
  apollo: {
    pipeline: {
      context() {
        return getQueryHeaders(this.pipelineEtag);
      },
      query: getPipelineSummaryQuery,
      // Pipelines without an iid (e.g. some imported ones) cannot be queried,
      // and the server would reject the request for the missing required variable.
      skip() {
        return !this.iid;
      },
      variables() {
        return this.queryVariables;
      },
      update({ project }) {
        return project?.pipeline || {};
      },
      error(error) {
        createAlert({ message: __('There was a problem fetching the pipeline summary.') });
        reportToSentry(this.$options.name, error);
      },
    },
    // Updates arrive as a normalized Pipeline, so Apollo merges them into the query's cache entry.
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      pipelineStatusUpdated: {
        query: pipelineSummaryStatusUpdatedSubscription,
        // Fires on the first confirm and on every reconnect, recovering events sent before either.
        // A closure, because with a cached pipeline this runs before created() defines the function.
        context() {
          return { onSubscriptionConfirmed: () => this.debouncedRefetchPipeline() };
        },
        variables() {
          return { pipelineId: this.pipeline.id };
        },
        skip() {
          return !this.pipeline?.id;
        },
        error(error) {
          reportToSentry(this.$options.name, error);
        },
      },
    },
  },
  computed: {
    commitPath() {
      return this.pipeline?.commit?.webPath;
    },
    commitSha() {
      return this.pipeline?.commit?.shortId;
    },
    downstreamPipelines() {
      return this.pipeline?.downstream?.nodes || [];
    },
    // A downstream pipeline's own status changes don't fire the parent's event
    aliveDownstreamIds() {
      return this.downstreamPipelines
        .slice(0, MAX_RENDERED_DOWNSTREAM_PIPELINES)
        .filter(
          ({ id, detailedStatus }) =>
            this.forcedAliveDownstreamIds.includes(id) ||
            PIPELINE_ALIVE_STATUSES.includes(detailedStatus?.name),
        )
        .map(({ id }) => id);
    },
    finishedAt() {
      return this.pipeline?.finishedAt;
    },
    isLoading() {
      return this.$apollo.queries.pipeline.loading;
    },
    pipelineId() {
      return getIdFromGraphQLId(this.pipeline?.id);
    },
    pipelinePath() {
      return this.status?.detailsPath || '';
    },
    queryVariables() {
      return {
        fullPath: this.fullPath,
        iid: this.iid,
        includeCommitInfo: this.includeCommitInfo,
      };
    },
    pipelineStages() {
      return this.pipeline?.stages?.nodes || [];
    },
    status() {
      return this.pipeline?.detailedStatus || null;
    },
    statusLabel() {
      return this.status?.label || '';
    },
    upstreamPipeline() {
      return this.pipeline?.upstream || {};
    },
  },
  watch: {
    aliveDownstreamIds(ids) {
      this.downstreamSubscriptions.syncSubscriptions(ids, (pipelineId) => {
        const subscription = this.$apollo
          .subscribe({
            query: pipelineSummaryDownstreamStatusUpdatedSubscription,
            variables: { pipelineId },
            context: { onSubscriptionConfirmed: this.debouncedRefetchPipeline },
          })
          .subscribe({ error: (error) => reportToSentry(this.$options.name, error) });

        return () => subscription.unsubscribe();
      });
    },
  },
  created() {
    this.downstreamSubscriptions = createSubscriptionsCollection();
    // The parent and each downstream subscription confirm on load and on every reconnect
    this.debouncedRefetchPipeline = debounce(
      this.refetchPipeline,
      DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
    );
  },
  beforeDestroy() {
    this.downstreamSubscriptions.unsubscribeAll();
    this.debouncedRefetchPipeline.cancel();
  },
  methods: {
    // A job action can restart a finished downstream pipeline, which has no subscription
    // and only fires the parent's event when its trigger job uses `strategy:`.
    onJobActionExecuted() {
      const downstreamIds = this.downstreamPipelines
        .slice(0, MAX_RENDERED_DOWNSTREAM_PIPELINES)
        .map(({ id }) => id);

      this.forcedAliveDownstreamIds = [
        ...new Set([...this.forcedAliveDownstreamIds, ...downstreamIds]),
      ];
      this.refetchPipeline();
    },
    // Not `refetch()`: that sets the query loading and swaps the summary for the spinner
    async refetchPipeline() {
      try {
        await this.$apollo.query({
          query: getPipelineSummaryQuery,
          variables: this.queryVariables,
          fetchPolicy: 'network-only',
        });
      } catch (error) {
        reportToSentry(this.$options.name, error);
      }
    },
  },
};
</script>

<template>
  <div class="!gl-w-full">
    <div v-if="isLoading" class="gl-mx-2 gl-flex !gl-items-center">
      <gl-loading-icon class="gl-mr-4" />
      {{ s__('Pipeline|Checking pipeline status') }}
    </div>
    <div v-else-if="pipeline.id" class="gl-flex !gl-w-full !gl-items-center">
      <div
        class="justify-space-between gl-flex !gl-grow gl-flex-wrap gl-gap-3"
        :class="{ '!gl-items-center': !finishedAt }"
      >
        <ci-icon v-if="status" class="gl-mt-1 gl-self-start" :status="status" />
        <div class="gl-flex !gl-grow gl-flex-col">
          <span>
            <gl-sprintf
              :message="s__('Pipelines|Pipeline %{linkStart}#%{pipelineId}%{linkEnd} %{status}')"
            >
              <template #status>{{ statusLabel }}</template>
              <template #link="{ content }">
                <gl-link data-testid="pipeline-path" :href="pipelinePath">
                  <gl-sprintf :message="content">
                    <template #pipelineId>{{ pipelineId }}</template>
                  </gl-sprintf>
                </gl-link>
              </template>
            </gl-sprintf>
          </span>
          <span class="gl-flex !gl-items-center gl-text-sm gl-text-subtle">
            <span v-if="includeCommitInfo" data-testid="commit-info">
              <gl-sprintf
                :message="s__('Pipelines|Pipeline %{status} for %{linkStart}%{commit}%{linkEnd} ')"
              >
                <template #status>{{ statusLabel }}</template>
                <template #link>
                  <gl-link
                    data-testid="commit-path"
                    :href="commitPath"
                    class="commit-sha-container gl-mr-2"
                  >
                    {{ commitSha }}
                  </gl-link>
                </template>
              </gl-sprintf>
            </span>
            <time-ago-tooltip v-if="finishedAt" :time="finishedAt" tooltip-placement="bottom" />
          </span>
        </div>
        <pipeline-mini-graph
          data-testid="pipeline-summary-pipeline-mini-graph"
          :downstream-pipelines="downstreamPipelines"
          :pipeline-path="pipelinePath"
          :pipeline-stages="pipelineStages"
          :upstream-pipeline="upstreamPipeline"
          @job-action-executed="onJobActionExecuted"
        />
      </div>
    </div>
  </div>
</template>

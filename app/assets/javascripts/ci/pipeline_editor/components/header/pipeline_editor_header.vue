<script>
import { GlCard, GlLoadingIcon } from '@gitlab/ui';
import Visibility from 'visibilityjs';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { reportToSentry } from '~/ci/utils';

import { getQueryHeaders } from '~/ci/pipeline_details/graph/utils';
import getPipelineIidQuery from '~/ci/pipeline_editor/graphql/queries/get_pipeline_iid.query.graphql';
import getPipelineEtag from '~/ci/pipeline_editor/graphql/queries/client/pipeline_etag.query.graphql';
import pipelineStatusesUpdatedSubscription from '~/ci/pipeline_editor/graphql/subscriptions/pipeline_editor_pipeline_statuses_updated.subscription.graphql';

import PipelineSummary from '~/ci/common/pipeline_summary/pipeline_summary.vue';
import ValidationSegment from './validation_segment.vue';

// Backstop for subscription events dropped by the server-side rate limit or a lost connection
const PIPELINE_IID_POLL_INTERVAL = 60 * 1000;

export default {
  name: 'PipelineEditorHeader',
  components: {
    GlCard,
    GlLoadingIcon,
    PipelineSummary,
    ValidationSegment,
  },
  inject: ['projectFullPath'],
  props: {
    ciConfigData: {
      type: Object,
      required: true,
    },
    commitSha: {
      type: String,
      required: false,
      default: '',
    },
    isNewCiConfigFile: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      pipelineEtag: '',
      pipelineIid: '',
    };
  },
  apollo: {
    pipelineEtag: {
      query: getPipelineEtag,
      update(data) {
        return data.etags?.pipeline;
      },
    },
    pipelineIid: {
      context() {
        return getQueryHeaders(this.pipelineEtag);
      },
      query: getPipelineIidQuery,
      skip() {
        return !this.commitSha;
      },
      variables() {
        return {
          fullPath: this.projectFullPath,
          sha: this.commitSha,
        };
      },
      update({ project }) {
        return project?.pipeline?.iid || '';
      },
      // An empty result leaves `pipelineIid` unchanged, and a new commit gets a fresh observer
      result() {
        this.updatePipelineIidPolling();
      },
      error() {
        createAlert({ message: s__('Pipelines|There was a problem fetching the pipeline iid.') });
      },
    },
    // Standalone rather than subscribeToMore: vue-apollo restarts linked
    // subscriptions on every query run, ignoring their `skip`.
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      pipelineCreated: {
        query: pipelineStatusesUpdatedSubscription,
        variables() {
          return {
            fullPath: this.projectFullPath,
            sha: this.commitSha,
          };
        },
        skip() {
          return !this.commitSha || Boolean(this.pipelineIid);
        },
        // The event can come from a child or MR pipeline on this SHA, so the query picks the pipeline
        result() {
          this.$apollo.queries.pipelineIid.refetch();
        },
        error(error) {
          reportToSentry(this.$options.name, error);
        },
      },
    },
  },
  computed: {
    isWaitingForIid() {
      return !this.pipelineIid;
    },
    showPipelineSummary() {
      return !this.isNewCiConfigFile;
    },
  },
  watch: {
    // Clear the old commit's iid so the subscription opens alongside the new query
    // instead of after it, so a pipeline created in between isn't missed.
    commitSha() {
      this.pipelineIid = '';
    },
    pipelineIid() {
      this.updatePipelineIidPolling();
    },
  },
  mounted() {
    this.visibilityChangeId = Visibility.change(this.updatePipelineIidPolling);
  },
  beforeDestroy() {
    Visibility.unbind(this.visibilityChangeId);
  },
  methods: {
    // Not `setupQueryPollingByVisibility`: it restarts polling on every tab focus, even once the iid is found
    updatePipelineIidPolling() {
      const query = this.$apollo.queries.pipelineIid;

      if (this.pipelineIid || Visibility.hidden()) {
        query.stopPolling();
      } else {
        query.startPolling(PIPELINE_IID_POLL_INTERVAL);
      }
    },
  },
};
</script>
<template>
  <gl-card>
    <template v-if="showPipelineSummary" #header>
      <div v-if="isWaitingForIid" class="gl-mx-2 gl-flex gl-items-center">
        <gl-loading-icon class="gl-mr-4" />
        {{ s__('Pipeline|Checking pipeline status') }}
      </div>
      <pipeline-summary
        v-else
        include-commit-info
        :iid="pipelineIid"
        :pipeline-etag="pipelineEtag"
        :full-path="projectFullPath"
      />
    </template>

    <validation-segment :ci-config="ciConfigData" />
  </gl-card>
</template>

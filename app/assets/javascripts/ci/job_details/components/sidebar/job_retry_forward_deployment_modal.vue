<script>
import { GlLink, GlModal } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'JobRetryForwardDeploymentModal',
  components: {
    GlLink,
    GlModal,
  },
  inject: {
    retryOutdatedJobDocsUrl: {
      default: '',
    },
  },
  props: {
    modalId: {
      type: String,
      required: true,
    },
    href: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      primaryProps: {
        text: __('Retry job'),
        attributes: {
          'data-method': 'post',
          'data-testid': 'retry-button-modal',
          href: this.href,
          variant: 'danger',
        },
      },
      cancelProps: {
        text: __('Cancel'),
        attributes: { category: 'secondary', variant: 'default' },
      },
    };
  },
};
</script>

<template>
  <gl-modal
    :action-cancel="cancelProps"
    :action-primary="primaryProps"
    :modal-id="modalId"
    :title="s__('Jobs|Are you sure you want to retry this job?')"
  >
    <p>
      {{
        s__(
          `Jobs|You're about to retry a job that failed because it attempted to deploy code that is older than the latest deployment.
    Retrying this job could result in overwriting the environment with the older source code.`,
        )
      }}
      <gl-link v-if="retryOutdatedJobDocsUrl" :href="retryOutdatedJobDocsUrl" target="_blank">
        {{ __('More information') }}
      </gl-link>
    </p>
    <p>{{ s__('Jobs|Are you sure you want to proceed?') }}</p>
  </gl-modal>
</template>

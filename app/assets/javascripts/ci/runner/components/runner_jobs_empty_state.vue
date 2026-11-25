<script>
import EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';

import { GlEmptyState } from '@gitlab/ui';

export default {
  name: 'RunnerJobsEmptyState',
  components: {
    GlEmptyState,
  },
  EMPTY_STATE_SVG_URL,
};
</script>

<template>
  <gl-empty-state
    :svg-path="$options.EMPTY_STATE_SVG_URL"
    :svg-height="96"
    :title="s__('Runners|This runner has not run any jobs')"
  >
    <template #description>
      <p>
        {{
          s__(
            'Runners|Make sure the runner is online and available to run jobs (not paused). Jobs display here when the runner picks them up.',
          )
        }}
      </p>
    </template>
  </gl-empty-state>
</template>

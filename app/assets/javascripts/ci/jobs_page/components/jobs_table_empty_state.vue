<script>
import { GlEmptyState } from '@gitlab/ui';
import EMPTY_STATE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';

export default {
  name: 'JobsTableEmptyState',
  components: {
    GlEmptyState,
  },
  inject: {
    pipelineEditorPath: {
      default: '',
    },
  },
  EMPTY_STATE_SVG,
};
</script>

<template>
  <gl-empty-state
    :title="s__('Jobs|Use jobs to automate your tasks')"
    :description="
      s__(
        'Jobs|Jobs are the building blocks of a GitLab CI/CD pipeline. Each job has a specific task, like testing code. To set up jobs in a CI/CD pipeline, add a CI/CD configuration file to your project.',
      )
    "
    :svg-path="$options.EMPTY_STATE_SVG"
    :svg-height="null"
    :primary-button-link="pipelineEditorPath"
    :primary-button-text="s__('Jobs|Create CI/CD configuration file')"
    data-testid="jobs-empty-state"
  />
</template>

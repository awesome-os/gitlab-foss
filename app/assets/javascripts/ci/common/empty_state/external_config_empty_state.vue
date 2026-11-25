<script>
import { GlButton } from '@gitlab/ui';
import PipelinesEmptyState from '~/ci/common/empty_state/pipelines_empty_state.vue';

export default {
  name: 'ExternalConfigEmptyState',
  components: {
    GlButton,
    PipelinesEmptyState,
  },
  props: {
    newPipelinePath: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>
<template>
  <pipelines-empty-state
    :title="
      s__(
        `ExternalConfigEmptyState|This project's pipeline configuration is located outside this repository`,
      )
    "
    :description="
      s__(
        `ExternalConfigEmptyState|To view or edit the pipeline configuration, check your project's CI/CD settings for the external file location, then navigate to that project or repository.`,
      )
    "
  >
    <template v-if="newPipelinePath" #actions>
      <gl-button :href="newPipelinePath" variant="confirm">{{
        s__('Pipelines|New pipeline')
      }}</gl-button>
    </template>
  </pipelines-empty-state>
</template>

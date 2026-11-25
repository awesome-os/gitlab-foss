<script>
import PipelinesEmptyState from '~/ci/common/empty_state/pipelines_empty_state.vue';
import PipelinesCiTemplates from './pipelines_ci_templates.vue';

export default {
  name: 'NoCiEmptyState',
  components: {
    PipelinesEmptyState,
    PipelinesCiTemplates,
  },
  inject: ['canCreatePipeline'],
};
</script>
<template>
  <pipelines-ci-templates v-if="canCreatePipeline" />
  <pipelines-empty-state
    v-else
    :description="s__('Pipelines|This project is not currently set up to run pipelines.')"
  />
</template>

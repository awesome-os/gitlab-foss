<script>
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import EMPTY_VARIABLES_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-variables-md.svg';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'ManualVariablesEmptyState',
  components: {
    GlEmptyState,
    GlSprintf,
    GlLink,
  },
  EMPTY_VARIABLES_SVG,
  runPipelineManuallyDocUrl: helpPagePath('ci/pipelines/_index', {
    anchor: 'run-a-pipeline-manually',
  }),
};
</script>

<template>
  <gl-empty-state
    :svg-path="$options.EMPTY_VARIABLES_SVG"
    :title="s__('ManualVariables|There are no manually-specified variables for this pipeline')"
  >
    <template #description>
      <gl-sprintf
        :message="
          s__(
            'ManualVariables|When you %{helpPageUrlStart}run a pipeline manually%{helpPageUrlEnd}, you can specify additional CI/CD variables to use in that pipeline run.',
          )
        "
      >
        <template #helpPageUrl="{ content }">
          <gl-link :href="$options.runPipelineManuallyDocUrl" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
  </gl-empty-state>
</template>

<script>
import { GlLink, GlModal } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';

export default {
  name: 'ForkPipelineWarningModal',
  components: {
    GlLink,
    GlModal,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change', 'confirm'],
  modalId: 'create-pipeline-for-fork-merge-request-modal',
  actionPrimary: {
    text: s__('Pipeline|Run pipeline'),
    attributes: {
      variant: 'danger',
    },
  },
  actionCancel: {
    text: __('Cancel'),
    attributes: {
      variant: 'default',
    },
  },
  runPipelinesInTheParentProjectHelpPath: helpPagePath(
    '/ci/pipelines/merge_request_pipelines.html',
    {
      anchor: 'run-pipelines-in-the-parent-project',
    },
  ),
};
</script>

<template>
  <gl-modal
    :id="$options.modalId"
    :modal-id="$options.modalId"
    :title="s__('Pipelines|Are you sure you want to run this pipeline?')"
    :action-primary="$options.actionPrimary"
    :action-cancel="$options.actionCancel"
    :visible="visible"
    @primary="$emit('confirm')"
    @change="$emit('change', $event)"
  >
    <p>
      {{
        s__(
          'Pipelines|This pipeline will run code originating from a forked project merge request. This means that the code can potentially have security considerations like exposing CI variables.',
        )
      }}
    </p>
    <p>
      {{
        s__(
          "Pipelines|It is recommended the code is reviewed thoroughly before running this pipeline with the parent project's CI resource.",
        )
      }}
    </p>
    <p>
      {{
        s__('Pipelines|If you are unsure, please ask a project maintainer to review it for you.')
      }}
    </p>
    <gl-link :href="$options.runPipelinesInTheParentProjectHelpPath" target="_blank">
      {{ s__('Pipelines|More Information') }}
    </gl-link>
  </gl-modal>
</template>

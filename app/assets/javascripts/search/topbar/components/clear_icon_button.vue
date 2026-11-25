<!--
  this component should be here only temporary until this MR gets sorted:
  https://gitlab.com/gitlab-org/gitlab-ui/-/merge_requests/3969
 -->
<script>
import { GlTooltipDirective, GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'ClearIconButton',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glListenersMixin],
  props: {
    title: {
      type: String,
      required: false,
      default: () => __('Clear'),
    },
  },
};
</script>

<template>
  <gl-button
    v-gl-tooltip.hover
    variant="default"
    category="tertiary"
    class="gl-clear-icon-button"
    size="small"
    name="clear"
    icon="clear"
    :title="title"
    :aria-label="title"
    v-on="glListeners()"
  />
</template>

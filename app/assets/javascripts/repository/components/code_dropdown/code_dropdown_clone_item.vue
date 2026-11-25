<script>
import {
  GlButton,
  GlFormGroup,
  GlFormInputGroup,
  GlTooltipDirective,
  GlToastMixin,
} from '@gitlab/ui';
import { __ } from '~/locale';
import { InternalEvents } from '~/tracking';

export default {
  name: 'CodeDropdownCloneItem',
  components: {
    GlFormGroup,
    GlFormInputGroup,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [InternalEvents.mixin(), GlToastMixin],
  props: {
    label: {
      type: String,
      required: true,
    },
    link: {
      type: String,
      required: true,
    },
    inputId: {
      type: String,
      required: false,
      default: '',
    },
    name: {
      type: String,
      required: false,
      default: null,
    },
    testId: {
      type: String,
      required: true,
    },
    copyButtonLabel: {
      type: String,
      required: false,
      default: __('Copy URL'),
    },
    tracking: {
      type: Object,
      required: false,
      default: () => ({ action: null }),
    },
  },
  methods: {
    onCopyUrl() {
      this.$toast.show(__('Copied'));

      this.trackCopyClick();
    },

    trackCopyClick() {
      const { action } = this.tracking;
      if (action) {
        this.trackEvent(action);
      }
    },
  },
};
</script>
<template>
  <li class="gl-my-1 gl-px-2 first:gl-mt-0 last:gl-mb-0">
    <gl-form-group
      :label="label"
      label-class="!gl-text-sm !gl-pt-2"
      :label-for="inputId"
      class="gl-mb-3 gl-px-3 gl-text-left"
    >
      <gl-form-input-group
        :id="inputId"
        :value="link"
        :name="name"
        :data-testid="inputId"
        :label="label"
        readonly
        select-on-click
        input-class="!gl-border"
      >
        <template #append>
          <gl-button
            v-gl-tooltip.hover
            :title="copyButtonLabel"
            :aria-label="copyButtonLabel"
            :data-clipboard-text="link"
            :data-testid="testId"
            icon="copy-to-clipboard"
            class="gl-inline-flex"
            @click="onCopyUrl"
          />
        </template>
      </gl-form-input-group>
    </gl-form-group>
  </li>
</template>

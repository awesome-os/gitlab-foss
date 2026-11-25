<script>
import { GlButton, GlButtonGroup } from '@gitlab/ui';

export default {
  name: 'CodeDropdownDownloadItems',
  components: {
    GlButton,
    GlButtonGroup,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
  },
  emits: ['close-dropdown'],
};
</script>
<template>
  <li v-if="items.length" class="gl-my-1 gl-px-3 gl-py-2 first:gl-mt-0 last:gl-mb-0">
    <gl-button-group class="gl-w-full">
      <gl-button
        v-for="(item, index) in items"
        :key="index"
        :href="item.href"
        v-bind="item.extraAttrs"
        @click="$emit('close-dropdown')"
      >
        {{ item.text }}
      </gl-button>
    </gl-button-group>
  </li>
</template>

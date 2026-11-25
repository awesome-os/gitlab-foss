<script>
import { GlButton } from '@gitlab/ui';
import { isExternal } from '~/lib/utils/url_utility';

export default {
  name: 'FeatureLibraryUpgradeCta',
  components: { GlButton },
  props: {
    cta: {
      type: Object,
      required: true,
    },
  },
  emits: ['click'],
  computed: {
    target() {
      return this.cta.new_tab || isExternal(this.cta.url) ? '_blank' : undefined;
    },
  },
};
</script>

<template>
  <gl-button
    variant="confirm"
    :href="cta.url"
    :target="target"
    data-testid="feature-library-cta-button"
    @click="$emit('click', cta.type)"
  >
    {{ cta.text }}
  </gl-button>
</template>

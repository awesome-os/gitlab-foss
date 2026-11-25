<script>
import { Portal } from '~/lib/utils/vue3compat/portal_vue_vue3';

export default {
  name: 'PortaledButtons',
  components: { Portal },
  props: {
    step: {
      type: Number,
      required: true,
    },
  },
  emits: ['prev', 'next'],
};
</script>

<template>
  <portal to="footer">
    <button data-testid="prev-button" :data-step="step" @click="$emit('prev')">
      {{ __('Back') }}
    </button>
    <button data-testid="next-button" :data-step="step" @click="$emit('next')">
      {{ __('Continue') }}
    </button>
  </portal>
</template>

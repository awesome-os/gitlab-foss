<script>
import { GlAlert } from '@gitlab/ui';

export default {
  name: 'WikiAlert',
  components: {
    GlAlert,
  },
  props: {
    error: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <gl-alert variant="danger" :dismissible="false">{{ error }}</gl-alert>
</template>

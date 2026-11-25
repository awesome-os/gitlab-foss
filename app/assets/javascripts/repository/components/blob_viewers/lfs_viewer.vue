<script>
import { GlLink, GlSprintf } from '@gitlab/ui';

export default {
  name: 'LfsViewer',
  components: {
    GlLink,
    GlSprintf,
  },
  props: {
    blob: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      fileName: this.blob.name,
      filePath: this.blob.externalStorageUrl || this.blob.rawPath,
    };
  },
};
</script>

<template>
  <div class="gl-bg-strong gl-py-13 gl-text-center" data-type="lfs">
    <gl-sprintf
      :message="
        __(
          'This content could not be displayed because it is stored in LFS. You can %{linkStart}download it%{linkEnd} instead.',
        )
      "
    >
      <template #link="{ content }">
        <gl-link :href="filePath" :download="fileName" target="_blank">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>

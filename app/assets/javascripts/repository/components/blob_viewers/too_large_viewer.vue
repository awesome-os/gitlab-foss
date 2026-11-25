<script>
import { GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'TooLargeViewer',
  components: { GlButton, GlSprintf, GlLink },
  props: {
    blob: {
      type: Object,
      required: true,
    },
    canExpand: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLineTooLong: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['expand'],
  computed: {
    filePath() {
      return this.blob.externalStorageUrl || this.blob.rawPath;
    },
    fileName() {
      return this.blob.name;
    },
    description() {
      return this.canExpand
        ? s__(
            'BlobViewer|You can %{expandLinkStart}load it anyway%{expandLinkEnd}, %{rawLinkStart}view the raw file%{rawLinkEnd}, or %{downloadLinkStart}download it%{downloadLinkEnd}.',
          )
        : s__(
            'BlobViewer|You can either %{rawLinkStart}view the raw file%{rawLinkEnd} or %{downloadLinkStart}download it%{downloadLinkEnd}.',
          );
    },
  },
};
</script>

<template>
  <div class="gl-p-6 gl-text-center">
    <template v-if="isLineTooLong">
      {{
        s__(
          'BlobViewer|The file could not be displayed because it contains a line that is too long.',
        )
      }}
    </template>
    <template v-else>
      {{ s__('BlobViewer|The file could not be displayed because it is too large.') }}
    </template>

    <gl-sprintf :message="description">
      <template #expandLink="{ content }">
        <gl-button variant="link" @click="$emit('expand')">{{ content }}</gl-button>
      </template>
      <template #rawLink="{ content }">
        <gl-link :href="filePath" rel="nofollow" target="_blank">{{ content }}</gl-link>
      </template>
      <template #downloadLink="{ content }">
        <gl-link :href="filePath" rel="nofollow" target="_blank" :download="fileName">{{
          content
        }}</gl-link>
      </template>
    </gl-sprintf>
  </div>
</template>

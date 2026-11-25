<script>
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import { historyImportOfflineExportPath } from '~/lib/utils/path_helpers/import';
import { n__ } from '~/locale';
import ReviewGroupsSection from '~/import/offline_transfer/components/review_groups_section.vue';

export default {
  name: 'ReviewExportTab',
  components: {
    GlAlert,
    GlButton,
    GlSprintf,
    ReviewGroupsSection,
  },
  props: {
    selectedGroups: {
      type: Array,
      required: true,
    },
    bucketName: {
      type: String,
      required: true,
    },
    hasSubmitSucceeded: {
      type: Boolean,
      required: false,
      default: false,
    },
    submissionError: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    reviewText() {
      return n__(
        'OfflineTransferExport|%{count} group will be exported to bucket %{bucket}. Select %{boldStart}Start export%{boldEnd} to confirm.',
        'OfflineTransferExport|%{count} groups will be exported to bucket %{bucket}. Select %{boldStart}Start export%{boldEnd} to confirm.',
        this.groupCount,
      );
    },
    groupCount() {
      return this.selectedGroups.length;
    },
    successText() {
      return n__(
        "OfflineTransferExport|You can leave this page. We'll email you when the export of the group is finished and the package is ready in bucket %{bucket}.",
        "OfflineTransferExport|You can leave this page. We'll email you when the export of %{count} groups is finished and the package is ready in bucket %{bucket}.",
        this.groupCount,
      );
    },
    offlineExportHistoryPath() {
      return historyImportOfflineExportPath();
    },
  },
};
</script>

<template>
  <div v-if="hasSubmitSucceeded" data-testid="submit-success">
    <h2 class="gl-heading-3">{{ s__('OfflineTransferExport|Export started') }}</h2>
    <p class="gl-max-w-2xl">
      <gl-sprintf :message="successText">
        <template #count>{{ groupCount }}</template>
        <template #bucket
          ><strong>{{ bucketName }}</strong></template
        >
      </gl-sprintf>
    </p>
    <gl-button
      :href="offlineExportHistoryPath"
      variant="confirm"
      data-testid="view-export-status-button"
    >
      {{ s__('OfflineTransferExport|View export status') }}
    </gl-button>
  </div>
  <div v-else>
    <gl-alert
      v-if="submissionError"
      :title="s__('OfflineTransferExport|Export failed')"
      variant="danger"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="submit-error"
    >
      {{ submissionError }}
    </gl-alert>
    <review-groups-section :groups="selectedGroups">
      <p v-if="!submissionError" class="gl-leading-24" data-testid="review-text">
        <gl-sprintf :message="reviewText">
          <template #count>{{ groupCount }}</template>
          <template #bucket>{{ bucketName }}</template>
          <template #bold="{ content }"
            ><strong>{{ content }}</strong></template
          >
        </gl-sprintf>
      </p>
    </review-groups-section>
  </div>
</template>

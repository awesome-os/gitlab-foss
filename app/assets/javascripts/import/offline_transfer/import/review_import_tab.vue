<script>
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import { historyImportBulkImportsPath } from '~/lib/utils/path_helpers/import';
import { __, s__ } from '~/locale';
import { DESTINATION_EXISTING_GROUP } from '../constants';

export default {
  name: 'ReviewImportTab',
  components: {
    GlAlert,
    GlButton,
    GlSprintf,
  },
  props: {
    destinationConfig: {
      type: Object,
      required: true,
    },
    storageConfig: {
      type: Object,
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
    isExistingGroupDestination() {
      return this.destinationConfig.type === DESTINATION_EXISTING_GROUP;
    },
    parentGroupName() {
      return this.destinationConfig.parentGroup?.fullName ?? '';
    },
    importAsLabel() {
      return this.isExistingGroupDestination
        ? s__('OfflineTransferImport|Subgroups of an existing group')
        : s__('OfflineTransferImport|Top-level groups');
    },
    maskedAccessKeyId() {
      return `${this.storageConfig.accessKeyId.slice(0, 4)}${this.$options.SECRET_MASK}`;
    },
    summaryRows() {
      const destinationRows = [
        {
          id: 'import-as',
          term: s__('OfflineTransferImport|Import as'),
          value: this.importAsLabel,
        },
      ];

      if (this.isExistingGroupDestination) {
        destinationRows.push({
          id: 'parent-group',
          term: s__('OfflineTransferImport|Parent group'),
          value: this.parentGroupName,
        });
      }

      return [
        {
          id: 'destination',
          heading: s__('OfflineTransferImport|Destination'),
          rows: destinationRows,
        },
        {
          id: 'source',
          heading: s__('OfflineTransferImport|Source'),
          rows: [
            {
              id: 'access-key-id',
              term: s__('OfflineTransferImport|Access key ID'),
              value: this.maskedAccessKeyId,
            },
            {
              id: 'secret-access-key',
              term: s__('OfflineTransferImport|Secret access key'),
              value: this.$options.SECRET_MASK,
            },
            {
              id: 'region',
              term: s__('OfflineTransferImport|Region'),
              value: this.storageConfig.region,
            },
            {
              id: 'bucket',
              term: s__('OfflineTransferImport|Bucket'),
              value: this.storageConfig.bucketName,
            },
            {
              id: 'path-style',
              term: s__('OfflineTransferImport|Path-style URLs'),
              value: this.storageConfig.pathStyle ? __('Yes') : __('No'),
            },
            {
              id: 'export-prefix',
              term: s__('OfflineTransferImport|Export prefix'),
              value: this.storageConfig.exportPrefix,
            },
          ],
        },
      ];
    },
    reviewText() {
      return this.isExistingGroupDestination
        ? s__(
            'OfflineTransferImport|All groups in the package will be imported as subgroups under %{parent}. Select %{boldStart}Start import%{boldEnd} to confirm.',
          )
        : s__(
            'OfflineTransferImport|All groups in the package will be imported as top-level groups on this instance. Select %{boldStart}Start import%{boldEnd} to confirm.',
          );
    },
    successText() {
      return this.isExistingGroupDestination
        ? s__(
            "OfflineTransferImport|You can leave this page. We'll email you when the import of all groups from bucket %{bucket} under %{parent} is finished.",
          )
        : s__(
            "OfflineTransferImport|You can leave this page. We'll email you when the import of all groups from bucket %{bucket} is finished.",
          );
    },
    importHistoryPath() {
      return historyImportBulkImportsPath();
    },
  },
  SECRET_MASK: '••••••••••••',
};
</script>

<template>
  <div v-if="hasSubmitSucceeded" data-testid="submit-success">
    <h2 class="gl-heading-3">{{ s__('OfflineTransferImport|Import started') }}</h2>
    <p class="gl-max-w-2xl">
      <gl-sprintf :message="successText">
        <template #bucket
          ><strong>{{ storageConfig.bucketName }}</strong></template
        >
        <template #parent
          ><strong>{{ parentGroupName }}</strong></template
        >
      </gl-sprintf>
    </p>
    <gl-button :href="importHistoryPath" variant="confirm" data-testid="view-import-status-button">
      {{ s__('OfflineTransferImport|View import status') }}
    </gl-button>
  </div>
  <div v-else>
    <gl-alert
      v-if="submissionError"
      :title="s__('OfflineTransferImport|Import failed')"
      variant="danger"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="submit-error"
    >
      {{ submissionError }}
    </gl-alert>

    <p v-if="!submissionError" class="gl-mb-5 gl-leading-24" data-testid="review-text">
      <gl-sprintf :message="reviewText">
        <template #parent>{{ parentGroupName }}</template>
        <template #bold="{ content }"
          ><strong>{{ content }}</strong></template
        >
      </gl-sprintf>
    </p>

    <section
      class="gl-border gl-flex gl-flex-col gl-gap-6 gl-rounded-base gl-border-default gl-p-5"
      data-testid="review-summary"
    >
      <div
        v-for="section in summaryRows"
        :key="section.id"
        :data-testid="`review-summary-${section.id}`"
      >
        <h3 class="gl-heading-5 gl-mb-3">{{ section.heading }}</h3>
        <dl class="gl-mb-0 gl-flex gl-flex-col gl-gap-3">
          <div
            v-for="row in section.rows"
            :key="row.id"
            class="gl-flex gl-flex-col gl-gap-1 @md:gl-flex-row @md:gl-gap-5"
            :data-testid="`review-row-${row.id}`"
          >
            <dt class="gl-shrink-0 gl-text-subtle @md:gl-w-30">{{ row.term }}</dt>
            <dd class="gl-mb-0 gl-break-anywhere">{{ row.value }}</dd>
          </div>
        </dl>
      </div>
    </section>
  </div>
</template>

<script>
import { GlAlert } from '@gitlab/ui';
import FormStepper from '~/import/offline_transfer/components/form_stepper.vue';
import ImportConfigTab from '~/import/offline_transfer/import/import_config_tab.vue';
import ReviewImportTab from '~/import/offline_transfer/import/review_import_tab.vue';
import SelectDestinationTab from '~/import/offline_transfer/import/select_destination_tab.vue';
import { OFFLINE_IMPORT_TAB_HEADINGS, DESTINATION_TOP_LEVEL } from '../constants';
import { isImportStorageConfigValid } from '../storage_config_validation';

export default {
  name: 'OfflineTransferImportApp',
  components: {
    FormStepper,
    GlAlert,
    ImportConfigTab,
    ReviewImportTab,
    SelectDestinationTab,
  },
  data() {
    return {
      destinationConfig: {
        type: DESTINATION_TOP_LEVEL,
        parentGroup: null,
      },
      showDestinationConfigTabError: false,
      storageConfig: {
        accessKeyId: '',
        secretAccessKey: '',
        region: '',
        bucketName: '',
        pathStyle: false,
        exportPrefix: '',
      },
      showStorageConfigTabError: false,
      hasSubmitSucceeded: false,
      submissionError: '',
    };
  },
  computed: {
    isDestinationValid() {
      return (
        this.destinationConfig.type === DESTINATION_TOP_LEVEL ||
        Boolean(this.destinationConfig.parentGroup)
      );
    },
  },
  methods: {
    validateStep(stepIndex) {
      switch (stepIndex) {
        case 0:
          return this.isDestinationValid;
        case 1:
          return isImportStorageConfigValid(this.storageConfig);
        case 2:
          return true;
        default:
          return false;
      }
    },
    onValidationFailed(stepIndex) {
      if (stepIndex === 0) {
        this.showDestinationConfigTabError = true;
      } else if (stepIndex === 1) {
        this.showStorageConfigTabError = true;
      }
    },
    onStepChanged({ previousTabIndex }) {
      if (previousTabIndex === 0) {
        this.showDestinationConfigTabError = false;
      } else if (previousTabIndex === 1) {
        this.showStorageConfigTabError = false;
      }
    },
    submitForm() {
      this.hasSubmitSucceeded = true;
    },
  },
  STEPS: OFFLINE_IMPORT_TAB_HEADINGS,
};
</script>

<template>
  <div>
    <gl-alert
      v-if="hasSubmitSucceeded"
      :title="__('Complete')"
      :dismiss-label="__('Dismiss')"
      dismissible
      variant="info"
      data-testid="completion-alert"
      @dismiss="hasSubmitSucceeded = false"
    />

    <header class="gl-my-5">
      <h1 class="gl-heading-display">
        {{ s__('OfflineTransferImport|Import for offline transfer') }}
      </h1>
      <p class="gl-max-w-2xl" data-testid="offline-import-subheading">
        {{
          s__(
            'OfflineTransferImport|Import your exported groups from an AWS S3 storage service you control. Each group is imported with all of its subgroups and projects.',
          )
        }}
      </p>
    </header>

    <form-stepper
      :steps="$options.STEPS"
      :validate-step="validateStep"
      :completion-button-text="s__('OfflineTransferImport|Start import')"
      :is-form-complete="hasSubmitSucceeded"
      @complete="submitForm"
      @validation-failed="onValidationFailed"
      @stepped-back="onStepChanged"
      @stepped-forward="onStepChanged"
    >
      <template #step-0>
        <select-destination-tab
          :destination-selection="destinationConfig"
          :validation-attempted="showDestinationConfigTabError"
          @destination-input="destinationConfig = $event"
        />
      </template>
      <template #step-1>
        <import-config-tab
          :storage-config="storageConfig"
          :validation-attempted="showStorageConfigTabError"
          @storage-input="storageConfig = $event"
        />
      </template>
      <template #step-2>
        <h2 v-if="!hasSubmitSucceeded" class="gl-heading-3">
          {{ s__('OfflineTransferImport|Review and import') }}
        </h2>
        <review-import-tab
          :destination-config="destinationConfig"
          :storage-config="storageConfig"
          :has-submit-succeeded="hasSubmitSucceeded"
          :submission-error="submissionError"
        />
      </template>
    </form-stepper>
  </div>
</template>

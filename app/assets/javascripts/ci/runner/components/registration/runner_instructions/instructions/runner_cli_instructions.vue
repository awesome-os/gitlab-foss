<script>
import { GlButton, GlCollapsibleListbox, GlLoadingIcon } from '@gitlab/ui';
import SimpleCopyButton from '~/vue_shared/components/simple_copy_button.vue';
import { REGISTRATION_TOKEN_PLACEHOLDER } from '../constants';
import getRunnerSetupInstructionsQuery from '../graphql/get_runner_setup.query.graphql';

export default {
  name: 'RunnerCliInstructions',
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlLoadingIcon,
    SimpleCopyButton,
  },
  props: {
    platform: {
      type: Object,
      required: false,
      default: null,
    },
    registrationToken: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['close', 'error'],
  data() {
    return {
      selectedArchName: this.platform?.architectures[0]?.name || null,
      instructions: null,
    };
  },
  apollo: {
    instructions: {
      query: getRunnerSetupInstructionsQuery,
      skip() {
        return !this.platform || !this.selectedArchitecture;
      },
      variables() {
        return {
          platform: this.platform.name,
          architecture: this.selectedArchitecture.name,
        };
      },
      update(data) {
        return data?.runnerSetup;
      },
      error() {
        this.$emit('error');
      },
    },
  },
  computed: {
    architectures() {
      return this.platform?.architectures || [];
    },
    selectedArchitecture() {
      return this.architectures.find(({ name }) => name === this.selectedArchName) || null;
    },
    binaryUrl() {
      return this.selectedArchitecture?.downloadLocation;
    },
    registerInstructionsWithToken() {
      const { registerInstructions } = this.instructions || {};

      if (this.registrationToken) {
        return registerInstructions?.replace(
          REGISTRATION_TOKEN_PLACEHOLDER,
          this.registrationToken,
        );
      }
      return registerInstructions;
    },
    listboxItems() {
      return this.architectures.map(({ name }) => {
        return { text: name, value: name };
      });
    },
  },
  watch: {
    platform() {
      // reset selection if architecture is not in this list
      const arch = this.architectures.find(({ name }) => name === this.selectedArchName);
      if (!arch) {
        this.selectedArchName = this.architectures[0]?.name || null;
      }
    },
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <div>
    <h5>
      {{ s__('Runners|Architecture') }}
      <gl-loading-icon v-if="$apollo.loading" size="sm" inline />
    </h5>

    <gl-collapsible-listbox v-model="selectedArchName" class="gl-mb-3" :items="listboxItems" />
    <div class="gl-mb-3 gl-items-center @sm/panel:gl-flex">
      <h5>{{ s__('Runners|Download and install binary') }}</h5>
      <gl-button
        v-if="binaryUrl"
        class="gl-ml-auto"
        :href="binaryUrl"
        download
        icon="download"
        data-testid="binary-download-button"
      >
        {{ s__('Runners|Download latest binary') }}
      </gl-button>
    </div>

    <template v-if="instructions">
      <div class="gl-flex">
        <pre class="gl-bg-gray gl-grow gl-whitespace-pre-line" data-testid="binary-instructions">{{
          instructions.installInstructions
        }}</pre>
        <simple-copy-button
          :title="s__('Runners|Copy instructions')"
          :text="instructions.installInstructions"
          class="gl-ml-2 gl-mt-2 gl-self-start"
          category="tertiary"
        />
      </div>
      <h5 class="gl-mb-3">{{ s__('Runners|Command to register runner') }}</h5>
      <div class="gl-flex">
        <pre class="gl-bg-gray gl-grow gl-whitespace-pre-line" data-testid="register-command">{{
          registerInstructionsWithToken
        }}</pre>
        <simple-copy-button
          :title="s__('Runners|Copy command')"
          :text="registerInstructionsWithToken"
          class="gl-ml-2 gl-mt-2 gl-self-start"
          category="tertiary"
        />
      </div>
    </template>

    <footer class="gl-flex gl-justify-end gl-pt-3">
      <gl-button @click="onClose()">{{ __('Close') }}</gl-button>
    </footer>
  </div>
</template>

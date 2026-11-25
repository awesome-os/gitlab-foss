<script>
import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'RegistrationToken',
  components: {
    InputCopyToggleVisibility,
  },
  mixins: [glSlotsMixin],
  props: {
    inputId: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    formInputGroupProps() {
      return {
        id: this.inputId,
      };
    },
  },
};
</script>
<template>
  <input-copy-toggle-visibility
    class="gl-m-0"
    :value="value"
    :label="s__('Runners|Registration token')"
    :label-for="inputId"
    :copy-button-title="s__('Runners|Copy registration token')"
    :form-input-group-props="formInputGroupProps"
    readonly
  >
    <template v-for="slot in Object.keys(glSlots())" #[slot]>
      <slot :name="slot"></slot>
    </template>
  </input-copy-toggle-visibility>
</template>

<script>
import { GlFormGroup, GlFormInput, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { __ } from '~/locale';
import validation, { initForm } from '~/vue_shared/directives/validation';
import BooleanCell from './boolean_cell.vue';
import DropdownCell from './dropdown_cell.vue';

/**
 * DynamicValueRenderer
 *
 * This component dynamically renders the appropriate input field based on the data type.
 * It supports multiple input types:
 * - Boolean: Rendered as a dropdown with true/false options
 * - Array: Rendered as a text area input field unless options are included
 * - Number: Rendered as a number input field unless options are included
 * - String/Others: Rendered as a text input field unless options are included
 *
 * The component emits update events when values change, allowing parent components
 * to track and manage the state of these inputs.
 */

const INPUT_TYPES = {
  ARRAY: 'ARRAY',
  BOOLEAN: 'BOOLEAN',
  NUMBER: 'NUMBER',
  STRING: 'STRING',
};

const MAX_NUMBER_VALUE = Number.MAX_SAFE_INTEGER;
const MIN_NUMBER_VALUE = Number.MIN_SAFE_INTEGER;

const VALIDATION_MESSAGES = {
  ARRAY_FORMAT_MISMATCH: __(
    'The value must be a valid JSON array format: [1,2,3] or [{"key": "value"}]',
  ),
  GENERAL_FORMAT_MISMATCH: __('Please match the requested format.'),
  VALUE_MISSING: __('This is required and must be defined.'),
};

const feedbackMap = {
  arrayFormatMismatch: {
    isInvalid: (el) => {
      if (el.dataset.jsonArray !== 'true' || !el.value) return false;

      try {
        const isValid = Array.isArray(JSON.parse(el.value));
        // we use setCustomValidity to set the message that appears when the user clicks submit
        el.setCustomValidity(isValid ? '' : VALIDATION_MESSAGES.GENERAL_FORMAT_MISMATCH);
        return !isValid;
      } catch {
        el.setCustomValidity(VALIDATION_MESSAGES.GENERAL_FORMAT_MISMATCH);
        return true;
      }
    },
    message: __('The value must be a valid JSON array format: [1,2,3] or [{"key": "value"}]'),
  },
  valueMissing: {
    isInvalid: (el) => el.validity?.valueMissing,
    message: VALIDATION_MESSAGES.VALUE_MISSING,
  },
};

export default {
  name: 'DynamicValueRenderer',
  MAX_NUMBER_VALUE,
  MIN_NUMBER_VALUE,
  components: {
    BooleanCell,
    DropdownCell,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlSprintf,
  },
  directives: {
    validation: validation(feedbackMap),
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['update'],
  data() {
    return {
      form: initForm({
        fields: {
          [this.item.name]: {
            value: this.item.value,
            required: this.item.required || false,
          },
        },
        showValidation: true,
      }),
    };
  },
  computed: {
    inputValue: {
      get() {
        return this.convertToDisplayValue(this.item.value);
      },
      set(newValue) {
        if (newValue === this.convertToDisplayValue(this.item.value)) return;

        // convert to number if number type
        const value = this.item.type === INPUT_TYPES.NUMBER ? Number(newValue) : newValue;
        this.emitUpdate({ value });
      },
    },
    hasArrayFormatError() {
      const field = this.form.fields[this.item.name];
      return this.isArrayType && field?.feedback === feedbackMap.arrayFormatMismatch.message;
    },
    hasValidationFeedback() {
      return Boolean(this.validationFeedback);
    },
    isArrayType() {
      return this.item.type === INPUT_TYPES.ARRAY && Boolean(!this.item.options?.length);
    },
    isBooleanType() {
      return this.item.type === INPUT_TYPES.BOOLEAN && !this.item.options?.length;
    },
    isNumberType() {
      return this.item.type === INPUT_TYPES.NUMBER && !this.item.options?.length;
    },
    inputId() {
      return uniqueId('pipeline-input-');
    },
    showPattern() {
      return Boolean(this.item.regex);
    },
    isDropdown() {
      return Boolean(this.item.options?.length);
    },
    validationFeedback() {
      return this.form.fields[this.item.name]?.feedback || '';
    },
    validationState() {
      // Override validation state for array format errors for our custom validation
      // This is also responsible for turning the border red when the input is invalid
      if (this.hasArrayFormatError) {
        return false;
      }

      const field = this.form.fields[this.item.name];
      return field?.state;
    },
  },
  methods: {
    convertToDisplayValue(value) {
      if (value == null || value === '') {
        return '';
      }

      return this.item.type === INPUT_TYPES.ARRAY && Array.isArray(value)
        ? JSON.stringify(value)
        : value;
    },
    emitUpdate({ value }) {
      this.$emit('update', {
        item: this.item,
        value,
      });
    },
  },
};
</script>

<template>
  <gl-form-group class="gl-mb-0" :label-for="inputId" :state="validationState">
    <!-- Dropdown for any type with options -->
    <dropdown-cell v-if="isDropdown" :input="item" :toggle-id="inputId" @update="emitUpdate" />

    <!-- Button cell for boolean types -->
    <boolean-cell v-else-if="isBooleanType" :input="item" @update="emitUpdate" />

    <!-- Textarea for arrays without options -->
    <gl-form-textarea
      v-else-if="isArrayType"
      :id="inputId"
      v-model="inputValue"
      v-validation:[form.showValidation]
      :aria-label="item.name"
      :data-json-array="'true'"
      :name="item.name"
      :required="item.required"
      :state="validationState"
      rows="3"
    />

    <!-- Number input for numbers without options -->
    <gl-form-input
      v-else-if="isNumberType"
      :id="inputId"
      v-model="inputValue"
      v-validation:[form.showValidation]
      step="any"
      type="number"
      :aria-label="item.name"
      :data-field-type="item.type"
      :min="$options.MIN_NUMBER_VALUE"
      :max="$options.MAX_NUMBER_VALUE"
      :name="item.name"
      :required="item.required"
      :state="validationState"
    />

    <!-- Text input for strings without options -->
    <gl-form-input
      v-else
      :id="inputId"
      v-model="inputValue"
      v-validation:[form.showValidation]
      :aria-label="item.name"
      :data-field-type="item.type"
      :name="item.name"
      :required="item.required"
      :state="validationState"
    />

    <!-- Pattern the backend will enforce -->

    <template v-if="showPattern" #description>
      <span class="gl-break-all gl-text-sm" data-testid="input-pattern">
        <gl-sprintf :message="s__('Pipelines|Pattern: %{pattern}')">
          <template #pattern>
            <code>{{ item.regex }}</code>
          </template>
        </gl-sprintf>
      </span>
    </template>

    <!-- Validation feedback -->

    <template v-if="hasValidationFeedback" #invalid-feedback>
      <span data-testid="validation-feedback">{{ validationFeedback }}</span>
    </template>
  </gl-form-group>
</template>

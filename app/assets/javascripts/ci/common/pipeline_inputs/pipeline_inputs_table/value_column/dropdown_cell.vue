<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __, sprintf } from '~/locale';

export default {
  name: 'DropdownCell',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    input: {
      type: Object,
      required: true,
    },
    toggleId: {
      type: String,
      required: true,
    },
  },
  emits: ['update'],
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    inputValue: {
      get() {
        const { value } = this.input;
        return value == null ? '' : value;
      },
      set(newValue) {
        if (newValue === this.inputValue) return;

        const value = this.input.type === 'NUMBER' ? Number(newValue) : newValue;
        this.$emit('update', { input: this.input, value });
      },
    },
    isMultiSelect() {
      return this.input.type === 'ARRAY';
    },
    dropdownOptions() {
      return this.input.options.map((option) => ({ value: option, text: String(option) }));
    },
    filteredDropdownOptions() {
      if (!this.searchTerm) {
        return this.dropdownOptions;
      }

      const term = this.searchTerm.toLowerCase();
      return this.dropdownOptions.filter((item) => item.text.toLowerCase().includes(term));
    },
    toggleText() {
      const value = this.inputValue;
      const isEmpty = value === '' || (Array.isArray(value) && !value.length);

      if (isEmpty) {
        return __('Select option');
      }

      if (this.isMultiSelect) {
        return value.length > 1
          ? sprintf(__('%{number} options selected'), { number: value.length })
          : String(value[0]);
      }

      return String(value);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="inputValue"
    block
    searchable
    :multiple="isMultiSelect"
    :aria-label="input.name"
    :toggle-id="toggleId"
    toggle-class="!gl-pl-4"
    :toggle-text="toggleText"
    :header-text="__('Options')"
    :items="filteredDropdownOptions"
    @search="searchTerm = $event"
  />
</template>

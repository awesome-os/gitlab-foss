<script>
import { GlDisclosureDropdownItem, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';

export default {
  name: 'WorkItemDisplaySettingsEmptyGroups',
  components: {
    GlDisclosureDropdownItem,
    GlToggle,
  },
  mixins: [InternalEvents.mixin()],
  i18n: {
    showEmptyGroups: s__('WorkItems|Show empty groups'),
  },
  props: {
    namespacePreferences: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['update-settings'],
  computed: {
    showEmptyGroups() {
      return this.namespacePreferences.showEmptyGroups ?? true;
    },
  },
  methods: {
    toggleShowEmptyGroups() {
      const showEmptyGroups = !this.showEmptyGroups;
      const input = { ...this.namespacePreferences, showEmptyGroups };

      this.trackEvent('configure_columns_on_work_item_board', {
        label: showEmptyGroups ? 'show_empty_groups' : 'hide_empty_groups',
      });

      this.$emit('update-settings', input);
    },
  },
};
</script>

<template>
  <ul class="gl-m-0 gl-list-none gl-px-2 gl-py-1" data-testid="display-settings-empty-groups">
    <gl-disclosure-dropdown-item class="work-item-dropdown-toggle" @action="toggleShowEmptyGroups">
      <template #list-item>
        <gl-toggle
          :value="showEmptyGroups"
          :label="$options.i18n.showEmptyGroups"
          class="gl-w-full gl-justify-between"
          label-position="left"
        />
      </template>
    </gl-disclosure-dropdown-item>
  </ul>
</template>

<script>
import { GlButton } from '@gitlab/ui';
import { JS_TOGGLE_EXPAND_CLASS } from '../constants';
import { toggleSuperSidebarCollapsed } from '../super_sidebar_collapsed_state_manager';

export default {
  name: 'SuperSidebarToggle',
  components: {
    GlButton,
  },
  // The Esc handler in super_sidebar.vue returns focus to this class when
  // closing the overlaying sidebar.
  expandClass: JS_TOGGLE_EXPAND_CLASS,
  methods: {
    openSidebar() {
      toggleSuperSidebarCollapsed(false);
    },
  },
};
</script>

<template>
  <gl-button
    :class="$options.expandClass"
    aria-controls="super-sidebar"
    aria-expanded="false"
    :aria-label="__('Open navigation menu')"
    icon="hamburger"
    data-testid="super-sidebar-toggle-button"
    category="tertiary"
    @click="openSidebar"
  />
</template>

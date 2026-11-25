<script>
import { GlDisclosureDropdownItem, GlLink } from '@gitlab/ui';
import { CLICK_MENU_ITEM_ACTION, TRACKING_UNKNOWN_ID, TRACKING_UNKNOWN_PANEL } from '../constants';

export default {
  name: 'DisclosureNavItem',
  components: { GlDisclosureDropdownItem, GlLink },
  props: {
    item: {
      type: Object,
      required: true,
    },
    panelType: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    // `text` satisfies the item validator; we render the link ourselves.
    structure() {
      return { text: this.item.title };
    },
    linkAttrs() {
      const { panelType } = this;
      const extra =
        !this.item.id || !panelType
          ? { 'data-track-extra': JSON.stringify({ title: this.item.title }) }
          : {};
      return {
        'aria-current': this.item.is_active ? 'page' : null,
        'data-method': this.item.data_method,
        'data-qa-submenu-item': this.item.title,
        'data-track-action': CLICK_MENU_ITEM_ACTION,
        'data-track-label': this.item.id ?? TRACKING_UNKNOWN_ID,
        'data-track-property': panelType ? `nav_panel_${panelType}` : TRACKING_UNKNOWN_PANEL,
        ...extra,
      };
    },
  },
  mounted() {
    // With a custom default slot, GlDisclosureDropdownItem does not activate
    // the link on Enter/Space (it only emits an unused `action` event, then the
    // dropdown closes). Handle those keys on the item's <li> and click the link
    // ourselves so the item navigates.
    this.$refs.item.$el.addEventListener('keydown', this.onKeydown);
  },
  beforeDestroy() {
    this.$refs.item.$el.removeEventListener('keydown', this.onKeydown);
  },
  methods: {
    onKeydown(event) {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      event.preventDefault();
      event.stopPropagation();
      this.$refs.link.$el.click();
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown-item ref="item" :item="structure">
    <template #default>
      <gl-link
        ref="link"
        class="gl-new-dropdown-item-content"
        :href="item.link"
        variant="unstyled"
        :tabindex="-1"
        v-bind="linkAttrs"
      >
        <span class="gl-new-dropdown-item-text-wrapper">{{ item.title }}</span>
      </gl-link>
    </template>
  </gl-disclosure-dropdown-item>
</template>

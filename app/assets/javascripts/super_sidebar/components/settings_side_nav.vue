<script>
import { GlNavItem } from '@gitlab/ui';
import { CLICK_MENU_ITEM_ACTION, TRACKING_UNKNOWN_PANEL } from '../constants';
import { isNavItemHidden } from '../utils';
import MenuSection from './menu_section.vue';

const visibleItems = (items) => items.filter((navItem) => !isNavItemHidden(navItem));

export default {
  name: 'SettingsSideNav',
  CLICK_MENU_ITEM_ACTION,
  components: {
    GlNavItem,
    MenuSection,
  },
  inject: {
    panelType: { default: '' },
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    navItems() {
      return visibleItems(this.item.items);
    },
    links() {
      return this.navItems.filter((navItem) => !navItem.items?.length);
    },
    // Nested sections (e.g. user settings' Access) render as headed groups below the links.
    groups() {
      return this.navItems.flatMap((navItem) => {
        if (!navItem.items?.length) return [];

        const items = visibleItems(navItem.items);
        return items.length ? [{ ...navItem, items }] : [];
      });
    },
    trackingProperty() {
      return this.panelType ? `nav_panel_${this.panelType}` : TRACKING_UNKNOWN_PANEL;
    },
    activeNavItem() {
      return [...this.links, ...this.groups.flatMap((group) => group.items)].find(
        (navItem) => navItem.is_active,
      );
    },
    // Collapsed by default, with the current page as its toggle label.
    collapsibleItem() {
      return {
        ...this.item,
        title: this.activeNavItem?.title ?? this.item.title,
        is_active: false,
      };
    },
  },
};
</script>

<template>
  <nav class="@md:gl-sticky @md:gl-top-3" :aria-label="item.title" data-testid="settings-side-nav">
    <menu-section
      :item="collapsibleItem"
      id-prefix="settings-side-nav"
      class="gl-mt-5 gl-rounded-lg gl-border-1 gl-border-solid gl-border-strong gl-p-3 @md:gl-hidden"
      data-testid="settings-side-nav-section"
    />
    <ul
      class="gl-m-0 gl-hidden gl-list-none gl-flex-col gl-gap-1 gl-overflow-y-auto gl-p-0 gl-px-5 gl-pt-3 @md:gl-flex"
      style="max-height: calc(var(--panel-content-inner-height, 100vh) - var(--gl-spacing-scale-5))"
    >
      <li v-for="navItem in links" :key="navItem.id">
        <gl-nav-item
          :href="navItem.link"
          :selected="navItem.is_active"
          :data-track-action="$options.CLICK_MENU_ITEM_ACTION"
          :data-track-label="navItem.id"
          :data-track-property="trackingProperty"
          class="before:gl-hidden"
          data-testid="settings-side-nav-item"
        >
          {{ navItem.title }}
        </gl-nav-item>
      </li>
      <li v-for="group in groups" :key="group.id" data-testid="settings-side-nav-group">
        <div
          :id="`settings-side-nav-group-${group.id}`"
          class="gl-px-3 gl-pb-2 gl-pt-4 gl-text-sm gl-font-semibold gl-text-subtle"
        >
          {{ group.title }}
        </div>
        <ul
          :aria-labelledby="`settings-side-nav-group-${group.id}`"
          class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-1 gl-p-0"
        >
          <li v-for="navItem in group.items" :key="navItem.id">
            <gl-nav-item
              :href="navItem.link"
              :selected="navItem.is_active"
              :data-track-action="$options.CLICK_MENU_ITEM_ACTION"
              :data-track-label="navItem.id"
              :data-track-property="trackingProperty"
              class="before:gl-hidden"
              data-testid="settings-side-nav-item"
            >
              {{ navItem.title }}
            </gl-nav-item>
          </li>
        </ul>
      </li>
    </ul>
  </nav>
</template>

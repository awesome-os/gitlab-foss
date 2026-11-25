<script>
import { kebabCase } from 'lodash-es';
import {
  GlCollapse,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlIcon,
  GlNavItem,
  GlAnimatedChevronRightDownIcon,
  GlOutsideDirective as Outside,
  GlTooltipDirective,
} from '@gitlab/ui';
import { isNavItemHidden } from '../utils';
import NavItem from './nav_item.vue';
import FlyoutMenu from './flyout_menu.vue';
import DisclosureNavItem from './disclosure_nav_item.vue';

const visibleItems = (items) => items.filter((item) => !isNavItemHidden(item));

export default {
  name: 'MenuSection',
  components: {
    GlCollapse,
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlIcon,
    GlNavItem,
    GlAnimatedChevronRightDownIcon,
    NavItem,
    FlyoutMenu,
    DisclosureNavItem,
  },
  directives: { Outside, GlTooltip: GlTooltipDirective },
  inject: {
    isIconOnly: { default: false },
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: false,
      default: false,
    },
    tag: {
      type: String,
      required: false,
      default: 'div',
    },
    hasFlyout: {
      type: Boolean,
      required: false,
      default: false,
    },
    disclosure: {
      type: Boolean,
      required: false,
      default: false,
    },
    // Only read by disclosure items, for their tracking attributes.
    panelType: {
      type: String,
      required: false,
      default: '',
    },
    headerless: {
      type: Boolean,
      required: false,
      default: false,
    },
    boldTitle: {
      type: Boolean,
      required: false,
      default: false,
    },
    // Hides the chevron until the header is hovered or keyboard-focused, on devices
    // that can hover. Touch devices always show it.
    revealChevronOnHover: {
      type: Boolean,
      required: false,
      default: false,
    },
    asyncCount: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    // Collapses the section even when it holds the active page. The header
    // then shows the active indicator instead. Changing it only affects an
    // active section; other sections keep their state.
    collapseActive: {
      type: Boolean,
      required: false,
      default: false,
    },
    // Keeps element ids unique when the section also renders outside the sidebar.
    idPrefix: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['collapse-toggle', 'nav-link-click', 'pin-add', 'pin-remove'],
  data() {
    return {
      isExpanded: Boolean(this.headerless || this.expanded || this.expandsWhenActive()),
      isMouseOverSection: false,
      isMouseOverFlyout: false,
      keepFlyoutClosed: false,
    };
  },
  computed: {
    navItems() {
      return visibleItems(this.item.items);
    },
    // A section can hold nested sections (e.g. user settings' Access), which
    // render as headed groups below the top-level links.
    sectionLinks() {
      return this.navItems.filter((navItem) => !navItem.items?.length);
    },
    nestedSections() {
      return this.navItems.flatMap((navItem) => {
        if (!navItem.items?.length) return [];

        const items = visibleItems(navItem.items);
        return items.length ? [{ ...navItem, items }] : [];
      });
    },
    flyoutItems() {
      return [...this.sectionLinks, ...this.nestedSections.flatMap((section) => section.items)];
    },
    buttonProps() {
      return {
        'aria-controls': this.itemId,
        'aria-expanded': String(this.isExpanded),
        'data-qa-menu-item': this.item.title,
      };
    },
    computedLinkClasses() {
      return {
        'with-mouse-over-flyout': this.isMouseOverFlyout,
        'super-sidebar-category-toggle': this.revealChevronOnHover,
      };
    },
    isActive() {
      return (!this.isExpanded || this.isIconOnly) && this.item.is_active;
    },
    itemId() {
      return kebabCase(`${this.idPrefix} ${this.item.title}`);
    },
    isMouseOver() {
      return this.isMouseOverSection || this.isMouseOverFlyout;
    },
    showExpanded() {
      return !this.isIconOnly && this.isExpanded;
    },
    // The disclosure button sits outside the panel, so it uses the qualified
    // label ("Project settings") where the backend supplies one.
    disclosureTitle() {
      return this.item.disclosure_title || this.item.title;
    },
    // Only the collapsed sidebar needs a tooltip, where the label is hidden.
    toggleTooltip() {
      if (!this.isIconOnly) return { title: '' };

      return { title: this.disclosureTitle, placement: 'right' };
    },
    // A headerless section has no toggle to reveal its items, so keep the
    // collapse open regardless of the (stale) expanded state carried over from
    // the expanded sidebar.
    collapseVisible() {
      return this.headerless || this.isExpanded;
    },
    showFlyout() {
      return (
        !this.headerless &&
        this.hasFlyout &&
        this.isMouseOver &&
        !this.showExpanded &&
        !this.keepFlyoutClosed &&
        this.flyoutItems.length > 0
      );
    },
  },
  watch: {
    isExpanded(newIsExpanded) {
      this.$emit('collapse-toggle', newIsExpanded);
      this.keepFlyoutClosed = !newIsExpanded && !this.isIconOnly;
      if (!newIsExpanded) {
        this.isMouseOverFlyout = false;
      }
    },
    isIconOnly(newIsIconOnly) {
      // Reset keepFlyoutClosed when toggling between expanded/collapsed sidebar
      if (newIsIconOnly) {
        this.keepFlyoutClosed = false;
      }
    },
    headerless(newHeaderless) {
      // A headerless section is force-expanded, so isExpanded may have been
      // initialized to true regardless of the real (cookie-backed) state. When
      // the header reappears, re-sync to the actual expanded prop so the group
      // honors its own collapse state instead of staying stuck open.
      if (!newHeaderless) {
        this.isExpanded = Boolean(this.expanded || this.expandsWhenActive());
      }
    },
    collapseActive() {
      if (this.headerless || this.disclosure || !this.item.is_active) return;

      this.isExpanded = this.expandsWhenActive();
    },
  },
  methods: {
    expandsWhenActive() {
      return this.item.is_active && !this.collapseActive && !this.item.keep_collapsed;
    },
    onCollapseInput(visible) {
      // Ignore the forced-open state of a headerless section so its stale
      // expanded state (from the expanded sidebar) is preserved.
      if (this.headerless) return;
      this.isExpanded = visible;
    },
    handleClick() {
      if (this.isIconOnly) {
        this.isMouseOverSection = !this.isMouseOverSection; // Allows touch devices to open the flyout menus by touch
        return;
      }
      this.isExpanded = !this.isExpanded;
    },
    handleClickOutside(targetId) {
      this.isMouseOverSection = false; // Allows touch devices to close the flyout menus by touch
      if (targetId) {
        document.getElementById(targetId)?.focus();
      }
    },
    handlePointerover(e) {
      if (!this.hasFlyout) return;

      this.isMouseOverSection = e.pointerType === 'mouse' || e.pointerType === 'pen';
    },
    handlePointerleave(e) {
      if (!this.hasFlyout) return;

      this.keepFlyoutClosed = false;

      // delay state change. otherwise the flyout menu gets removed before it
      // has a chance to emit its mouseover event.
      // checks pointer type to not mess with touch devices, which fire a pointerleave event before
      // every click!
      if (e.pointerType === 'mouse' || e.pointerType === 'pen') {
        setTimeout(() => {
          this.isMouseOverSection = false;
        }, 5);
      }
    },
  },
};
</script>

<template>
  <component :is="tag">
    <gl-disclosure-dropdown v-if="disclosure" class="super-sidebar-settings-dropdown" block>
      <template #toggle="{ accessibilityAttributes }">
        <gl-nav-item
          v-gl-tooltip="toggleTooltip"
          :icon="item.icon"
          :is-icon-only="isIconOnly"
          :aria-label="disclosureTitle"
          :selected="item.is_active"
          data-testid="menu-section-button"
          :data-qa-section-name="item.title"
          v-bind="accessibilityAttributes"
        >
          {{ disclosureTitle }}
        </gl-nav-item>
      </template>

      <gl-disclosure-dropdown-group v-if="sectionLinks.length">
        <disclosure-nav-item
          v-for="navItem in sectionLinks"
          :key="navItem.id"
          :item="navItem"
          :panel-type="panelType"
        />
      </gl-disclosure-dropdown-group>
      <gl-disclosure-dropdown-group
        v-for="(section, index) in nestedSections"
        :key="section.id"
        :bordered="index > 0 || sectionLinks.length > 0"
        data-testid="disclosure-section-group"
      >
        <template #group-label>{{ section.title }}</template>
        <disclosure-nav-item
          v-for="navItem in section.items"
          :key="navItem.id"
          :item="navItem"
          :panel-type="panelType"
        />
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>

    <gl-nav-item
      v-if="!disclosure && !headerless"
      :id="`menu-section-button-${itemId}`"
      v-outside="handleClickOutside"
      class="gl-relative gl-mb-1"
      :class="computedLinkClasses"
      data-testid="menu-section-button"
      :data-qa-section-name="item.title"
      :aria-label="item.title"
      :icon="item.icon"
      :is-icon-only="isIconOnly"
      :expanded="isExpanded"
      :selected="isActive"
      is-parent
      v-bind="buttonProps"
      @click="handleClick"
      @escape="handleClickOutside"
      @pointerover="handlePointerover"
      @pointerleave="handlePointerleave"
    >
      <span
        class="gl-truncate-end menu-section-button-label"
        :class="{ 'gl-font-bold': boldTitle }"
      >
        {{ item.title }}
      </span>
    </gl-nav-item>

    <flyout-menu
      v-if="!disclosure && showFlyout"
      :target-id="`menu-section-button-${itemId}`"
      :title="item.title"
      :items="flyoutItems"
      :async-count="asyncCount"
      @mouseover="isMouseOverFlyout = true"
      @mouseleave="isMouseOverFlyout = false"
      @pin-add="(itemId, itemTitle) => $emit('pin-add', itemId, itemTitle)"
      @pin-remove="(itemId, itemTitle) => $emit('pin-remove', itemId, itemTitle)"
      @nav-link-click="$emit('nav-link-click')"
      @nav-item-keydown-esc="handleClickOutside"
      @nav-pin-keydown-esc="handleClickOutside"
    />

    <!-- Hide with a class, not `visible`: GlCollapse's transitions set inline `display`. -->
    <gl-collapse
      v-if="!disclosure"
      :id="itemId"
      :visible="collapseVisible"
      :class="{ 'gl-hidden': isIconOnly && !headerless }"
      class="gl-m-0 gl-list-none gl-p-0 gl-transition-[height] gl-duration-medium gl-ease-ease"
      data-testid="menu-section"
      :data-qa-section-name="item.title"
      @input="onCollapseInput"
    >
      <slot>
        <ul :aria-label="item.title" class="gl-m-0 gl-list-none gl-p-0">
          <nav-item
            v-for="subItem of sectionLinks"
            :key="`${item.title}-${subItem.title}`"
            :item="subItem"
            :async-count="asyncCount"
            hide-icon
            @pin-add="(itemId, itemTitle) => $emit('pin-add', itemId, itemTitle)"
            @pin-remove="(itemId, itemTitle) => $emit('pin-remove', itemId, itemTitle)"
            @nav-link-click="$emit('nav-link-click')"
          />
        </ul>
        <div v-for="section in nestedSections" :key="section.id" data-testid="menu-section-group">
          <div class="gl-mx-2 gl-flex gl-gap-2 gl-pb-2 gl-pl-2 gl-pt-3">
            <span class="gl-w-6 gl-shrink-0" aria-hidden="true"></span>
            <span
              :id="`${itemId}-${section.id}`"
              class="gl-text-sm gl-font-semibold gl-text-subtle"
            >
              {{ section.title }}
            </span>
          </div>
          <ul :aria-labelledby="`${itemId}-${section.id}`" class="gl-m-0 gl-list-none gl-p-0">
            <nav-item
              v-for="subItem of section.items"
              :key="`${section.title}-${subItem.title}`"
              :item="subItem"
              :async-count="asyncCount"
              hide-icon
              @pin-add="(itemId, itemTitle) => $emit('pin-add', itemId, itemTitle)"
              @pin-remove="(itemId, itemTitle) => $emit('pin-remove', itemId, itemTitle)"
              @nav-link-click="$emit('nav-link-click')"
            />
          </ul>
        </div>
      </slot>
    </gl-collapse>
  </component>
</template>

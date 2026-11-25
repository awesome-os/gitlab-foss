<script>
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { SCROLL_CONTAINER_SELECTOR, syncSidebarSpace } from '~/detail_layout_sidebar';
import BaseLayout from './base_layout.vue';
import DetailLayoutSkeleton from './detail_layout_skeleton.vue';

export default {
  name: 'DetailLayout',
  components: { BaseLayout, DetailLayoutSkeleton },
  mixins: [glSlotsMixin],
  props: {
    ...BaseLayout.props,
    showSidebar: {
      type: Boolean,
      required: false,
      default: true,
    },
    sidebarLabel: {
      type: String,
      required: false,
      default: null,
    },
  },
  watch: {
    loading() {
      // The sidebar only renders once loading is done, so (re-)wire against it then.
      this.$nextTick(this.setupSidebarSync);
    },
  },
  mounted() {
    this.$nextTick(this.setupSidebarSync);
    window.addEventListener('resize', this.scheduleSyncSidebarSpace);
  },
  beforeDestroy() {
    cancelAnimationFrame(this.syncFrame);
    this.scrollContainer?.removeEventListener('scroll', this.scheduleSyncSidebarSpace);
    window.removeEventListener('resize', this.scheduleSyncSidebarSpace);
    this.contentResizeObserver?.disconnect();
  },
  methods: {
    setupSidebarSync() {
      const scrollContainer = this.$refs.sidebar?.closest(SCROLL_CONTAINER_SELECTOR);
      if (!scrollContainer || scrollContainer === this.scrollContainer) return;

      // Detach from a previously resolved container so it can't leak a listener.
      this.scrollContainer?.removeEventListener('scroll', this.scheduleSyncSidebarSpace);
      this.scrollContainer = scrollContainer;
      this.scrollContainer.addEventListener('scroll', this.scheduleSyncSidebarSpace, {
        passive: true,
      });

      // Re-measure when content above the sidebar changes height after mount.
      this.contentResizeObserver?.disconnect();
      if (typeof ResizeObserver !== 'undefined') {
        this.contentResizeObserver = new ResizeObserver(this.scheduleSyncSidebarSpace);
        this.contentResizeObserver.observe(this.$el);
      }

      this.syncSidebarSpace();
    },
    onStickyChange() {
      // The sticky header height moves the stuck sidebar without a scroll event.
      this.scheduleSyncSidebarSpace();
    },
    scheduleSyncSidebarSpace() {
      // Coalesce bursts of scroll/resize events into one measurement per frame.
      cancelAnimationFrame(this.syncFrame);
      this.syncFrame = requestAnimationFrame(this.syncSidebarSpace);
    },
    syncSidebarSpace() {
      const { sidebar } = this.$refs;
      if (!sidebar || !this.scrollContainer) return;

      syncSidebarSpace(sidebar, this.scrollContainer);
    },
  },
};
</script>

<template>
  <base-layout
    :heading="heading"
    :heading-tag="headingTag"
    :description="description"
    :page-heading-sr-only="pageHeadingSrOnly"
    :hide-page-heading="hidePageHeading"
    :loading="loading"
    :animate-sticky-header="animateStickyHeader"
    @sticky-change="onStickyChange"
  >
    <template v-for="(_, name) in glSlots()" #[name]="slotProps">
      <slot :name="name" v-bind="slotProps || {}"></slot>
    </template>
    <template v-if="!glSlots()['loading-skeleton']" #loading-skeleton>
      <detail-layout-skeleton
        :sidebar="Boolean(glSlots().sidebar) && showSidebar"
        :widgets="Boolean(glSlots().widgets)"
        :activity="Boolean(glSlots().activity)"
      />
    </template>
    <template #content>
      <div
        class="gl-detail-layout-container"
        :class="{ 'gl-detail-layout-container-has-sidebar': glSlots().sidebar && showSidebar }"
        data-testid="detail-layout-container"
      >
        <div class="gl-detail-layout-content" data-testid="detail-layout-content">
          <slot></slot>
        </div>
        <aside
          v-if="glSlots().sidebar"
          ref="sidebar"
          class="gl-detail-layout-sidebar"
          :class="{
            'gl-contents': !showSidebar,
            'gl-detail-layout-sidebar-no-animation': !animateStickyHeader,
          }"
          data-testid="detail-layout-sidebar"
          :tabindex="showSidebar ? 0 : null"
          :aria-label="sidebarLabel || __('Sidebar')"
          @transitionend.self="scheduleSyncSidebarSpace"
        >
          <slot name="sidebar"></slot>
        </aside>
        <div
          v-if="glSlots().widgets"
          class="gl-detail-layout-widgets"
          data-testid="detail-layout-widgets"
        >
          <slot name="widgets"></slot>
        </div>
        <div
          v-if="glSlots().activity"
          class="gl-detail-layout-activity"
          data-testid="detail-layout-activity"
        >
          <slot name="activity"></slot>
        </div>
      </div>
    </template>
  </base-layout>
</template>

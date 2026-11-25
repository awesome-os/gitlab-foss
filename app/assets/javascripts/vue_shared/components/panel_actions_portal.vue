<script>
import { MountingPortal } from 'portal-vue';
import { uniqueId } from 'lodash-es';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'PanelActionsPortal',
  components: {
    MountingPortal,
  },
  mixins: [glSlotsMixin],
  data() {
    return {
      resolvedSelector: null,
    };
  },
  mounted() {
    const panelView = this.$el.closest(this.$options.panelSelector);
    if (!panelView) return;

    const target = panelView.querySelector(this.$options.targetSelector);
    if (!target) return;

    if (!target.id) {
      target.id = uniqueId('panel-actions-portal-target-');
    }

    this.resolvedSelector = `#${target.id}`;

    this.landmark = target.closest(this.$options.landmarkSelector);
    if (this.landmark && this.glSlots().default) {
      this.landmark.setAttribute('aria-label', this.landmark.dataset.label);
    }
  },
  destroyed() {
    if (!this.landmark) return;

    const target = this.landmark.querySelector(this.$options.targetSelector);
    const hasActions =
      target.children.length > 0 ||
      Array.from(this.landmark.children).some((child) => child !== target);
    if (!hasActions) this.landmark.removeAttribute('aria-label');
  },
  panelSelector: '.js-paneled-view',
  targetSelector: '.js-panel-actions-portal-target',
  landmarkSelector: '.js-panel-actions-landmark',
};
</script>

<template>
  <mounting-portal v-if="resolvedSelector" :mount-to="resolvedSelector" append>
    <template v-if="glSlots().default" #default><slot></slot></template>
  </mounting-portal>
  <div v-else hidden></div>
</template>

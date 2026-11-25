<script>
import { GlTooltip } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import SafeHtml from '~/vue_shared/directives/safe_html';

const getTooltipTitle = (element) => {
  return element.getAttribute('title') || element.dataset.title;
};

const getTooltipCustomClass = (element) => {
  return element.dataset.tooltipCustomClass;
};

const newTooltip = (element, config = {}) => {
  const { placement, html, triggers, noFade } = element.dataset;
  const title = getTooltipTitle(element);
  const customClass = getTooltipCustomClass(element);

  return {
    id: uniqueId('gl-tooltip'),
    target: element,
    title,
    html,
    placement,
    triggers,
    disabled: !title,
    customClass,
    noFade: noFade === 'true',
    ...config,
  };
};

export default {
  name: 'TooltipsWrapper',
  components: {
    GlTooltip,
  },
  directives: {
    SafeHtml,
  },
  emits: ['hidden'],
  data() {
    return {
      tooltips: [],
    };
  },
  created() {
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.removedNodes.forEach((node) => this.dispose(node));
      });
    });
  },
  beforeDestroy() {
    this.observer.disconnect();
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- addTooltips is part of the component's public API for adding tooltips dynamically.
    addTooltips(elements, config) {
      const newTooltips = elements
        .filter((element) => !this.tooltipExists(element))
        .map((element) => newTooltip(element, config))
        .filter((tooltip) => tooltip.title);

      newTooltips.forEach((tooltip) => this.observe(tooltip));

      this.tooltips.push(...newTooltips);
    },
    observe(tooltip) {
      this.observer.observe(tooltip.target.parentElement, {
        childList: true,
      });
    },
    dispose(target) {
      if (!target) {
        this.tooltips = [];
      } else {
        const index = this.tooltips.indexOf(this.findTooltipByTarget(target));

        if (index > -1) {
          this.tooltips.splice(index, 1);
        }
      }
    },
    // eslint-disable-next-line vue/no-unused-properties -- fixTitle is part of the component's public API for updating tooltip titles.
    fixTitle(target) {
      const tooltip = this.findTooltipByTarget(target);

      if (tooltip) {
        tooltip.title = target.getAttribute('title');
      }
    },
    // eslint-disable-next-line vue/no-unused-properties -- triggerEvent is part of the component's public API for triggering tooltip events.
    triggerEvent(target, event) {
      const tooltip = this.findTooltipByTarget(target);
      const tooltipRef = this.$refs[tooltip?.id];

      if (tooltipRef) {
        tooltipRef[0][event]();
      }
    },
    tooltipExists(element) {
      return Boolean(this.findTooltipByTarget(element));
    },
    findTooltipByTarget(element) {
      return this.tooltips.find((tooltip) => tooltip.target === element);
    },
  },
  safeHtmlConfig: {
    ADD_TAGS: ['gl-emoji'],
  },
};
</script>
<template>
  <div>
    <gl-tooltip
      v-for="(tooltip, index) in tooltips"
      :id="tooltip.id"
      :ref="tooltip.id"
      :key="index"
      :target="tooltip.target"
      :triggers="tooltip.triggers"
      :placement="tooltip.placement"
      :disabled="tooltip.disabled"
      :show="tooltip.show"
      :custom-class="tooltip.customClass"
      :no-fade="tooltip.noFade"
      @hidden="$emit('hidden', tooltip)"
    >
      <span v-if="tooltip.html" v-safe-html:[$options.safeHtmlConfig]="tooltip.title"></span>
      <span v-else>{{ tooltip.title }}</span>
    </gl-tooltip>
  </div>
</template>

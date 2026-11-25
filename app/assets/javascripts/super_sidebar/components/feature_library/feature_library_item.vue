<script>
import { GlBadge, GlButton, GlIcon, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { sprintf, __, s__ } from '~/locale';
import { TIERS, ITEM_VARIANTS } from './constants';

export default {
  name: 'FeatureLibraryItem',
  components: { GlBadge, GlButton, GlIcon, GlLink },
  directives: { GlTooltip: GlTooltipDirective },
  props: {
    supportsPins: {
      type: Boolean,
      required: false,
      default: false,
    },
    item: {
      type: Object,
      required: true,
    },
    pinned: {
      type: Boolean,
      required: false,
      default: false,
    },
    // Set when the row sits on an already-tinted surface, so the hover fill
    // stays visible against it instead of matching the section behind.
    solidBackground: {
      type: Boolean,
      required: false,
      default: false,
    },
    variant: {
      type: String,
      required: false,
      default: ITEM_VARIANTS.DEFAULT,
      validator: (value) => Object.values(ITEM_VARIANTS).includes(value),
    },
  },
  emits: ['pin-toggle', 'navigate', 'learn-more'],
  data() {
    return {
      descriptionTruncated: false,
    };
  },
  computed: {
    descriptionTooltip() {
      return this.descriptionTruncated ? this.item.description : '';
    },
    isLocked() {
      return this.variant === ITEM_VARIANTS.LOCKED;
    },
    showPin() {
      return !this.isLocked && this.supportsPins;
    },
    showLearnMore() {
      return this.isLocked && Boolean(this.item.docs_url);
    },
    rowClasses() {
      // A locked row isn't a link, so it has no hover state.
      if (this.isLocked) return '';

      return this.solidBackground ? 'hover:gl-bg-default' : 'hover:gl-bg-strong';
    },
    // A locked item shows the label the catalog endpoint sends, such as "New with Premium".
    badgeLabel() {
      return this.isLocked ? this.item.label?.text || '' : this.tierLabel;
    },
    tierLabel() {
      // The server sends tierGated: false when the viewer's plan already includes the tier.
      if (this.item.tierGated === false) return '';

      switch (this.item.tier) {
        case TIERS.PREMIUM:
          return __('Premium');
        case TIERS.ULTIMATE:
          return __('Ultimate');
        case TIERS.ADD_ON:
          return __('Add-on');
        default:
          return '';
      }
    },
    learnMoreAriaLabel() {
      return sprintf(s__('FeatureLibrary|Learn more about %{title}'), { title: this.item.title });
    },
    pinAriaLabel() {
      return sprintf(s__('FeatureLibrary|Pin %{title}'), { title: this.item.title });
    },
    pinIconName() {
      return this.pinned ? 'thumbtack-solid' : 'thumbtack';
    },
    pinTooltipText() {
      return this.pinned ? s__('FeatureLibrary|Unpin') : s__('FeatureLibrary|Pin');
    },
  },
  methods: {
    // Measured on hover rather than with a ResizeObserver per row.
    checkDescriptionTruncated() {
      const el = this.$refs.description;
      this.descriptionTruncated = Boolean(el) && el.scrollWidth > el.clientWidth;
    },
    onPinClick() {
      this.$emit('pin-toggle', this.item.id, !this.pinned, this.item.title);
    },
    onNavigate() {
      this.$emit('navigate', this.item.id);
    },
    onLearnMoreClick() {
      this.$emit('learn-more', this.item.id);
    },
    // eslint-disable-next-line vue/no-unused-properties -- invoked externally via this.$refs.searchResultItems in feature_library_modal.vue
    focus() {
      this.$refs.titleLink?.$el?.focus();
    },
  },
};
</script>

<template>
  <li
    class="gl-flex gl-items-start gl-gap-3 gl-rounded-lg gl-px-3 gl-py-2"
    :class="rowClasses"
    @mouseenter="checkDescriptionTruncated"
  >
    <gl-icon :name="item.icon" class="gl-mt-2 gl-shrink-0 gl-text-subtle" />

    <!-- The title link stretches over this column only, so the pin action stays
         outside the link's click target. The tooltip sits here, not on the
         description, because the link's overlay covers the description. -->
    <div
      v-gl-tooltip.hover="descriptionTooltip"
      class="gl-relative gl-min-w-0 gl-grow"
      data-testid="feature-library-item-content"
    >
      <gl-link
        v-if="!isLocked"
        ref="titleLink"
        variant="meta"
        :href="item.link"
        class="gl-font-semibold gl-stretched-link"
        data-testid="feature-library-item-title"
        @click="onNavigate"
      >
        {{ item.title }}
      </gl-link>
      <span v-else class="gl-font-semibold gl-text-strong" data-testid="feature-library-item-title">
        {{ item.title }}
      </span>
      <p
        ref="description"
        data-testid="feature-library-item-description"
        class="gl-mb-0 gl-truncate gl-text-sm gl-text-subtle"
      >
        {{ item.description }}
      </p>
    </div>

    <gl-badge
      v-if="badgeLabel"
      variant="tier"
      class="gl-mt-2 gl-shrink-0"
      data-testid="feature-library-item-badge"
    >
      {{ badgeLabel }}
    </gl-badge>

    <gl-button
      v-if="showPin"
      v-gl-tooltip.hover="pinTooltipText"
      category="tertiary"
      size="small"
      class="gl-mt-1 gl-shrink-0"
      :icon="pinIconName"
      :aria-label="pinAriaLabel"
      :aria-pressed="String(pinned)"
      @click="onPinClick"
    />
    <gl-link
      v-else-if="showLearnMore"
      :href="item.docs_url"
      target="_blank"
      class="gl-mt-2 gl-shrink-0 gl-text-sm gl-font-semibold"
      :aria-label="learnMoreAriaLabel"
      data-testid="feature-library-item-learn-more"
      @click="onLearnMoreClick"
    >
      {{ __('Learn more') }}
    </gl-link>
  </li>
</template>

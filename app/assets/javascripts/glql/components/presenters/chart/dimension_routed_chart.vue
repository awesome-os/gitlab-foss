<script>
import { GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { PANEL_FITTED_DISPLAY_TYPES } from '~/glql/constants';
import { dimensionValueCount, dimensionsOf, metricsOf } from '../../../utils/chart_data';
import { dimensionMetricValidationError } from '../../../utils/chart_validation';
import { pageOf } from '../bar_list/fold_tail';

// Shared shell for the chart display types that plot dimensions against
// metrics (column, bar, line, area, diverging bar). Owns the wiring each of them would
// otherwise repeat: the loading skeleton, dimension/metric validation
// (emitted as `error` for the embedded-view alert), routing on dimension
// count, the `stacked` display option, and Previous and Next paging when
// given a `pageSize`. The owning presenter supplies the actual chart through
// the `one-dimension` / `two-dimensions` scoped slots.
export default {
  name: 'DimensionRoutedChart',
  components: {
    GlKeysetPagination,
    GlSkeletonLoader,
  },
  inject: {
    fitChartToPanel: { default: false },
  },
  props: {
    displayType: {
      required: true,
      type: String,
    },
    data: {
      required: false,
      type: Object,
      default: () => ({ nodes: [] }),
    },
    fields: {
      required: false,
      type: Array,
      default: () => [],
    },
    loading: {
      required: false,
      type: Boolean,
      default: false,
    },
    displayConfig: {
      required: false,
      type: Object,
      default: () => ({}),
    },
    minDimensions: {
      required: false,
      type: Number,
      default: 1,
    },
    maxDimensions: {
      required: false,
      type: Number,
      default: 2,
    },
    minMetrics: {
      required: false,
      type: Number,
      default: 1,
    },
    maxMetrics: {
      required: false,
      type: Number,
      default: Infinity,
    },
    // How many first-dimension values each page shows. Null shows them all.
    pageSize: {
      required: false,
      type: Number,
      default: null,
    },
  },
  emits: { error: null },
  data() {
    return {
      // Display-side: the rows are already fetched, so a page turn makes no request.
      page: 0,
    };
  },
  computed: {
    fitsPanel() {
      return this.fitChartToPanel && PANEL_FITTED_DISPLAY_TYPES.has(this.displayType);
    },
    dimensions() {
      return dimensionsOf(this.fields);
    },
    metrics() {
      return metricsOf(this.fields);
    },
    // A second dimension becomes the series and is always stacked, so the
    // option only reaches the one-dimension slot.
    stacked() {
      return this.displayConfig?.stacked === true;
    },
    validationError() {
      if (!this.fields.length) return null;
      return dimensionMetricValidationError({
        displayType: this.displayType,
        dimensions: this.dimensions,
        metrics: this.metrics,
        minDimensions: this.minDimensions,
        maxDimensions: this.maxDimensions,
        minMetrics: this.minMetrics,
        maxMetrics: this.maxMetrics,
      });
    },
    nodes() {
      return this.data?.nodes ?? [];
    },
    // One dimension pages by row, like `pageData`, since distinct rows can share a label (a null
    // value and a literal "Unknown", say). Two dimensions page by first-dimension value, which is
    // what the stacked charts group by.
    pageCount() {
      if (!this.pageSize || !this.dimensions.length) return 1;

      const count =
        this.dimensions.length === 1
          ? this.nodes.length
          : dimensionValueCount(this.nodes, this.dimensions[0]);

      return Math.ceil(count / this.pageSize);
    },
    // One row per value, so a single-dimension chart can take its page as plain rows. A
    // two-dimension chart gets `page` instead and builds its series from every row before it
    // slices, so series order and color hold across pages. A single-dimension chart that needs
    // every row too (diverging bar builds its labels from all of them) also gets `page`.
    pageData() {
      if (!this.pageSize) return this.data;

      return { ...this.data, nodes: pageOf(this.nodes, this.page, this.pageSize) };
    },
    showPagination() {
      return this.pageCount > 1 && !this.loading && !this.validationError;
    },
    hasPreviousPage() {
      return this.page > 0;
    },
    hasNextPage() {
      return this.page + 1 < this.pageCount;
    },
    pageCounter() {
      return sprintf(s__('Glql|Page %{current} of %{total}'), {
        current: this.page + 1,
        total: this.pageCount,
      });
    },
  },
  watch: {
    // A new result set invalidates the current page, so paging restarts.
    data() {
      this.page = 0;
    },
    pageCount(count) {
      if (this.page >= count) this.page = 0;
    },
    validationError: {
      immediate: true,
      handler(message) {
        if (message) this.$emit('error', new Error(message));
      },
    },
  },
};
</script>

<template>
  <div :class="{ 'gl-flex gl-min-h-31 gl-grow gl-flex-col': fitsPanel }">
    <gl-skeleton-loader v-if="loading" />
    <!-- With no rows ECharts can't give the chart an accessible name. Hosts should show their own empty state. -->
    <div
      v-else-if="!validationError && nodes.length"
      :class="{ 'gl-flex gl-min-h-0 gl-grow gl-flex-col': fitsPanel }"
    >
      <slot
        v-if="dimensions.length === 1"
        name="one-dimension"
        :dimension="dimensions[0]"
        :metrics="metrics"
        :stacked="stacked"
        :page-data="pageData"
        :page="page"
      ></slot>
      <slot
        v-else-if="dimensions.length === 2"
        name="two-dimensions"
        :dimensions="dimensions"
        :metric="metrics[0]"
        :page="page"
      ></slot>
    </div>
    <div v-if="showPagination" class="gl-mt-6 gl-flex gl-items-center gl-justify-between">
      <gl-keyset-pagination
        :has-previous-page="hasPreviousPage"
        :has-next-page="hasNextPage"
        @prev="page -= 1"
        @next="page += 1"
      />
      <span class="gl-text-sm gl-text-subtle" data-testid="page-counter">{{ pageCounter }}</span>
    </div>
  </div>
</template>

<script>
import { GlKeysetPagination } from '@gitlab/ui';
import { mapValues, pick } from 'lodash-es';
import { s__, sprintf } from '~/locale';
import { sha256 } from '~/lib/utils/text_utility';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import {
  AGGREGATED_AUTO_PAGE_SIZE,
  DEFAULT_PAGE_SIZE,
  DEFAULT_DISPLAY_TYPE,
  EXECUTION_QUEUE_DEFAULT,
  LIMIT_PAGED_DISPLAY_TYPES,
  MAX_AUTO_PAGINATED_ROWS,
  MODE_ANALYTICS,
  PAGINATION_AUTO,
  PAGINATION_BY_DISPLAY_TYPE,
  PAGINATION_LOAD_MORE,
  PAGINATION_PAGED,
  PANEL_FITTED_DISPLAY_TYPES,
  STANDARD_MAX_PAGE_SIZE,
} from '~/glql/constants';
import { parse } from '../../core/parser';
import { execute } from '../../core/executor';
import { transform } from '../../core/transformer';
import DataPresenter from '../presenters/data.vue';
import {
  appendPage,
  currentPage,
  emptyPageList,
  goToPage,
  hasCachedNextPage,
  hasPreviousPage,
  markCurrentPageAsLast,
  startPageList,
} from '../../utils/page_list';
import GlqlPagination from './pagination.vue';

// No display type maps to this: it is what `pagination` falls back to for a display type and
// mode with no entry, or for an auto-paginated display outside LIMIT_PAGED_DISPLAY_TYPES with
// a `limit:`.
const PAGINATION_NONE = 'none';

// A copy of the parsed variables with the given values set. Each request builds its own, so no
// request depends on what an earlier one sent. A value for a variable the query does not declare
// is dropped.
const withValues = (variables, values) =>
  variables &&
  mapValues(variables, (variable, key) =>
    Object.hasOwn(values, key) ? { ...variable, value: values[key] } : variable,
  );

export default {
  name: 'GlqlResolver',
  components: {
    DataPresenter,
    GlKeysetPagination,
    GlqlPagination,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    fitChartToPanel: { default: false },
  },
  props: {
    glqlQuery: {
      required: true,
      type: String,
    },
    trackingEventName: {
      required: false,
      type: String,
      default: '',
    },
    /**
     * Namespace to compile the query against, as `{ group }` or `{ project }`.
     * When null, the namespace is derived from the current URL.
     */
    scope: {
      required: false,
      type: Object,
      default: null,
    },
    /**
     * Comparison settings: `query` is a second query run alongside `glqlQuery`, with its
     * result exposed as `comparisonData`, and `metric` names the metric used for comparison.
     * `bindings` stands in for the main query's bindings when the comparison covers another
     * period. Presenters pair its rows one-to-one with the main rows. Unlike `breakdown`, it
     * runs eagerly as a single page, and a failure drops it. Only dashboard panels set this.
     */
    comparison: {
      required: false,
      type: Object,
      default: null,
    },
    /**
     * Breakdown settings: `query` is a second query, run on demand, with its result exposed as
     * `breakdownData`. Presenters nest its rows under the main rows. Unlike `comparison`, it
     * runs only when requested, walks every page up to the row cap, and reports a failure.
     * Only dashboard panels set this.
     */
    breakdown: {
      required: false,
      type: Object,
      default: null,
    },
    /**
     * Request queue the queries run on. Resolvers on a page that name the same queue share
     * its concurrency limit, so dashboard panels use their own to load side by side.
     */
    queue: {
      required: false,
      type: String,
      default: EXECUTION_QUEUE_DEFAULT,
    },
    /**
     * Order among requests waiting on the queue: lower runs first, equal keeps arrival order.
     * Dashboard panels pass their grid position so a view fills top to bottom.
     */
    priority: {
      required: false,
      type: Number,
      default: 0,
    },
    /**
     * Control bindings, each names a query field and the value to inject into it.
     * The compiler rewrites the query's filters from these, so the caller never templates the
     * query text. Only dashboard panels set this.
     */
    bindings: {
      required: false,
      type: Array,
      default: () => [],
    },
  },
  emits: ['change'],
  data() {
    return {
      loading: false,

      data: undefined,
      comparisonData: undefined,
      // From the moment `fetchComparison` starts until `applyComparison` applies its result, or
      // until `resetData` clears it when the main query fails.
      comparisonRunning: false,
      // The main query as `parse` returned it. Requests never change it.
      compiled: undefined,
      // Nothing to show: the query, a request or the presenter failed.
      error: undefined,
      // A Next or Load more request failed. The rows on screen are still good.
      pageError: undefined,
      resultsTruncated: false,
      breakdownData: undefined,
      breakdownLoading: false,
      breakdownError: undefined,

      // `paged` only: every page fetched so far, so Previous never refetches.
      pageList: emptyPageList(),
      pageLoading: false,
    };
  },
  computed: {
    config() {
      return this.compiled?.config;
    },
    fields() {
      return this.compiled?.fields;
    },
    mode() {
      return this.compiled?.mode;
    },
    source() {
      return this.compiled?.source;
    },
    hasDisplayType() {
      return Boolean(this.config?.display);
    },
    // The backend's cap, so each auto-paginated page is as large as it allows.
    aggregatedPageSize() {
      return gon.aggregation_max_page_size ?? AGGREGATED_AUTO_PAGE_SIZE;
    },
    /**
     * Page size for an analytics-mode display in LIMIT_PAGED_DISPLAY_TYPES with a positive whole
     * `limit:`. Every row is fetched and the presenter pages over them, so the limit never reaches
     * the server. Null otherwise, and `limit` is the fetch page size, which the server rejects if
     * invalid. Outside analytics mode nothing walks the pages, so `limit` stays a fetch size.
     */
    displayPageSize() {
      const limit = Number(this.config?.limit);

      if (this.mode !== MODE_ANALYTICS || !LIMIT_PAGED_DISPLAY_TYPES.has(this.config?.display)) {
        return null;
      }
      return Number.isInteger(limit) && limit > 0 ? limit : null;
    },
    pagination() {
      const display = this.config?.display ?? DEFAULT_DISPLAY_TYPE;
      const strategy = PAGINATION_BY_DISPLAY_TYPE[display]?.[this.mode] ?? PAGINATION_NONE;

      // An explicit `limit:` turns automatic fetching into a single page of that size, unless it
      // sizes a chart's display-side pages.
      if (strategy === PAGINATION_AUTO && this.config?.limit != null && !this.displayPageSize) {
        return PAGINATION_NONE;
      }

      return strategy;
    },
    hasNextPage() {
      if (this.isPaged) return Boolean(this.data?.pageInfo?.hasNextPage);

      return (
        this.isLoadMore && Boolean(this.data?.count && this.data.nodes?.length < this.data.count)
      );
    },
    isLoadMore() {
      return this.pagination === PAGINATION_LOAD_MORE;
    },
    // Emitted, so consumers read what the view is instead of comparing strategy names.
    isPaged() {
      return this.pagination === PAGINATION_PAGED;
    },
    // This root scrolls, so a tile shorter than the chart's minimum height scrolls here instead
    // of being clipped by the panel's overflow-hidden root.
    fitsPanel() {
      return this.fitChartToPanel && PANEL_FITTED_DISPLAY_TYPES.has(this.config?.display);
    },
    /**
     * The explicit `limit:` to send. The server silently caps `first`, at `aggregatedPageSize` in
     * analytics mode and at `STANDARD_MAX_PAGE_SIZE` otherwise, so a larger limit is lowered to the
     * cap. That way the page counter and the Load more footer count the rows the server really
     * returns. A limit that isn't a whole number is sent as is, so the server still rejects it.
     */
    requestedLimit() {
      const { limit } = this.config ?? {};
      if (!Number.isInteger(limit)) return limit;

      const cap = this.mode === MODE_ANALYTICS ? this.aggregatedPageSize : STANDARD_MAX_PAGE_SIZE;

      return Math.min(limit, cap);
    },
    /**
     * The page size every request of the main query sends. An explicit `limit:` wins, unless it
     * sizes a chart's display-side pages. Otherwise lists and tables get the default page size,
     * and aggregated displays take a full page that `autoPaginate` walks to the end of. Null when
     * the query has no `limit` variable, or nothing sets it.
     */
    pageSize() {
      if (!this.compiled?.variables?.limit) return null;

      if (this.config.limit != null && !this.displayPageSize) return this.requestedLimit;
      if (this.isLoadMore || this.isPaged) return DEFAULT_PAGE_SIZE;
      if (this.pagination === PAGINATION_AUTO) return this.aggregatedPageSize;

      return null;
    },
    hasPreviousPage() {
      return hasPreviousPage(this.pageList);
    },
    // The query returns the total row count, so the page count is known before the last page.
    pageCounter() {
      const total = Number(this.data?.count);
      if (!this.isPaged || !(total > 0) || !this.pageSize) return null;

      return sprintf(s__('Glql|Page %{current} of %{total}'), {
        current: this.pageList.index + 1,
        total: Math.ceil(total / this.pageSize),
      });
    },
    hasBreakdown() {
      return Boolean(this.breakdown?.query);
    },
    // The comparison is a single page of `aggregatedPageSize` rows, so it can only pair every row
    // of a main result that fits in one. A wider result drops it.
    fitsComparisonPage() {
      return !(this.data?.count > this.aggregatedPageSize);
    },
    // Keeps a column free for the comparison while it runs. It is released as soon as the main
    // result turns out too wide, rather than when loading clears.
    comparisonPending() {
      return this.comparisonRunning && this.fitsComparisonPage;
    },
  },
  created() {
    // Not reactive: aborting it drops this instance's requests still waiting in the queue. The
    // pagination loops are plain async functions that destroying the component does not stop, so
    // they check `discarded()` too. Parents remount this component instead of mutating its props.
    this.abortController = new AbortController();
  },
  mounted() {
    this.executeQuery();
  },
  beforeDestroy() {
    this.abortController.abort();
  },
  methods: {
    discarded() {
      return this.abortController.signal.aborted;
    },

    resetData() {
      this.data = undefined;
      this.comparisonData = undefined;
      this.comparisonRunning = false;
      this.compiled = undefined;
      this.error = undefined;
      this.pageError = undefined;
      this.resultsTruncated = false;
      this.pageList = emptyPageList();
      this.pageLoading = false;
      this.breakdownData = undefined;
      this.breakdownLoading = false;
      this.breakdownError = undefined;
    },

    emitChange() {
      this.$emit('change', {
        ...this.compiled,
        ...pick(this, [
          'data',
          'comparisonData',
          'error',
          'pageError',
          'loading',
          'isPaged',
          'resultsTruncated',
        ]),
      });
    },

    // Runs one request of a compiled query, with `values` set on a copy of its variables.
    async run({ query, variables, fields, mode, source }, values = {}) {
      const executionResult = await execute(query, withValues(variables, values), {
        queue: this.queue,
        priority: this.priority,
        signal: this.abortController.signal,
        tag: this.glqlQuery,
      });

      return transform(executionResult, { fields, mode, source });
    },

    // The values every request of the main query sends. Page turns add the cursor to these.
    mainQueryValues() {
      return this.pageSize == null ? {} : { limit: this.pageSize };
    },

    async executeQuery() {
      if (!this.glqlQuery.trim()) return;

      this.resetData();

      this.loading = true;
      this.emitChange();

      try {
        this.compiled = await parse(this.glqlQuery, this.scope, { bindings: this.bindings });

        // Started before the comparison, so the main query is queued first, and awaited only once
        // the comparison is underway, so both run at once. Every request carries the source as
        // its tag, so a panel reload can drop all of them from the dashboard result cache.
        const mainRequest = this.run(this.compiled, this.mainQueryValues());
        const comparisonRequest = this.fetchComparison();

        this.data = await mainRequest;

        if (this.pagination === PAGINATION_PAGED) {
          this.pageList = startPageList({ nodes: this.data.nodes, pageInfo: this.data.pageInfo });
        }
        if (this.pagination === PAGINATION_AUTO) await this.autoPaginate();

        this.applyComparison(await comparisonRequest);

        this.trackRender();
      } catch (error) {
        // Keep the parsed config through the failure: consumers size their error
        // states by the display type, which the query still declares.
        const { config } = this;

        this.resetData();
        this.compiled = { config };
        this.error = error;
      } finally {
        this.loading = false;
        this.emitChange();
      }
    },

    // Its `limit` variable stays null on purpose: the compiler never fills it and only the main
    // query gets the `limit:` config, so the backend serves its default page of `aggregatedPageSize`
    // rows and a `limit: 5` table still pairs rows on its later pages. `applyComparison` drops the
    // comparison past that size, since one page then cannot pair every row. Never rejects.
    async fetchComparison() {
      if (!this.comparison?.query) return undefined;

      this.comparisonRunning = true;

      try {
        const compiled = await parse(this.comparison.query, this.scope, {
          bindings: this.comparison.bindings ?? this.bindings,
        });
        const result = await this.run(compiled);

        return { ...result, metric: this.comparison.metric };
      } catch (error) {
        // Skip only the queue's own abort rejection, so real failures after teardown still report.
        if (error === this.abortController.signal.reason) return undefined;

        Sentry.captureException(error);
        return undefined;
      }
    },

    // Applies the comparison once the main result is in, so both render in the same change.
    applyComparison(comparisonData) {
      this.comparisonData = this.fitsComparisonPage ? comparisonData : undefined;
      this.comparisonRunning = false;
    },

    // Runs once a presenter asks for it, for the whole result at once: its rows don't follow the
    // main query's pages, so it is walked to the row cap on its own. A failed first page is
    // reported, and the next request tries again. A query that fails to compile fails the panel
    // with the compiler's message instead, since retrying it can never work.
    async fetchBreakdown() {
      if (!this.breakdown?.query || this.breakdownData || this.breakdownLoading) return;

      this.breakdownLoading = true;
      this.breakdownError = undefined;

      let compiled;
      try {
        compiled = await parse(this.breakdown.query, this.scope, { bindings: this.bindings });
      } catch (error) {
        this.breakdownLoading = false;
        this.handlePresenterError(error);
        return;
      }

      try {
        const values = { limit: this.aggregatedPageSize };
        const data = await this.paginate(await this.run(compiled, values), compiled, values);
        if (this.discarded()) return;

        // With the fields it compiled to, so presenters can tell its dimensions apart.
        this.breakdownData = { ...data, fields: compiled.fields };
      } catch (error) {
        // Skip only the queue's own abort rejection, so real failures after teardown still report.
        if (error === this.abortController.signal.reason) return;

        Sentry.captureException(error);
        this.breakdownError = error;
      } finally {
        this.breakdownLoading = false;
      }
    },

    // Fetches the page after `data` and appends its rows.
    async fetchNextPage(data, compiled, values) {
      const nextPage = await this.run(compiled, { ...values, after: data.pageInfo?.endCursor });

      return { ...data, pageInfo: nextPage.pageInfo, nodes: [...data.nodes, ...nextPage.nodes] };
    },

    showPage(pageList) {
      const { nodes, pageInfo } = currentPage(pageList);
      this.pageList = pageList;
      this.data = { ...this.data, nodes, pageInfo };
      this.emitChange();
    },

    previousPage() {
      if (this.pageLoading) return;
      this.pageError = undefined;

      if (this.hasPreviousPage) this.showPage(goToPage(this.pageList, this.pageList.index - 1));
    },

    async nextPage() {
      if (this.pageLoading) return;
      // A failed turn is over once the user turns again, so it is not reported on later changes.
      this.pageError = undefined;

      if (hasCachedNextPage(this.pageList)) {
        this.showPage(goToPage(this.pageList, this.pageList.index + 1));
        return;
      }

      const after = this.data?.pageInfo?.endCursor;
      if (!after) {
        this.emitChange();
        return;
      }

      try {
        this.pageLoading = true;

        const { nodes, pageInfo } = await this.run(this.compiled, {
          ...this.mainQueryValues(),
          after,
        });

        if (!nodes?.length) {
          this.endOnCurrentPage();
          return;
        }

        this.showPage(appendPage(this.pageList, { nodes, pageInfo }));
      } catch (error) {
        this.pageError = error;
        this.emitChange();
      } finally {
        this.pageLoading = false;
      }
    },

    // The data shrank between requests, so the page on screen is the last one now. Showing the
    // empty page would hand the dashboard an empty result and replace the table with its empty
    // state, which has no way back.
    endOnCurrentPage() {
      this.showPage(markCurrentPageAsLast(this.pageList));
    },

    // Walks the pages after `data` up to the row cap, and returns every row it gathered. Each
    // request sends `values` and the previous page's cursor.
    async paginate(data, compiled, values) {
      let result = data;

      // Bounds requests as well as rows, so a backend that keeps claiming another page can't spin.
      const maxPages = Math.ceil(MAX_AUTO_PAGINATED_ROWS / this.aggregatedPageSize);

      for (let page = 0; page < maxPages; page += 1) {
        if (this.discarded()) break;

        if (!result.pageInfo?.endCursor || !result.pageInfo.hasNextPage) break;
        if (result.nodes.length >= MAX_AUTO_PAGINATED_ROWS) break;

        try {
          // Sequential by nature: each request needs the previous page's cursor.
          // eslint-disable-next-line no-await-in-loop
          result = await this.fetchNextPage(result, compiled, values);
        } catch (error) {
          if (this.discarded()) break;

          // Rate limiting is keyed by query SHA, so once a page fails the next is rejected too.
          // Keep the pages already loaded rather than losing the rows. TODO: warn that the view
          // is incomplete — https://gitlab.com/gitlab-org/glql/-/work_items/216
          Sentry.captureException(error);
          break;
        }
      }

      return result;
    },

    // Emits nothing: the caller emits once, so the chart never draws a partial aggregate.
    async autoPaginate() {
      if (!this.data?.nodes) return;

      const data = await this.paginate(this.data, this.compiled, this.mainQueryValues());
      // A presenter that failed on the first page has cleared the rows, so they stay cleared.
      if (this.discarded() || !this.data) return;

      this.data = data;
      // Every exit from `paginate` can leave rows behind, not just the row cap: a short page, a
      // missing cursor, or a failed continuation. Compare against the total rather than track
      // each one.
      this.resultsTruncated = Boolean(this.data?.count && this.data.nodes.length < this.data.count);
    },

    async loadMore() {
      try {
        this.loading = true;
        this.pageError = undefined;
        this.emitChange();

        this.data = await this.fetchNextPage(this.data, this.compiled, this.mainQueryValues());
      } catch (error) {
        this.pageError = error;
      } finally {
        this.loading = false;
        this.emitChange();
      }
    },

    async trackRender() {
      if (!this.trackingEventName) return;

      try {
        this.trackEvent(this.trackingEventName, { label: await sha256(this.glqlQuery) });
      } catch (e) {
        // ignore any tracking errors
      }
    },

    handlePresenterError(error) {
      // The presenter cannot render these rows, so there is nothing worth keeping on screen.
      this.data = undefined;
      this.error = error;
      this.pageError = undefined;
      this.emitChange();
    },
  },
};
</script>
<template>
  <!-- A paged table fills its panel and keeps the controls at the bottom, so turning to a
       shorter page does not move them. -->
  <div
    :class="{
      'gl-flex gl-h-full gl-flex-col': isPaged,
      'gl-flex gl-h-full gl-min-h-0 gl-flex-col gl-overflow-y-auto gl-overflow-x-hidden': fitsPanel,
    }"
  >
    <data-presenter
      v-if="hasDisplayType && !error"
      :data="data"
      :comparison-data="comparisonData"
      :comparison-pending="comparisonPending"
      :comparison-metric="comparison?.metric ?? null"
      :has-breakdown="hasBreakdown"
      :breakdown-data="breakdownData"
      :breakdown-loading="breakdownLoading"
      :breakdown-error="breakdownError"
      :fields="fields"
      :display-type="config.display"
      :display-config="config.displayConfig"
      :source="source"
      :loading="loading"
      :display-page-size="displayPageSize"
      @error="handlePresenterError"
      @load-breakdown="fetchBreakdown"
    />
    <div v-if="isLoadMore && hasNextPage" class="glql-load-more gl-border-t gl-p-3">
      <glql-pagination
        :count="data.nodes.length"
        :total-count="data.count"
        :page-size="pageSize"
        :loading="loading"
        @load-more="loadMore"
      />
    </div>
    <div
      v-else-if="isPaged && (hasPreviousPage || hasNextPage)"
      class="glql-load-more gl-border-t gl-mt-auto gl-flex gl-items-center gl-justify-between gl-p-3"
    >
      <gl-keyset-pagination
        :has-previous-page="hasPreviousPage"
        :has-next-page="hasNextPage"
        :disabled="pageLoading"
        @prev="previousPage"
        @next="nextPage"
      />
      <span v-if="pageCounter" class="gl-text-sm gl-text-subtle" data-testid="page-counter">{{
        pageCounter
      }}</span>
    </div>
  </div>
</template>

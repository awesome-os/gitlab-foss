<script>
import { GlEmptyState, GlLoadingIcon, GlTableLite } from '@gitlab/ui';
import EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/status/status-nothing-md.svg';
import { normalizeHeaders } from '@gitlab/frontend-utils';
import { createAlert } from '~/alert';
import { parseErrorMessage } from '~/lib/utils/error_message';
import { parseIntPagination } from '~/lib/utils/common_utils';
import { s__, __ } from '~/locale';
import { getOfflineExports } from '~/rest_api';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import PaginationBar from '~/vue_shared/components/pagination_bar/pagination_bar.vue';
import ExportStatusBadge from './components/export_status_badge.vue';

const DEFAULT_PER_PAGE = 20;

export default {
  name: 'OfflineTransferExportHistoryApp',
  components: {
    ExportStatusBadge,
    GlEmptyState,
    GlLoadingIcon,
    GlTableLite,
    PaginationBar,
    TimeAgo,
  },
  data() {
    return {
      loading: true,
      offlineExports: [],
      perPage: DEFAULT_PER_PAGE,
      pageInfo: {},
    };
  },
  computed: {
    hasExports() {
      return this.offlineExports.length > 0;
    },
  },
  mounted() {
    this.loadExportHistory();
  },
  methods: {
    async loadExportHistory(page = 1) {
      this.loading = true;

      try {
        const { data, headers } = await getOfflineExports({ page, per_page: this.perPage });
        this.offlineExports = data;
        this.pageInfo = parseIntPagination(normalizeHeaders(headers));
      } catch (error) {
        createAlert({
          message: parseErrorMessage(
            error,
            s__(
              'OfflineTransferExport|Something went wrong while fetching offline export history.',
            ),
          ),
          captureError: true,
          error,
        });
      } finally {
        this.loading = false;
      }
    },
    setPageSize(perPage) {
      this.perPage = perPage;
      this.loadExportHistory();
    },
  },
  fields: [
    {
      key: 'bucket',
      label: s__('OfflineTransferExport|Destination bucket'),
      thClass: '@md/panel:gl-w-3/10',
      tdClass: 'gl-wrap-anywhere',
    },
    {
      key: 'export_prefix',
      label: s__('OfflineTransferExport|Export prefix'),
      thClass: '@md/panel:gl-w-3/10',
      tdClass: 'gl-wrap-anywhere',
    },
    {
      key: 'created_at',
      label: __('Start date'),
      thClass: '@md/panel:gl-w-1/5',
    },
    {
      key: 'status',
      label: __('Status'),
      thClass: '@md/panel:gl-w-1/5',
    },
  ],
  EMPTY_STATE_SVG_URL,
};
</script>

<template>
  <div>
    <header class="gl-my-5">
      <h1 class="gl-heading-display">
        {{ s__('OfflineTransferExport|Offline export history') }}
      </h1>
    </header>

    <gl-loading-icon v-if="loading" size="lg" class="gl-mt-5" />

    <gl-empty-state
      v-else-if="!hasExports"
      :svg-path="$options.EMPTY_STATE_SVG_URL"
      :title="s__('OfflineTransferExport|No history is available yet')"
      :description="
        s__('OfflineTransferExport|Groups exported through offline transfer appear here.')
      "
    />

    <gl-table-lite
      v-else
      :fields="$options.fields"
      :items="offlineExports"
      stacked="md"
      data-testid="export-history-table"
      class="gl-w-full"
    >
      <template #cell(created_at)="{ value }">
        <time-ago :time="value" />
      </template>

      <template #cell(status)="{ value, item }">
        <export-status-badge :status="value" :has-failures="item.has_failures" />
      </template>
    </gl-table-lite>

    <pagination-bar
      v-if="!loading && hasExports"
      :page-info="pageInfo"
      class="gl-m-0 gl-mt-3"
      @set-page="loadExportHistory"
      @set-page-size="setPageSize"
    />
  </div>
</template>

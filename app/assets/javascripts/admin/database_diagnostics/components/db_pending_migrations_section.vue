<script>
import { GlBadge, GlLink, GlTableLite } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { severityVariant } from '../utils';
import DiagnosticsSection from './diagnostics_section.vue';

// Gitlab::Database::Diagnostics::Checks::PendingMigrations types.
const TYPE_REGULAR = 'regular';
const TYPE_POST_DEPLOYMENT = 'post_deployment';

const TYPE_SEVERITIES = { [TYPE_REGULAR]: 'error', [TYPE_POST_DEPLOYMENT]: 'warning' };

const PENDING_MIGRATIONS_DOCS_URL = helpPagePath('administration/admin_area', {
  anchor: 'pending-migrations-check',
});

export default {
  name: 'DbPendingMigrationsSection',
  components: { GlBadge, GlLink, GlTableLite, DiagnosticsSection },
  props: {
    pendingMigrations: {
      type: Object,
      required: true,
    },
  },
  computed: {
    findings() {
      return this.pendingMigrations.findings || [];
    },
    // Migrations arrive with regular ones first, then by version, so no ordering is applied here.
    migrations() {
      return this.pendingMigrations.migrations || [];
    },
    hasMigrations() {
      return this.migrations.length > 0;
    },
    cappedNote() {
      return sprintf(
        s__(
          'DatabaseDiagnostics|Only the first %{count} migrations are listed. The findings above count every migration.',
        ),
        { count: this.migrations.length },
      );
    },
  },
  methods: {
    typeVariant(type) {
      return severityVariant(TYPE_SEVERITIES[type]);
    },
    typeLabel(type) {
      return type === TYPE_POST_DEPLOYMENT
        ? s__('DatabaseDiagnostics|Post-deployment')
        : s__('DatabaseDiagnostics|Regular');
    },
  },
  fields: [
    { key: 'version', label: s__('DatabaseDiagnostics|Version') },
    { key: 'name', label: s__('DatabaseDiagnostics|Name') },
    { key: 'type', label: s__('DatabaseDiagnostics|Type') },
  ],
  pendingMigrationsDocsUrl: PENDING_MIGRATIONS_DOCS_URL,
};
</script>

<template>
  <section>
    <diagnostics-section
      :title="s__('DatabaseDiagnostics|Pending migrations')"
      :severity="pendingMigrations.severity"
      :findings="findings"
      testid-prefix="pending-migrations"
    >
      <template v-if="hasMigrations">
        <p class="gl-text-sm gl-text-subtle">
          {{
            s__(
              'DatabaseDiagnostics|Regular and post-deployment migrations that have not run on this database. Regular migrations are listed first.',
            )
          }}
        </p>

        <gl-table-lite
          :items="migrations"
          :fields="$options.fields"
          stacked="md"
          data-testid="pending-migrations-table"
        >
          <template #cell(version)="{ item }">
            <code>{{ item.version }}</code>
          </template>

          <template #cell(type)="{ item }">
            <gl-badge
              :variant="typeVariant(item.type)"
              :data-testid="`pending-migrations-type-${item.type}`"
            >
              {{ typeLabel(item.type) }}
            </gl-badge>
          </template>
        </gl-table-lite>

        <p
          v-if="pendingMigrations.migrations_capped"
          class="gl-mt-3 gl-text-sm gl-text-subtle"
          data-testid="pending-migrations-capped"
        >
          {{ cappedNote }}
        </p>
      </template>

      <p
        v-else-if="!findings.length"
        class="gl-text-sm gl-text-subtle"
        data-testid="pending-migrations-empty"
      >
        {{ s__('DatabaseDiagnostics|All regular and post-deployment migrations have run.') }}
      </p>

      <p class="gl-mt-3 gl-text-sm">
        <gl-link :href="$options.pendingMigrationsDocsUrl" target="_blank">{{
          s__('DatabaseDiagnostics|Learn more about pending migrations.')
        }}</gl-link>
      </p>
    </diagnostics-section>
  </section>
</template>

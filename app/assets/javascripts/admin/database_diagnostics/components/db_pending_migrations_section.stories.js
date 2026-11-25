import {
  pendingMigrations,
  pendingMigrationsEmpty,
  pendingMigrationsNotChecked,
} from 'jest/admin/database_diagnostics/mock_data';
import DbPendingMigrationsSection from './db_pending_migrations_section.vue';

export default {
  title: 'admin/database_diagnostics/components/db_pending_migrations_section',
  component: DbPendingMigrationsSection,
  parameters: {
    docs: {
      description: {
        component:
          'Lists the regular and post-deployment migrations that have not run on a database. Details start collapsed, so use the Details toggle to reveal the table.',
      },
    },
  },
  argTypes: {
    pendingMigrations: { control: false },
  },
};

const Template = (args, { argTypes }) => ({
  props: Object.keys(argTypes),
  components: { DbPendingMigrationsSection },
  template: '<db-pending-migrations-section v-bind="$props" />',
});

// A pending regular migration (error) and a pending post-deployment migration (warning).
export const Default = Template.bind({});
Default.args = { pendingMigrations };

export const Empty = Template.bind({});
Empty.args = { pendingMigrations: pendingMigrationsEmpty };

// The check could not read the post-deployment migrations, so it does not report a clean result.
export const NotChecked = Template.bind({});
NotChecked.args = { pendingMigrations: pendingMigrationsNotChecked };

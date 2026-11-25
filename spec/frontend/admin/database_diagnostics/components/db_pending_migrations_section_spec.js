import { nextTick } from 'vue';
import { GlAlert, GlLink, GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DbPendingMigrationsSection from '~/admin/database_diagnostics/components/db_pending_migrations_section.vue';
import {
  pendingMigrations,
  pendingMigrationsEmpty,
  pendingMigrationsNotChecked,
} from '../mock_data';

describe('DbPendingMigrationsSection component', () => {
  let wrapper;

  const findStatusIcon = () => wrapper.findComponentByTestId('pending-migrations-status-icon');
  const findCountBadge = () => wrapper.findByTestId('pending-migrations-count');
  const findToggle = () => wrapper.findComponentByTestId('pending-migrations-toggle');
  const findCollapse = () => wrapper.findComponentByTestId('pending-migrations-details');
  const findEmpty = () => wrapper.findByTestId('pending-migrations-empty');
  const findTable = () => wrapper.findComponentByTestId('pending-migrations-table');
  const findCapped = () => wrapper.findByTestId('pending-migrations-capped');
  const findRegularBadge = () => wrapper.findComponentByTestId('pending-migrations-type-regular');
  const findPostDeploymentBadge = () =>
    wrapper.findComponentByTestId('pending-migrations-type-post_deployment');
  const findAllAlerts = () => wrapper.findAllComponents(GlAlert);
  const findDocsLink = () => wrapper.findComponent(GlLink);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mountExtended(DbPendingMigrationsSection, {
      propsData: {
        pendingMigrations: pendingMigrationsEmpty,
        ...props,
      },
    });
  };

  describe('when every migration has run', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a green status icon and no count badge', () => {
      expect(findStatusIcon().props('variant')).toBe('success');
      expect(findStatusIcon().props('name')).toBe('check-circle-filled');
      expect(findCountBadge().exists()).toBe(false);
    });

    it('keeps the details collapsed until toggled', async () => {
      expect(findCollapse().props('visible')).toBe(false);

      findToggle().vm.$emit('click');
      await nextTick();

      expect(findCollapse().props('visible')).toBe(true);
    });

    it('says so instead of rendering the table', () => {
      expect(findEmpty().text()).toBe('All regular and post-deployment migrations have run.');
      expect(wrapper.findComponent(GlTableLite).exists()).toBe(false);
      expect(findAllAlerts()).toHaveLength(0);
    });

    it('links to the documentation', () => {
      expect(findDocsLink().attributes('href')).toBe(
        '/help/administration/admin_area#pending-migrations-check',
      );
    });
  });

  describe('when migrations are pending', () => {
    beforeEach(() => {
      createComponent({ props: { pendingMigrations } });
    });

    it('renders the worst severity as the status icon and counts the findings', () => {
      expect(findStatusIcon().props('variant')).toBe('danger');
      expect(findStatusIcon().props('name')).toBe('error');
      expect(findCountBadge().text()).toBe('2');
    });

    it('renders an alert for each finding', () => {
      expect(findAllAlerts().wrappers.map((alert) => alert.props('variant'))).toEqual([
        'danger',
        'warning',
      ]);
      expect(findAllAlerts().at(0).text()).toBe(pendingMigrations.findings[0].message);
    });

    it('renders the migrations in the order the check supplied', () => {
      expect(findTable().props('items')).toEqual(pendingMigrations.migrations);
      expect(findEmpty().exists()).toBe(false);
    });

    it('marks a regular migration as an error and a post-deployment one as a warning', () => {
      expect(findRegularBadge().props('variant')).toBe('danger');
      expect(findRegularBadge().text()).toBe('Regular');
      expect(findPostDeploymentBadge().props('variant')).toBe('warning');
      expect(findPostDeploymentBadge().text()).toBe('Post-deployment');
    });

    it('does not say the list was cut', () => {
      expect(findCapped().exists()).toBe(false);
    });
  });

  describe('when a finding has no migration to list', () => {
    beforeEach(() => {
      createComponent({ props: { pendingMigrations: pendingMigrationsNotChecked } });
    });

    it('renders the finding without saying that all migrations have run', () => {
      expect(findStatusIcon().props('variant')).toBe('warning');
      expect(findAllAlerts().at(0).text()).toBe(pendingMigrationsNotChecked.findings[0].message);
      expect(findEmpty().exists()).toBe(false);
      expect(wrapper.findComponent(GlTableLite).exists()).toBe(false);
    });
  });

  describe('when the check cut the list', () => {
    beforeEach(() => {
      createComponent({
        props: { pendingMigrations: { ...pendingMigrations, migrations_capped: true } },
      });
    });

    it('says so under the table with the number of rows shown', () => {
      expect(findCapped().text()).toBe(
        'Only the first 2 migrations are listed. The findings above count every migration.',
      );
    });
  });
});

import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import ImportStats from '~/import_entities/components/import_stats.vue';
import { STATUSES } from '~/import_entities/constants';

describe('Import entities stats component', () => {
  let wrapper;

  const mockStats = {
    labels: {
      fetched: 10,
      imported: 9,
    },
    self: {
      fetched: 1,
      imported: 1,
    },
    milestones: {
      fetched: 1000,
      imported: 999,
    },
    issues: {
      fetched: 1,
      imported: 0,
    },
    namespace_settings: {
      fetched: 0,
      imported: 0,
    },
  };

  const defaultProps = {
    stats: mockStats,
    status: STATUSES.CREATED,
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(ImportStats, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findAllStatItems = () => wrapper.findAllByTestId('import-stat-item');
  const findGlIcon = (item) => item.findComponent(GlIcon);

  describe('template', () => {
    it('renders collection and entity labels and hides stats with 0/0', () => {
      const expectedText = [
        {
          item: 'Labels',
          stat: '9/10',
        },
        {
          item: 'Group',
          stat: '1/1',
        },
        {
          item: 'Milestones',
          stat: '999/1000',
        },
        {
          item: 'Issues',
          stat: '0/1',
        },
        {
          item: 'CI Pipelines',
          stat: '2/2',
        },
      ];

      createComponent({
        props: {
          stats: {
            ...mockStats,
            ci_pipelines: { fetched: 2, imported: 2 },
          },
        },
      });

      const items = findAllStatItems();
      expect(items).toHaveLength(5);

      items.wrappers.forEach((item, index) => {
        expect(item.find('span').text()).toBe(expectedText[index].item);
        expect(item.text()).toContain(expectedText[index].stat);
      });
    });

    describe.each`
      status               | expectedIcons
      ${STATUSES.CREATED}  | ${['running', 'success', 'running', 'running']}
      ${STATUSES.FINISHED} | ${['alert', 'success', 'alert', 'alert']}
    `('when status is $status', ({ status, expectedIcons }) => {
      it('renders correct item icons', () => {
        createComponent({
          props: {
            status,
          },
        });

        const items = findAllStatItems();
        expect(items).toHaveLength(4);

        items.wrappers.forEach((item, index) => {
          expect(findGlIcon(item).props().name).toBe(`status-${expectedIcons[index]}`);
        });
      });
    });
  });
});

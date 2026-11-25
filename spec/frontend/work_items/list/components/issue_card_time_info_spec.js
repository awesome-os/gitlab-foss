import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { STATUS_CLOSED } from '~/issues/constants';
import IssueCardTimeInfo from '~/work_items/list/components/issue_card_time_info.vue';
import IssuableMilestone from '~/vue_shared/issuable/list/components/issuable_milestone.vue';
import WorkItemParentMetadata from '~/work_items/components/shared/work_item_parent_metadata.vue';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';
import WorkItemDatesAttribute from '~/work_items/components/shared/work_item_dates_attribute.vue';
import { mockParentWorkItem } from 'ee_else_ce_jest/work_items/mock_data';

describe('CE IssueCardTimeInfo component', () => {
  let wrapper;

  const issueObject = ({
    milestoneStartDate,
    milestoneDueDate,
    startDate,
    dueDate,
    state,
    timeEstimate,
  } = {}) => ({
    milestone: {
      dueDate: milestoneDueDate,
      startDate: milestoneStartDate,
      title: 'My milestone',
      webPath: '/milestone/webPath',
    },
    startDate,
    dueDate,
    humanTimeEstimate: timeEstimate,
    state,
  });

  const workItemObject = ({
    milestoneStartDate,
    milestoneDueDate,
    startDate,
    dueDate,
    state,
    timeEstimate,
  } = {}) => ({
    state,
    features: {
      startAndDueDate: {
        startDate,
        dueDate,
      },
      milestone: {
        milestone: {
          dueDate: milestoneDueDate,
          startDate: milestoneStartDate,
          title: 'My milestone',
          webPath: '/milestone/webPath',
        },
      },
      timeTracking: {
        humanReadableAttributes: {
          timeEstimate,
        },
      },
    },
  });

  const findMilestone = () => wrapper.findComponent(IssuableMilestone);
  const findWorkItemAttribute = () => wrapper.findComponent(WorkItemAttribute);
  const findDueDateIcon = () => wrapper.findByTestId('issuable-due-date').findComponent(GlIcon);
  const findParentMetadata = () => wrapper.findComponent(WorkItemParentMetadata);

  const mountComponent = ({ issue = issueObject(), hiddenMetadataKeys = [] } = {}) =>
    shallowMountExtended(IssueCardTimeInfo, {
      propsData: { issue, hiddenMetadataKeys },
      stubs: {
        WorkItemAttribute,
        WorkItemDatesAttribute,
      },
    });

  describe.each`
    type           | object
    ${'issue'}     | ${issueObject}
    ${'work item'} | ${workItemObject}
  `('with $type object', ({ object }) => {
    describe('milestone', () => {
      it('renders', () => {
        wrapper = mountComponent({ issue: object() });

        const milestone = findMilestone();

        expect(milestone.exists()).toBe(true);
      });

      it('hides milestone when included in hiddenMetadataKeys', () => {
        wrapper = mountComponent({
          issue: object(),
          hiddenMetadataKeys: ['milestone'],
        });

        expect(findMilestone().exists()).toBe(false);
      });
    });

    describe('due date', () => {
      describe('when upcoming', () => {
        it('renders with "No start date" prefix when no start date is present', () => {
          wrapper = mountComponent({ issue: object({ dueDate: '2020-12-12' }) });
          expect(findWorkItemAttribute().props('title')).toBe('No start date – Dec 12, 2020');
          expect(findWorkItemAttribute().props('tooltipText')).toBe('Due date');
          expect(findDueDateIcon().props()).toMatchObject({
            variant: 'current',
            name: 'calendar',
          });
        });

        it('hides dates when included in hiddenMetadataKeys', () => {
          wrapper = mountComponent({
            issue: object({ dueDate: '2020-12-12' }),
            hiddenMetadataKeys: ['dates'],
          });

          expect(findWorkItemAttribute().exists()).toBe(false);
        });
      });

      describe('when in the past', () => {
        describe('when issue is open', () => {
          it('renders in red with overdue icon and "No start date" prefix', () => {
            wrapper = mountComponent({ issue: object({ dueDate: '2020-01-01' }) });
            expect(findWorkItemAttribute().props('title')).toBe('No start date – Jan 1, 2020');
            expect(findDueDateIcon().props()).toMatchObject({
              variant: 'danger',
              name: 'calendar-overdue',
            });
          });
        });

        describe('when issue is closed', () => {
          it('does not render in red with overdue icon but shows "No start date" prefix', () => {
            wrapper = mountComponent({
              issue: object({ dueDate: '2020-01-01', state: STATUS_CLOSED }),
            });

            expect(findWorkItemAttribute().props('title')).toBe('No start date – Jan 1, 2020');
            expect(findDueDateIcon().props()).toMatchObject({
              variant: 'current',
              name: 'calendar',
            });
          });
        });
      });

      describe('when approaching', () => {
        it('classifies today as approaching, not overdue', () => {
          wrapper = mountComponent({ issue: object({ dueDate: '2020-07-06' }) });

          expect(findDueDateIcon().props()).toMatchObject({
            variant: 'warning',
            name: 'calendar-due',
          });
          expect(findWorkItemAttribute().props('tooltipText')).toBe('Due date (due soon)');
        });

        it('renders with warning variant and calendar-due icon when due within 6 days', () => {
          wrapper = mountComponent({ issue: object({ dueDate: '2020-07-12' }) });

          expect(findDueDateIcon().props()).toMatchObject({
            variant: 'warning',
            name: 'calendar-due',
          });
        });

        it('renders with normal variant when due exactly 7 days away', () => {
          wrapper = mountComponent({ issue: object({ dueDate: '2020-07-13' }) });

          expect(findDueDateIcon().props()).toMatchObject({
            variant: 'current',
            name: 'calendar',
          });
          expect(findWorkItemAttribute().props('tooltipText')).toBe('Due date');
        });

        it('does not apply approaching state when issue is closed', () => {
          wrapper = mountComponent({
            issue: object({ dueDate: '2020-07-09', state: STATUS_CLOSED }),
          });

          expect(findDueDateIcon().props()).toMatchObject({
            variant: 'current',
            name: 'calendar',
          });
        });
      });
    });

    describe('start date', () => {
      describe('when dates are excluded from metadata', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            issue: object({ startDate: '2020-11-30' }),
            hiddenMetadataKeys: ['dates'],
          });
        });

        it('hides the start date', () => {
          expect(wrapper.findComponent(WorkItemDatesAttribute).exists()).toBe(false);
        });
      });

      describe('with start date and due date', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            issue: object({ startDate: '2020-11-30', dueDate: '2020-12-12' }),
          });
        });

        it('renders date range', () => {
          expect(findWorkItemAttribute().props('title')).toBe('Nov 30 – Dec 12, 2020');
        });
      });

      describe('with start date and no due date', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            issue: object({ startDate: '2020-11-30', dueDate: null }),
          });
        });

        it('renders date range', () => {
          expect(findWorkItemAttribute().exists()).toBe(true);
          expect(findWorkItemAttribute().props('title')).toBe('Nov 30, 2020 – No due date');
        });
      });
    });

    describe('time estimate', () => {
      it('renders time estimate', () => {
        wrapper = mountComponent({ issue: object({ timeEstimate: '1w' }) });
        const timeEstimate = wrapper.findByTestId('time-estimate');

        expect(findWorkItemAttribute().props('title')).toBe('1w');
        expect(findWorkItemAttribute().props('tooltipText')).toBe('Estimate');
        expect(timeEstimate.findComponent(GlIcon).props('name')).toBe('timer');
      });

      describe('when the language is not English', () => {
        beforeEach(() => {
          document.querySelector('html').setAttribute('lang', 'de');
        });

        afterEach(() => {
          document.querySelector('html').removeAttribute('lang');
        });

        it('renders time estimate with localized units', () => {
          wrapper = mountComponent({ issue: object({ timeEstimate: '1w' }) });

          expect(findWorkItemAttribute().props('title')).toBe(
            new Intl.NumberFormat('de', {
              style: 'unit',
              unit: 'week',
              unitDisplay: 'short',
            }).format(1),
          );
        });
      });
    });
  });

  describe('start date data compatibility', () => {
    describe.each([undefined, null])('when both dates are %s', (date) => {
      beforeEach(() => {
        wrapper = mountComponent({ issue: issueObject({ startDate: date, dueDate: date }) });
      });

      it('hides dates', () => {
        expect(wrapper.findComponent(WorkItemDatesAttribute).exists()).toBe(false);
      });
    });

    describe('with a milestone start date and no issue start date', () => {
      beforeEach(() => {
        wrapper = mountComponent({
          issue: issueObject({ milestoneStartDate: '2020-11-30', dueDate: '2020-12-12' }),
        });
      });

      it('does not use the milestone start date as the issue start date', () => {
        expect(findWorkItemAttribute().props('title')).toBe('No start date – Dec 12, 2020');
      });
    });

    describe('with work item dates', () => {
      const object = workItemObject;

      describe.each([undefined, null])('when the root start date is %s', (date) => {
        beforeEach(() => {
          wrapper = mountComponent({
            issue: {
              ...object({ startDate: '2020-11-30', dueDate: '2020-12-12' }),
              startDate: date,
            },
          });
        });

        it('preserves the fallback', () => {
          expect(findWorkItemAttribute().props('title')).toBe('Nov 30 – Dec 12, 2020');
        });
      });

      describe('with an explicitly returned root date', () => {
        beforeEach(() => {
          wrapper = mountComponent({
            issue: {
              ...object({ startDate: '2020-11-30', dueDate: '2020-12-12' }),
              startDate: '2020-12-01',
            },
          });
        });

        it('uses the root date before the fallback', () => {
          expect(findWorkItemAttribute().props('title')).toBe('Dec 1 – 12, 2020');
        });
      });
    });
  });

  describe('hiddenMetadataKeys', () => {
    it('hides multiple metadata fields', () => {
      wrapper = mountComponent({
        issue: issueObject({ dueDate: '2020-12-12' }),
        hiddenMetadataKeys: ['milestone', 'dates'],
      });

      expect(findMilestone().exists()).toBe(false);
      expect(findWorkItemAttribute().exists()).toBe(false);
    });

    it('handles undefined hiddenMetadataKeys', () => {
      wrapper = mountComponent({
        issue: issueObject({ dueDate: '2020-12-12' }),
        hiddenMetadataKeys: undefined,
      });

      expect(findMilestone().exists()).toBe(true);
      expect(findWorkItemAttribute().exists()).toBe(true);
    });
  });

  describe('parent metadata', () => {
    it('does not render parent metadata when parent is not present', () => {
      wrapper = mountComponent({ issue: issueObject() });

      expect(findParentMetadata().exists()).toBe(false);
    });

    it('renders parent metadata when parent is present', () => {
      wrapper = mountComponent({
        issue: {
          ...workItemObject(),
          features: {
            ...workItemObject().features,
            hierarchy: { parent: mockParentWorkItem },
          },
        },
      });

      expect(findParentMetadata().exists()).toBe(true);
      expect(findParentMetadata().props('parent')).toEqual(mockParentWorkItem);
    });
  });
});

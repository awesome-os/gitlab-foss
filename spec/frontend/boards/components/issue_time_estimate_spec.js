import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { setLanguage } from 'helpers/locale_helper';
import IssueTimeEstimate from '~/boards/components/issue_time_estimate.vue';

describe('Issue Time Estimate component', () => {
  let wrapper;

  const findIssueTimeEstimate = () => wrapper.find('[data-testid="issue-time-estimate"]');

  describe('when limitToHours is false', () => {
    beforeEach(() => {
      wrapper = shallowMount(IssueTimeEstimate, {
        propsData: {
          estimate: 374460,
        },
        provide: {
          timeTrackingLimitToHours: false,
        },
      });
    });

    it('renders the correct time estimate', () => {
      expect(wrapper.find('time').text().trim()).toEqual('2w 3d 1m');
    });

    it('renders expanded time estimate in tooltip', () => {
      expect(findIssueTimeEstimate().text()).toContain('2 weeks 3 days 1 minute');
    });

    it('prevents tooltip xss', async () => {
      const alertSpy = jest.spyOn(window, 'alert');

      try {
        // This will raise props validating warning by Vue, silencing it
        Vue.config.silent = true;
        await wrapper.setProps({ estimate: 'Foo <script>alert("XSS")</script>' });
      } finally {
        Vue.config.silent = false;
      }

      expect(alertSpy).not.toHaveBeenCalled();
      expect(wrapper.find('time').text().trim()).toEqual('0m');
      expect(findIssueTimeEstimate().text()).toContain('0m');
    });
  });

  describe('when the language is not English', () => {
    const format = (unitDisplay) =>
      new Intl.ListFormat('de', { type: 'unit', style: unitDisplay }).format(
        [
          [2, 'week'],
          [3, 'day'],
          [1, 'minute'],
        ].map(([value, unit]) =>
          new Intl.NumberFormat('de', { style: 'unit', unit, unitDisplay }).format(value),
        ),
      );

    beforeEach(() => {
      setLanguage('de');
      wrapper = shallowMount(IssueTimeEstimate, {
        propsData: {
          estimate: 374460,
        },
        provide: {
          timeTrackingLimitToHours: false,
        },
      });
    });

    afterEach(() => {
      setLanguage(null);
    });

    it('renders the time estimate with short localized units', () => {
      expect(wrapper.find('time').text().trim()).toBe(format('short'));
    });

    it('renders the time estimate with long localized units in tooltip', () => {
      expect(findIssueTimeEstimate().text()).toContain(format('long'));
    });
  });

  describe('when limitToHours is true', () => {
    beforeEach(() => {
      wrapper = shallowMount(IssueTimeEstimate, {
        propsData: {
          estimate: 374460,
        },
        provide: {
          timeTrackingLimitToHours: true,
        },
      });
    });

    it('renders the correct time estimate', () => {
      expect(wrapper.find('time').text().trim()).toEqual('104h 1m');
    });

    it('renders expanded time estimate in tooltip', () => {
      expect(findIssueTimeEstimate().text()).toContain('104 hours 1 minute');
    });
  });
});

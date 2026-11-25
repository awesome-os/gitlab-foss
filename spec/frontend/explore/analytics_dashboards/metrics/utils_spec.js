import { UNITS, FLOW_METRICS, VALUE_STREAM_METRIC_METADATA } from '~/analytics/shared/constants';
import {
  formatMetric,
  hasTrailingDecimalZero,
  buildMetricLink,
  calculateRate,
  generateMetricTableTooltip,
} from '~/explore/analytics_dashboards/metrics/utils';

describe('Analytics Dashboards metrics utils', () => {
  describe.each([
    { units: UNITS.PER_DAY, suffix: '/d' },
    { units: UNITS.DAYS, suffix: ' d' },
    { units: UNITS.PERCENT, suffix: '%' },
    { units: UNITS.MINUTES, suffix: ' m' },
  ])('formatMetric(*, $units)', ({ units, suffix }) => {
    it.each`
      value      | result
      ${0}       | ${'0.0'}
      ${10}      | ${'10.0'}
      ${-10}     | ${'-10.0'}
      ${1}       | ${'1.0'}
      ${-1}      | ${'-1.0'}
      ${0.1}     | ${'0.1'}
      ${-0.99}   | ${'-0.99'}
      ${0.099}   | ${'0.099'}
      ${-0.01}   | ${'-0.01'}
      ${0.0099}  | ${'0.0099'}
      ${-0.0001} | ${'-0.0001'}
    `('returns $result for a metric with the value $value', ({ value, result }) => {
      expect(formatMetric(value, units)).toBe(`${result}${suffix}`);
    });
  });

  describe('formatMetric(*, BIGINT_COUNT)', () => {
    it.each`
      value      | result
      ${0}       | ${'0'}
      ${10}      | ${'10'}
      ${-10}     | ${'-10'}
      ${1}       | ${'1'}
      ${-1}      | ${'-1'}
      ${0.1}     | ${'-'}
      ${-0.99}   | ${'-'}
      ${0.099}   | ${'-'}
      ${-0.01}   | ${'-'}
      ${0.0099}  | ${'-'}
      ${-0.0001} | ${'-'}
    `('returns $result for a metric with the value $value', ({ value, result }) => {
      expect(formatMetric(value, UNITS.BIGINT_COUNT)).toBe(result);
    });
  });

  describe('hasTrailingDecimalZero', () => {
    it.each`
      value         | result
      ${'-10.0/d'}  | ${false}
      ${'0.099/d'}  | ${false}
      ${'0.0099%'}  | ${false}
      ${'0.10%'}    | ${true}
      ${'-0.010 d'} | ${true}
    `('returns $result for value $value', ({ value, result }) => {
      expect(hasTrailingDecimalZero(value)).toBe(result);
    });
  });

  describe('buildMetricLink', () => {
    const namespace = 'group/project';
    const identifier = FLOW_METRICS.ISSUES_COMPLETED;
    const { groupLink, projectLink } = VALUE_STREAM_METRIC_METADATA[identifier];
    let originalRelativeUrlRoot;

    beforeEach(() => {
      originalRelativeUrlRoot = window.gon.relative_url_root;
      window.gon.relative_url_root = '';
    });

    afterEach(() => {
      window.gon.relative_url_root = originalRelativeUrlRoot;
    });

    it('returns an empty string when the identifier has no metadata', () => {
      expect(buildMetricLink({ identifier: 'not-a-metric', isProject: false, namespace })).toBe('');
    });

    it('returns an empty string when no namespace is provided', () => {
      expect(buildMetricLink({ identifier, isProject: false, namespace: '' })).toBe('');
    });

    it('builds a group drill-down link for a group namespace', () => {
      expect(buildMetricLink({ identifier, isProject: false, namespace })).toBe(
        `/groups/${namespace}/${groupLink}`,
      );
    });

    it('builds a project drill-down link for a project namespace', () => {
      expect(buildMetricLink({ identifier, isProject: true, namespace })).toBe(
        `/${namespace}/${projectLink}`,
      );
    });

    it('prepends the relative URL root when present', () => {
      window.gon.relative_url_root = '/gitlab';

      expect(buildMetricLink({ identifier, isProject: false, namespace })).toBe(
        `/gitlab/groups/${namespace}/${groupLink}`,
      );
    });

    it('appends filter labels as label_name query params', () => {
      expect(
        buildMetricLink({ identifier, isProject: true, namespace, filterLabels: ['bug', 'flow'] }),
      ).toBe(`/${namespace}/${projectLink}?label_name[]=bug&label_name[]=flow`);
    });
  });

  describe('calculateRate', () => {
    it('returns null when counts are invalid', () => {
      expect(calculateRate({ numerator: -2, denominator: 10 })).toBeNull();
      expect(calculateRate({ numerator: 1, denominator: 0 })).toBeNull();
    });

    it('returns null when counts are zero', () => {
      expect(calculateRate({ numerator: 0, denominator: 0 })).toBeNull();
    });

    it('returns rate as percentage', () => {
      expect(calculateRate({ numerator: 3, denominator: 4 })).toBe(75);
      expect(calculateRate({ numerator: 0, denominator: 1 })).toBe(0);
    });

    it('returns rate as decimal when asDecimal=true', () => {
      expect(calculateRate({ numerator: 5, denominator: 10, asDecimal: true })).toBe(0.5);
    });
  });

  describe('generateMetricTableTooltip', () => {
    const noDataMsg = 'No data';

    it.each`
      numerator    | denominator  | result
      ${4}         | ${5}         | ${'4/5'}
      ${0}         | ${20}        | ${'0/20'}
      ${undefined} | ${10}        | ${noDataMsg}
      ${8}         | ${undefined} | ${noDataMsg}
    `(`returns the metric table's tooltip as expected`, ({ numerator, denominator, result }) => {
      expect(generateMetricTableTooltip({ numerator, denominator })).toBe(result);
    });
  });
});

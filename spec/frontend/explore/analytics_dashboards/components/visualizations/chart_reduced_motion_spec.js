import { GlChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BarListChart from '~/explore/analytics_dashboards/components/visualizations/bar_list_chart.vue';
import DivergingBarChart from '~/explore/analytics_dashboards/components/visualizations/diverging_bar_chart.vue';
import HeatMapChart from '~/explore/analytics_dashboards/components/visualizations/heat_map_chart.vue';

describe.each`
  name                 | component            | propsData
  ${'bar list'}        | ${BarListChart}      | ${{ data: [{ name: 'Chat', value: 90, share: 90 }] }}
  ${'diverging chart'} | ${DivergingBarChart} | ${{ data: [{ name: 'Power', values: [1, 2] }], seriesNames: ['A', 'B'] }}
  ${'heat map'}        | ${HeatMapChart}      | ${{ data: [{ row: 'Power', column: 'Chat', value: 9 }] }}
`('$name', ({ component, propsData }) => {
  const mountWithReducedMotion = (matches) => {
    window.matchMedia = jest.fn().mockReturnValue({
      matches,
      addEventListener: jest.fn(),
      removeEventListener: jest.fn(),
    });
    return shallowMountExtended(component, { propsData });
  };

  const animation = (wrapper) => wrapper.findComponent(GlChart).props('options').animation;

  it('keeps the default animation', () => {
    expect(animation(mountWithReducedMotion(false))).toBeUndefined();
  });

  it('stops animating for people who ask for reduced motion', () => {
    expect(animation(mountWithReducedMotion(true))).toBe(false);
  });
});

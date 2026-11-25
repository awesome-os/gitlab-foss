import { GlChart } from '@gitlab/ui/src/charts';
import BarListChart from './bar_list_chart.vue';
import DivergingBarChart from './diverging_bar_chart.vue';
import HeatMapChart from './heat_map_chart.vue';
import {
  CHART_STYLES,
  CHART_STYLE_CLASSIC,
  CHART_STYLE_INJECTION_KEY,
  createStyler,
} from './chart_styles';

export default {
  title: 'explore/analytics_dashboards/components/visualizations/chart_styles',
  argTypes: {
    chartStyle: {
      control: { type: 'select' },
      options: CHART_STYLES,
      description: 'The style the dashboard provides. Every chart below follows it.',
    },
  },
};

const days = ['Nov 3', 'Nov 4', 'Nov 5', 'Nov 6', 'Nov 7', 'Nov 8', 'Nov 9'];

const sessions = [
  { name: 'Chat', data: [420, 510, 480, 560, 610, 300, 280] },
  { name: 'Code review', data: [120, 160, 150, 190, 210, 90, 70] },
  { name: 'Fix pipeline', data: [60, 80, 70, 110, 95, 40, 30] },
];

const outcomes = [
  { name: 'Approved', data: [32, 41, 38, 45, 52, 47, 55] },
  { name: 'Changes requested', data: [18, 22, 19, 24, 21, 26, 23] },
  { name: 'Abandoned', data: [6, 8, 5, 9, 7, 6, 8] },
];

const creditsWent = [
  { name: 'Chat', value: 85600, share: 89 },
  { name: 'Software Dev', value: 4600, share: 5 },
  { name: 'Developer', value: 2200, share: 2 },
  { name: 'Code Suggestions', value: 833, share: 0.9 },
];

const creditsByModel = [
  ['Claude Sonnet', 41000, 9000, 3000],
  ['GPT-5', 18000, 6000, 1500],
  ['Codestral', 4000, 2500, 900],
].map(([name, chat, review, fix]) => ({
  name,
  segments: [
    { name: 'Chat', value: chat },
    { name: 'Code review', value: review },
    { name: 'Fix pipeline', value: fix },
  ],
}));

const usersVsSessions = [
  { name: 'Power (100+)', values: [107, 3467] },
  { name: 'Heavy (25–99)', values: [288, 2111] },
  { name: 'Regular (5–24)', values: [472, 902] },
  { name: 'Light (1–4)', values: [531, 172] },
];

const tiers = ['Power', 'Heavy', 'Regular', 'Light'];
const capabilities = ['Chat', 'Code review', 'Fix pipeline', 'Code suggestions', 'Security'];
const heatCells = tiers.flatMap((row, r) =>
  capabilities.map((column, c) => ({ row, column, value: Math.round(900 / (r + 1) / (c + 1)) })),
);

// A column, line or area chart drawn from the styler. The GLQL presenters draw these through
// the @gitlab/ui wrappers, which set their own series styles, so this shows what a base chart
// that takes the style would draw.
const StyledSeriesPreview = {
  name: 'StyledSeriesPreview',
  components: { GlChart },
  inject: {
    getChartStyle: { from: CHART_STYLE_INJECTION_KEY, default: () => () => CHART_STYLE_CLASSIC },
  },
  props: {
    type: { type: String, required: true },
    categories: { type: Array, required: true },
    series: { type: Array, required: true },
  },
  computed: {
    styler() {
      return createStyler(this.getChartStyle());
    },
    options() {
      const { styler } = this;
      const isColumn = this.type === 'column';
      const series = this.series.map(({ name, data }, index) =>
        isColumn
          ? {
              type: 'bar',
              name,
              stack: 'total',
              barMaxWidth: 32,
              ...(styler.emphasis && { emphasis: styler.emphasis }),
              data: data.map((value) => ({
                value,
                itemStyle: styler.column(index, {
                  stacked: true,
                  cap: index === this.series.length - 1,
                }),
              })),
            }
          : {
              type: 'line',
              name,
              stack: this.type === 'area' ? 'total' : undefined,
              data,
              ...styler.line(index, { area: this.type === 'area' }),
              ...(styler.emphasis && { emphasis: styler.emphasis }),
            },
      );

      return {
        ...styler.animation(),
        grid: { top: 16, right: 16, bottom: 32, left: 44 },
        legend: { show: false },
        xAxis: {
          type: 'category',
          data: this.categories,
          boundaryGap: isColumn,
          ...styler.axes.category(),
        },
        yAxis: { type: 'value', ...styler.axes.value() },
        series,
      };
    },
  },
  template: '<gl-chart :options="options" :height="240" responsive />',
};

const panel = (title, body, note = '') => `
  <section class="gl-border gl-flex gl-min-w-0 gl-flex-col gl-gap-3 gl-rounded-lg gl-border-default gl-bg-default gl-p-5">
    <h3 class="gl-heading-5 gl-m-0">${title}</h3>
    ${note ? `<p class="gl-m-0 gl-text-sm gl-text-subtle">${note}</p>` : ''}
    ${body}
  </section>`;

const PREVIEW_NOTE = 'Preview: the GLQL presenter draws this with a @gitlab/ui wrapper today';

const Template = (args, { argTypes }) => ({
  components: { BarListChart, DivergingBarChart, HeatMapChart, StyledSeriesPreview },
  props: Object.keys(argTypes),
  // The same getter a dashboard would provide, so the control switches every chart at once.
  provide() {
    return { [CHART_STYLE_INJECTION_KEY]: () => this.chartStyle };
  },
  data() {
    return {
      days,
      sessions,
      outcomes,
      creditsWent,
      creditsByModel,
      usersVsSessions,
      heatCells,
      divergingNames: ['Share of users', 'Share of sessions'],
    };
  },
  template: `
    <div class="gl-flex gl-flex-col gl-gap-5 gl-bg-subtle gl-p-5" data-testid="chart-style-gallery">
      <h2 class="gl-heading-4 gl-m-0">Follow the style</h2>
      <div class="gl-grid gl-grid-cols-1 gl-gap-5 @md/panel:gl-grid-cols-2">
        ${panel('Bar list', '<bar-list-chart :data="creditsWent" color="blue" />')}
        ${panel('Stacked bar list', '<bar-list-chart :data="creditsByModel" />')}
        ${panel(
          'Diverging bars',
          '<diverging-bar-chart :data="usersVsSessions" :series-names="divergingNames" />',
        )}
        ${panel('Heat map', '<heat-map-chart :data="heatCells" />')}
      </div>
      <h2 class="gl-heading-4 gl-m-0">Need a base chart that takes the style</h2>
      <div class="gl-grid gl-grid-cols-1 gl-gap-5 @md/panel:gl-grid-cols-2">
        ${panel(
          'Stacked columns',
          '<styled-series-preview type="column" :categories="days" :series="sessions" />',
          PREVIEW_NOTE,
        )}
        ${panel(
          'Lines',
          '<styled-series-preview type="line" :categories="days" :series="outcomes" />',
          PREVIEW_NOTE,
        )}
        ${panel(
          'Stacked areas',
          '<styled-series-preview type="area" :categories="days" :series="sessions" />',
          PREVIEW_NOTE,
        )}
      </div>
    </div>`,
});

export const Classic = Template.bind({});
Classic.args = { chartStyle: 'classic' };

export const Modern = Template.bind({});
Modern.args = { chartStyle: 'modern' };

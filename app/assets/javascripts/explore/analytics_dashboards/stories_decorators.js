import '../../../stylesheets/page_bundles/explore_analytics_dashboards.scss';
import {
  CHART_STYLE_CLASSIC,
  CHART_STYLE_INJECTION_KEY,
} from './components/visualizations/chart_styles';
import { dashboardThemeClass } from './utils';

// The themes the dashboard YAML schema allows.
const DASHBOARD_THEMES = [CHART_STYLE_CLASSIC, 'modern'];

export const dashboardThemeArgTypes = {
  theme: {
    control: 'select',
    options: DASHBOARD_THEMES,
    description:
      'The theme the dashboard YAML names, as shown with `analytics_dashboard_themes` on.',
  },
};

/**
 * Shows a story in a dashboard theme. `defaultTheme` is the theme the story opens in;
 * the `theme` control, when set, overrides it.
 *
 * @example decorators: [withDashboardTheme('modern')]
 */
export const withDashboardTheme =
  (defaultTheme = CHART_STYLE_CLASSIC) =>
  (story, { args }) => ({
    components: { story },
    provide() {
      return { [CHART_STYLE_INJECTION_KEY]: () => this.theme };
    },
    computed: {
      theme() {
        return args.theme ?? defaultTheme;
      },
      themeClass() {
        return dashboardThemeClass(this.theme);
      },
    },
    watch: {
      themeClass: {
        handler(className, previousClassName) {
          if (previousClassName) document.body.classList.remove(previousClassName);
          if (className) document.body.classList.add(className);
        },
        immediate: true,
      },
    },
    beforeDestroy() {
      if (this.themeClass) document.body.classList.remove(this.themeClass);
    },
    template: '<story />',
  });

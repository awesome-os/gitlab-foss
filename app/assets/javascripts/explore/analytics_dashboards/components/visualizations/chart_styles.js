/* eslint-disable @gitlab/require-i18n-strings -- CSS values and ECharts option strings, not copy */
import { colorFromDefaultPalette } from '@gitlab/ui/src/utils/charts/theme';
import {
  GL_COLOR_DATA_BLUE_50,
  GL_COLOR_DATA_BLUE_100,
  GL_COLOR_DATA_BLUE_200,
  GL_COLOR_DATA_BLUE_400,
  GL_COLOR_DATA_BLUE_600,
  GL_COLOR_DATA_BLUE_800,
  GL_COLOR_NEUTRAL_0,
  GL_COLOR_NEUTRAL_50,
  GL_COLOR_NEUTRAL_800,
  GL_COLOR_NEUTRAL_950,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import {
  BAR_COLOR_BLUE,
  BAR_COLOR_GRAY,
  BAR_COLOR_ORANGE,
  BAR_COLOR_TOKENS,
} from './bar_list_chart_options';

// ECharts' SVG renderer writes colour strings into the SVG as-is, so `light-dark()` follows
// the colour mode with no redraw. Canvas cannot resolve them; these styles assume SVG.

export const CHART_STYLE_CLASSIC = 'classic';
export const CHART_STYLE_MODERN = 'modern';
export const CHART_STYLES = [CHART_STYLE_CLASSIC, CHART_STYLE_MODERN];

export const CHART_STYLE_INJECTION_KEY = 'getChartStyle';

const SURFACE = 'var(--gl-background-color-default)';
const TRACK = 'var(--gl-background-color-subtle)';
const TEXT = 'var(--gl-text-color-default)';

const pair = (light, dark) => `light-dark(${light}, ${dark})`;

/** `color` at `percent` opacity. */
export const translucent = (color, percent) =>
  `color-mix(in srgb, ${color} ${percent}%, transparent)`;

const tint = (color, percent) => `color-mix(in srgb, ${color} ${percent}%, ${SURFACE})`;

const linearGradient = (from, to, { horizontal = false } = {}) => ({
  type: 'linear',
  x: 0,
  y: 0,
  x2: horizontal ? 1 : 0,
  y2: horizontal ? 0 : 1,
  colorStops: [
    { offset: 0, color: from },
    { offset: 1, color: to },
  ],
});

// The palette from https://gitlab.com/gitlab-org/gitlab/-/merge_requests/269576. It has not
// passed the colour vision review, so only the modern style uses it.
const PROTOTYPE_PALETTE = [
  pair('#7c5cf5', '#8468f5'),
  pair('#0891b2', '#0ea5c6'),
  pair('#e64a8f', '#e64a8f'),
  pair('#c27800', '#c98500'),
  pair('#1a9c6b', '#1ea672'),
  pair('#3b82f6', '#4a8af0'),
];

// The heat map's blue ramp, lightest first. Dark mode reverses it and darkens the empty
// cell, as the contribution calendar does, so a busier cell is the more prominent one.
const BLUE_RAMP = [
  GL_COLOR_DATA_BLUE_50,
  GL_COLOR_DATA_BLUE_100,
  GL_COLOR_DATA_BLUE_200,
  GL_COLOR_DATA_BLUE_400,
  GL_COLOR_DATA_BLUE_600,
  GL_COLOR_DATA_BLUE_800,
];
const BLUE_RAMPS = {
  light: { empty: GL_COLOR_NEUTRAL_50, gap: GL_COLOR_NEUTRAL_0, values: BLUE_RAMP },
  dark: {
    empty: GL_COLOR_NEUTRAL_800,
    gap: GL_COLOR_NEUTRAL_950,
    values: [...BLUE_RAMP].reverse(),
  },
};
const TINT_STRENGTHS = [15, 30, 45, 60, 75, 90];
// Every step clears 4.5:1 with neutral-950 text in light mode and white text in dark mode.
const TINT_LABEL = pair(GL_COLOR_NEUTRAL_950, GL_COLOR_NEUTRAL_0);
const BAR_START_STRENGTH = 60;

/**
 * The styles, as data. Each key answers one question about the look, so a new style is a new
 * object and a design change is one value. `classic` is the look the charts have today.
 */
export const CHART_STYLE_PRESETS = {
  [CHART_STYLE_CLASSIC]: {
    palette: 'default',
    barList: { height: 7, radius: 0, fill: 'flat' },
    diverging: { height: 7, radius: 0, fill: 'flat' },
    heatMap: { ramp: 'blue', gaps: 'gridlines', gap: 2, radius: 0 },
    column: { fill: 'outline', radius: 0, stackGap: 0 },
    line: { width: 2, smooth: false, markers: 'always', area: 'flat' },
    axes: { ticks: true, gridline: 'solid', titleWeight: 'bold' },
    motion: 'default',
    hoverHighlight: true,
  },
  [CHART_STYLE_MODERN]: {
    palette: 'prototype',
    barList: { height: 16, radius: 8, fill: 'gradient' },
    diverging: { height: 16, radius: 8, fill: 'gradient' },
    heatMap: { ramp: 'tint', gaps: 'tiles', gap: 4, radius: 8 },
    column: { fill: 'gradient', radius: 8, stackGap: 1.5 },
    line: { width: 3, smooth: 0.35, markers: 'hover', area: 'wash' },
    axes: { ticks: false, gridline: 'dotted', titleWeight: 'normal' },
    motion: 'sweep',
    // ECharts lightens a mark on hover, and can't read the CSS colour strings this style uses,
    // so hovered marks flicker or lose their fill.
    hoverHighlight: false,
  },
};

const MOTION = {
  default: {},
  sweep: {
    animationDuration: 700,
    animationEasing: 'cubicOut',
    animationDurationUpdate: 200,
    animationEasingUpdate: 'cubicOut',
  },
  none: { animation: false },
};

const STAGGER_MS = 40;

const prefersReducedMotion = () =>
  Boolean(window.matchMedia?.('(prefers-reduced-motion: reduce)').matches);

export const isChartStyle = (name) => CHART_STYLES.includes(name);

/**
 * Turns a style name into the pieces of ECharts options that carry the look.
 *
 * @param {string} name one of CHART_STYLES; anything else falls back to classic
 */
export const createStyler = (name) => {
  const styleName = isChartStyle(name) ? name : CHART_STYLE_CLASSIC;
  const preset = CHART_STYLE_PRESETS[styleName];
  const reducedMotion = prefersReducedMotion();

  const color = (index) =>
    preset.palette === 'prototype'
      ? PROTOTYPE_PALETTE[index % PROTOTYPE_PALETTE.length]
      : colorFromDefaultPalette(index);
  const axisName = { fontWeight: preset.axes.titleWeight };

  return {
    name: styleName,

    /** Series colour, which follows the series, not its position among the visible ones. */
    color,

    /** A series' `emphasis`, or undefined to keep ECharts' hover highlight. */
    emphasis: preset.hoverHighlight ? undefined : { disabled: true },

    /** Spread into the root options. */
    animation: () => (reducedMotion ? MOTION.none : MOTION[preset.motion]),

    /** `animationDelay` for marks drawn in sequence. */
    stagger: () =>
      !reducedMotion && preset.motion === 'sweep' ? (i) => i * STAGGER_MS : undefined,

    barList: {
      height: preset.barList.height,
      radius: preset.barList.radius,
      track: TRACK,
      /** The fill for a single-colour bar list, by the bar colour name it was configured with. */
      fillFor: (colorName) => {
        if (preset.barList.fill !== 'gradient') {
          return BAR_COLOR_TOKENS[colorName] ?? BAR_COLOR_TOKENS[BAR_COLOR_ORANGE];
        }
        // One hue per bar, pale at the start and full at the value, as in the design prototype.
        // The prototype draws the `blue` bars in its teal.
        const hues = {
          [BAR_COLOR_BLUE]: color(1),
          [BAR_COLOR_ORANGE]: color(3),
          [BAR_COLOR_GRAY]: 'var(--gl-color-neutral-500)',
        };
        const hue = hues[colorName] ?? hues[BAR_COLOR_ORANGE];
        return linearGradient(tint(hue, BAR_START_STRENGTH), hue, { horizontal: true });
      },
      segment: (index) => ({ color: color(index) }),
    },

    diverging: {
      height: preset.diverging.height,
      radius: preset.diverging.radius,
      /** The fill for one half; `leftward` swaps the stops so the strong end is the data end. */
      fillFor: (index, { leftward = false } = {}) => {
        const base = color(index);
        if (preset.diverging.fill !== 'gradient') return base;
        const pale = tint(base, BAR_START_STRENGTH);
        const stops = leftward ? [base, pale] : [pale, base];
        return linearGradient(...stops, { horizontal: true });
      },
    },

    heatMap: {
      /** Cells sit on gridlines drawn in the gap colour, or are tiles with surface gaps. */
      tiles: preset.heatMap.gaps === 'tiles',
      gap: preset.heatMap.gap,
      radius: preset.heatMap.radius,
      /**
       * The ramp for the current colour mode, lightest first. A ramp without `labels` leaves the
       * label colour to a contrast check against each cell's hex colour.
       */
      ramp: (dark) => {
        if (preset.heatMap.ramp === 'tint') {
          const values = TINT_STRENGTHS.map((strength) => tint(color(0), strength));
          const empty = pair('#f4f4f6', '#28272d');
          return {
            empty,
            gap: SURFACE,
            values,
            // Every colour this ramp paints needs an entry: they are CSS strings, which the
            // contrast check behind `labelColorOn` cannot read.
            labels: new Map([[empty, TEXT], ...values.map((value) => [value, TINT_LABEL])]),
          };
        }
        return dark ? BLUE_RAMPS.dark : BLUE_RAMPS.light;
      },
    },

    // The look a column, line or area chart needs. The GLQL presenters draw those through the
    // @gitlab/ui wrappers, which set their own series styles, so only the Storybook gallery
    // uses these until a base chart takes them.
    column: (index, { stacked = false, cap = true } = {}) => {
      const base = color(index);
      const r = preset.column.radius;
      const fills = {
        outline: translucent(base, 20),
        gradient: linearGradient(base, translucent(base, 62)),
      };
      return {
        color: fills[preset.column.fill],
        borderColor: preset.column.fill === 'outline' ? base : SURFACE,
        borderWidth:
          preset.column.fill === 'outline' ? 1 : (stacked && preset.column.stackGap) || 0,
        borderRadius: cap && r ? [r, r, 0, 0] : 0,
      };
    },

    line: (index, { area = false } = {}) => {
      const base = color(index);
      const areaColor =
        preset.line.area === 'wash'
          ? linearGradient(translucent(base, 38), translucent(base, 0))
          : translucent(base, 20);
      return {
        smooth: preset.line.smooth,
        showSymbol: preset.line.markers !== 'hover' && !area,
        symbol: 'circle',
        symbolSize: preset.line.markers === 'hover' ? 10 : 6,
        lineStyle: { color: base, width: preset.line.width, type: 'solid' },
        itemStyle: { color: base },
        areaStyle: area ? { color: areaColor } : undefined,
      };
    },

    axes: {
      category: () => ({
        axisTick: { show: preset.axes.ticks },
        axisLine: { show: preset.axes.ticks },
        nameTextStyle: axisName,
      }),
      value: () => ({
        nameTextStyle: axisName,
        splitLine: {
          lineStyle: preset.axes.gridline === 'dotted' ? { type: [2, 6], opacity: 0.7 } : {},
        },
      }),
    },
  };
};

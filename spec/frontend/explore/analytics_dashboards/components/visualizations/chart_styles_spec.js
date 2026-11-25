import {
  CHART_STYLES,
  createStyler,
  isChartStyle,
  translucent,
} from '~/explore/analytics_dashboards/components/visualizations/chart_styles';

const mockReducedMotion = (matches) => {
  window.matchMedia = jest.fn().mockReturnValue({ matches });
};

describe('isChartStyle', () => {
  it.each(['classic', 'modern'])('accepts %s', (name) => {
    expect(isChartStyle(name)).toBe(true);
  });

  it.each(['neon', '', undefined])('rejects %s', (name) => {
    expect(isChartStyle(name)).toBe(false);
  });
});

describe('translucent', () => {
  it('mixes the colour with transparency at the given strength', () => {
    expect(translucent('#ff0000', 40)).toBe('color-mix(in srgb, #ff0000 40%, transparent)');
  });
});

describe('createStyler', () => {
  beforeEach(() => mockReducedMotion(false));

  it.each(['neon', undefined])('falls back to the classic style for %s', (name) => {
    expect(createStyler(name).name).toBe('classic');
  });

  it('leaves animation on by default', () => {
    expect(createStyler('classic').animation()).toEqual({});
  });

  it('reverses the heat map ramp in dark mode', () => {
    const { ramp } = createStyler('classic').heatMap;

    expect(ramp(true).values).toEqual([...ramp(false).values].reverse());
  });

  describe.each(CHART_STYLES)('%s', (name) => {
    it('turns animation off for people who ask for reduced motion', () => {
      mockReducedMotion(true);
      const styler = createStyler(name);

      expect(styler.animation()).toEqual({ animation: false });
      expect(styler.stagger()).toBeUndefined();
    });

    it('gives neighbouring series different colours', () => {
      const styler = createStyler(name);

      expect(styler.color(0)).not.toBe(styler.color(1));
    });

    it('rounds only the cap of a column', () => {
      expect(createStyler(name).column(0, { cap: false }).borderRadius).toBe(0);
    });
  });
});

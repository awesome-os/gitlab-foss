import { GlButton, GlIcon, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { assertProps } from 'helpers/assert_props';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import FeatureLibraryItem from '~/super_sidebar/components/feature_library/feature_library_item.vue';
import { TIERS } from '~/super_sidebar/components/feature_library/constants';

const baseItem = {
  id: 'repository',
  title: 'Repository',
  description: 'Browse and manage your code',
  icon: 'code',
  category: 'code',
  tier: TIERS.FREE,
  link: '/-/repository',
};

describe('FeatureLibraryItem', () => {
  let wrapper;

  const createWrapper = ({
    item = baseItem,
    pinned = false,
    solidBackground = false,
    supportsPins = true,
    variant,
  } = {}) => {
    wrapper = mountExtended(FeatureLibraryItem, {
      propsData: { item, pinned, solidBackground, supportsPins, variant },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
      attachTo: document.body,
    });
  };

  const findContent = () => wrapper.findByTestId('feature-library-item-content');
  const findTitle = () => wrapper.findByTestId('feature-library-item-title');
  const findTitleLink = () => wrapper.findComponent(GlLink);
  const findDescription = () => wrapper.findByTestId('feature-library-item-description');
  const findBadge = () => wrapper.findByTestId('feature-library-item-badge');
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPinButton = () => wrapper.findComponent(GlButton);
  const findLearnMore = () => wrapper.findByTestId('feature-library-item-learn-more');

  describe('variant prop', () => {
    it('rejects an unknown variant', () => {
      expect(() => assertProps(FeatureLibraryItem, { item: baseItem, variant: 'unknown' })).toThrow(
        'Invalid prop: custom validator check failed for prop "variant"',
      );
    });
  });

  describe('locked variant', () => {
    const variant = 'locked';
    const lockedItem = {
      ...baseItem,
      docs_url: '/help/user/project/repository',
      label: { type: 'new', plan: 'premium', text: 'New with Premium' },
    };

    describe('with a docs URL', () => {
      beforeEach(() => createWrapper({ item: lockedItem, variant }));

      it('renders the title as plain text rather than a link to the feature', () => {
        expect(findTitle().text()).toBe('Repository');
        expect(findTitle().attributes('href')).toBeUndefined();
      });

      it('does not render a pin button, even when pins are supported', () => {
        expect(findPinButton().exists()).toBe(false);
      });

      it('renders a Learn more link that opens the docs in a new tab', () => {
        expect(findLearnMore().text()).toBe('Learn more');
        expect(findLearnMore().attributes()).toMatchObject({
          href: '/help/user/project/repository',
          target: '_blank',
          rel: 'noopener noreferrer',
          'aria-label': 'Learn more about Repository',
        });
      });

      it('emits learn-more with the item id when the Learn more link is clicked', async () => {
        await findLearnMore().trigger('click');

        expect(wrapper.emitted('learn-more')).toEqual([['repository']]);
      });

      it('renders the label text from the catalog in the badge instead of the tier', () => {
        expect(findBadge().text()).toBe('New with Premium');
      });
    });

    describe('without a docs URL or label', () => {
      beforeEach(() => createWrapper({ item: baseItem, variant }));

      it('renders no Learn more link and no badge', () => {
        expect(findLearnMore().exists()).toBe(false);
        expect(findBadge().exists()).toBe(false);
      });
    });

    it.each([true, false])(
      'renders without a hover state when solidBackground is %s',
      (solidBackground) => {
        createWrapper({ variant, solidBackground });

        expect(wrapper.classes()).not.toContain('hover:gl-bg-default');
        expect(wrapper.classes()).not.toContain('hover:gl-bg-strong');
      },
    );
  });

  describe('rendering', () => {
    beforeEach(() => createWrapper());

    it('renders the icon', () => {
      expect(findIcon().props('name')).toBe('code');
    });

    it('renders the title', () => {
      expect(findTitle().text()).toBe('Repository');
    });

    it('renders the description', () => {
      expect(findDescription().text()).toBe('Browse and manage your code');
    });
  });

  describe('tier badge', () => {
    it.each([
      [TIERS.PREMIUM, 'Premium'],
      [TIERS.ULTIMATE, 'Ultimate'],
      [TIERS.ADD_ON, 'Add-on'],
    ])('renders %s as "%s"', (tier, expected) => {
      createWrapper({ item: { ...baseItem, tier } });

      expect(findBadge().text()).toBe(expected);
    });

    it.each([TIERS.FREE, undefined])('renders no badge for %s', (tier) => {
      createWrapper({ item: { ...baseItem, tier } });

      expect(findBadge().exists()).toBe(false);
    });

    it('renders the badge when the server marks the tier gated', () => {
      createWrapper({ item: { ...baseItem, tier: TIERS.ULTIMATE, tierGated: true } });

      expect(findBadge().text()).toBe('Ultimate');
    });

    it.each([TIERS.PREMIUM, TIERS.ULTIMATE, TIERS.ADD_ON])(
      'renders no badge for %s when the server marks the tier not gated',
      (tier) => {
        createWrapper({ item: { ...baseItem, tier, tierGated: false } });

        expect(findBadge().exists()).toBe(false);
      },
    );
  });

  describe('hover state', () => {
    it.each`
      solidBackground | hoverClass
      ${false}        | ${'hover:gl-bg-strong'}
      ${true}         | ${'hover:gl-bg-default'}
    `(
      'uses $hoverClass when solidBackground is $solidBackground',
      ({ solidBackground, hoverClass }) => {
        createWrapper({ solidBackground });

        expect(wrapper.classes()).toContain(hoverClass);
      },
    );
  });

  describe('description tooltip', () => {
    const findTooltipValue = () => getBinding(findContent().element, 'gl-tooltip').value;
    const hoverWithWidths = async ({ scrollWidth, clientWidth }) => {
      const el = findDescription().element;
      jest.spyOn(el, 'scrollWidth', 'get').mockReturnValue(scrollWidth);
      jest.spyOn(el, 'clientWidth', 'get').mockReturnValue(clientWidth);
      await wrapper.trigger('mouseenter');
    };

    it.each(['default', 'locked'])(
      'shows the full description when it is truncated in the %s variant',
      async (variant) => {
        createWrapper({ variant });
        await hoverWithWidths({ scrollWidth: 300, clientWidth: 200 });

        expect(findTooltipValue()).toBe(baseItem.description);
      },
    );

    it('shows no tooltip when the description fits', async () => {
      createWrapper();
      await hoverWithWidths({ scrollWidth: 200, clientWidth: 200 });

      expect(findTooltipValue()).toBe('');
    });

    it('shows no tooltip before the row is hovered', () => {
      createWrapper();

      expect(findTooltipValue()).toBe('');
    });
  });

  describe('title navigation', () => {
    it('renders the title as a link', () => {
      createWrapper();
      expect(findTitle().element.tagName).toBe('A');
      expect(findTitleLink().attributes('href')).toBe('/-/repository');
    });

    it('emits navigate with the item id when the title link is clicked', async () => {
      createWrapper();
      const link = findTitleLink();
      link.element.addEventListener('click', (e) => e.preventDefault());
      await link.trigger('click');
      expect(wrapper.emitted('navigate')).toEqual([['repository']]);
    });

    it('stretches the title link over the tile content area', () => {
      createWrapper();
      // The ::after overlay stretches against the positioned content wrapper.
      expect(findContent().classes()).toContain('gl-relative');
      expect(findTitleLink().classes()).toContain('gl-stretched-link');
    });

    it('keeps the pin action outside the stretched link click target', () => {
      createWrapper();
      expect(findContent().findComponent(GlButton).exists()).toBe(false);
    });
  });

  describe('focus()', () => {
    it('moves keyboard focus to the title link when the item has a link', () => {
      createWrapper();

      wrapper.vm.focus();

      expect(document.activeElement).toBe(findTitleLink().element);
    });
  });

  describe('pin button', () => {
    it('is not rendered when pins are not supported', () => {
      createWrapper({ supportsPins: false });
      expect(findPinButton().exists()).toBe(false);
    });

    it('is rendered when pins are supported', () => {
      createWrapper({ supportsPins: true });
      expect(findPinButton().exists()).toBe(true);
    });

    it('emits pin-toggle with nextState=true and the title when not pinned', async () => {
      createWrapper({ pinned: false });
      await findPinButton().trigger('click');
      expect(wrapper.emitted('pin-toggle')).toEqual([['repository', true, 'Repository']]);
    });

    it('emits pin-toggle with nextState=false and the title when pinned', async () => {
      createWrapper({ pinned: true });
      await findPinButton().trigger('click');
      expect(wrapper.emitted('pin-toggle')).toEqual([['repository', false, 'Repository']]);
    });

    it.each`
      pinned   | icon
      ${false} | ${'thumbtack'}
      ${true}  | ${'thumbtack-solid'}
    `(
      'shows the $icon icon without the selected state when pinned is $pinned',
      ({ pinned, icon }) => {
        createWrapper({ pinned });

        expect(findPinButton().props('icon')).toBe(icon);
        expect(findPinButton().props('selected')).toBe(false);
      },
    );

    it.each([true, false])('keeps the "Pin" aria-label when pinned is %s', (pinned) => {
      createWrapper({ pinned });
      expect(findPinButton().attributes('aria-label')).toBe('Pin Repository');
    });

    it.each([true, false])('sets aria-pressed to match pinned %s', (pinned) => {
      createWrapper({ pinned });
      expect(findPinButton().attributes('aria-pressed')).toBe(String(pinned));
    });

    it('shows "Pin" tooltip when not pinned', () => {
      createWrapper({ pinned: false });
      expect(getBinding(findPinButton().element, 'gl-tooltip').value).toBe('Pin');
    });

    it('shows "Unpin" tooltip when pinned', () => {
      createWrapper({ pinned: true });
      expect(getBinding(findPinButton().element, 'gl-tooltip').value).toBe('Unpin');
    });
  });
});

import { GlDisclosureDropdownItem, GlLink } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DisclosureNavItem from '~/super_sidebar/components/disclosure_nav_item.vue';

describe('DisclosureNavItem component', () => {
  let wrapper;

  const item = { id: 'general', title: 'General', link: '/general' };

  const findDropdownItem = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findLink = () => wrapper.findComponent(GlLink);

  const createWrapper = ({ props = {}, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(DisclosureNavItem, {
      propsData: { item, ...props },
    });
  };

  it('renders a dropdown item labelled with the item title', () => {
    createWrapper();

    expect(findDropdownItem().props('item')).toEqual({ text: 'General' });
  });

  describe('link', () => {
    beforeEach(() => {
      createWrapper({
        props: { item: { ...item, is_active: true }, panelType: 'project' },
        mountFn: mountExtended,
      });
    });

    it('renders a link with the base dropdown item styling', () => {
      expect(findLink().classes()).toContain('gl-new-dropdown-item-content');
      expect(findLink().attributes('href')).toBe('/general');
      expect(findLink().text()).toBe('General');
    });

    it('marks the active item with aria-current', () => {
      expect(findLink().attributes('aria-current')).toBe('page');
    });

    it('sets tracking attributes derived from the panel type', () => {
      expect(findLink().attributes()).toMatchObject({
        'data-track-action': 'click_menu_item',
        'data-track-label': 'general',
        'data-track-property': 'nav_panel_project',
      });
      expect(findLink().attributes('data-track-extra')).toBeUndefined();
    });

    it('renders the link as an unstyled, non-tabbable anchor (matching the library item)', () => {
      // The <li> is the single Tab stop; the link must not add extra ones.
      expect(findLink().attributes('tabindex')).toBe('-1');
      expect(findLink().props('variant')).toBe('unstyled');
    });
  });

  describe('when the item has no id or the panel type is unknown', () => {
    it('adds a data-track-extra title payload so the event can still be attributed', () => {
      createWrapper({
        props: { item: { title: 'General', link: '/general' } },
        mountFn: mountExtended,
      });

      expect(findLink().attributes()).toMatchObject({
        'data-track-label': 'item_without_id',
        'data-track-property': 'nav_panel_unknown',
        'data-track-extra': JSON.stringify({ title: 'General' }),
      });
    });
  });

  describe('keyboard activation', () => {
    it.each(['Enter', ' '])('clicks the link on "%s" keydown so it navigates', (key) => {
      createWrapper({ mountFn: mountExtended });

      const clickSpy = jest.spyOn(findLink().element, 'click').mockImplementation(() => {});

      findDropdownItem().element.dispatchEvent(
        new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }),
      );

      expect(clickSpy).toHaveBeenCalledTimes(1);
    });
  });
});

import { GlNavItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SettingsSideNav from '~/super_sidebar/components/settings_side_nav.vue';
import MenuSection from '~/super_sidebar/components/menu_section.vue';
import { HIDDEN_NAV_ITEM_CLASS } from '~/super_sidebar/constants';

describe('SettingsSideNav', () => {
  let wrapper;

  const item = {
    id: 'settings_menu',
    title: 'Settings',
    items: [
      { id: 'general', title: 'General', link: '/settings/general', is_active: true },
      { id: 'repository', title: 'Repository', link: '/settings/repository', is_active: false },
      {
        id: 'hidden',
        title: 'Hidden',
        link: '/settings/hidden',
        is_active: false,
        link_classes: HIDDEN_NAV_ITEM_CLASS,
      },
    ],
  };

  const findNav = () => wrapper.findByTestId('settings-side-nav');
  const findNavItems = () => wrapper.findAllComponents(GlNavItem);
  const findMenuSection = () => wrapper.findComponent(MenuSection);

  const createComponent = ({ provide = { panelType: 'project' } } = {}) => {
    wrapper = shallowMountExtended(SettingsSideNav, {
      propsData: { item },
      provide,
      stubs: { GlNavItem },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('labels the navigation with the section title', () => {
    expect(findNav().attributes('aria-label')).toBe('Settings');
  });

  it('renders a nav item for each visible settings page', () => {
    expect(findNavItems().wrappers.map((navItem) => navItem.text())).toEqual([
      'General',
      'Repository',
    ]);
  });

  it('links each nav item to its page and marks the active one', () => {
    expect(findNavItems().at(0).props()).toMatchObject({
      href: '/settings/general',
      selected: true,
    });
    expect(findNavItems().at(1).props()).toMatchObject({
      href: '/settings/repository',
      selected: false,
    });
  });

  it('tracks clicks on the nav items with the panel type', () => {
    expect(findNavItems().at(1).attributes()).toMatchObject({
      'data-track-action': 'click_menu_item',
      'data-track-label': 'repository',
      'data-track-property': 'nav_panel_project',
    });
  });

  it('tracks clicks with an unknown panel when no panel type is provided', () => {
    createComponent({ provide: {} });

    expect(findNavItems().at(0).attributes('data-track-property')).toBe('nav_panel_unknown');
  });

  describe('on small screens', () => {
    it('renders a collapsed section labelled with the active page', () => {
      expect(findMenuSection().props('item')).toMatchObject({
        title: 'General',
        is_active: false,
        items: item.items,
      });
    });

    it('prefixes the section ids so they do not clash with the sidebar', () => {
      expect(findMenuSection().props('idPrefix')).toBe('settings-side-nav');
    });

    it('falls back to the section title when no page is active', () => {
      wrapper = shallowMountExtended(SettingsSideNav, {
        propsData: { item: { ...item, items: [{ ...item.items[1] }] } },
      });

      expect(findMenuSection().props('item').title).toBe('Settings');
    });
  });

  describe('with nested sections', () => {
    const nestedItem = {
      id: 'settings_menu',
      title: 'Settings',
      items: [
        { id: 'profile_menu', title: 'Profile', link: '/profile', is_active: false, items: [] },
        {
          id: 'access_menu',
          title: 'Access',
          link: '/password',
          is_active: true,
          items: [
            { id: 'password', title: 'Password', link: '/password', is_active: false },
            { id: 'ssh_keys', title: 'SSH keys', link: '/ssh_keys', is_active: true },
            {
              id: 'hidden',
              title: 'Hidden',
              link: '/hidden',
              is_active: false,
              link_classes: HIDDEN_NAV_ITEM_CLASS,
            },
          ],
        },
      ],
    };
    const findGroups = () => wrapper.findAllByTestId('settings-side-nav-group');

    beforeEach(() => {
      wrapper = shallowMountExtended(SettingsSideNav, {
        propsData: { item: nestedItem },
        provide: { panelType: 'profile' },
        stubs: { GlNavItem },
      });
    });

    it('renders the top-level links, then the visible pages of each section under its heading', () => {
      expect(findNavItems().wrappers.map((navItem) => navItem.text())).toEqual([
        'Profile',
        'Password',
        'SSH keys',
      ]);
      expect(findGroups()).toHaveLength(1);
      expect(findGroups().at(0).text()).toContain('Access');
    });

    it('labels the group list with its heading', () => {
      const list = findGroups().at(0).find('ul');

      expect(
        findGroups()
          .at(0)
          .find(`#${list.attributes('aria-labelledby')}`)
          .text(),
      ).toBe('Access');
    });

    it('marks only the active page of the section as selected', () => {
      expect(findNavItems().wrappers.map((navItem) => navItem.props('selected'))).toEqual([
        false,
        false,
        true,
      ]);
    });

    it('labels the small screen section with the active nested page', () => {
      expect(findMenuSection().props('item').title).toBe('SSH keys');
    });
  });
});

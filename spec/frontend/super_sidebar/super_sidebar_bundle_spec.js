import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initSettingsSideNav } from '~/super_sidebar/super_sidebar_bundle';

describe('initSettingsSideNav', () => {
  const settingsMenu = {
    id: 'settings_menu',
    title: 'Settings',
    items: [{ id: 'general', title: 'General', link: '/settings/general', is_active: true }],
  };
  const sidebarData = { current_menu_items: [{ id: 'manage_menu', items: [] }, settingsMenu] };

  const findNav = () => document.querySelector('[data-testid="settings-side-nav"]');

  afterEach(() => {
    resetHTMLFixture();
  });

  it('does nothing without a mount element', () => {
    setHTMLFixture('<div></div>');

    expect(initSettingsSideNav({ sidebarData })).toBe(false);
  });

  it('does nothing without a settings menu in the sidebar data', () => {
    setHTMLFixture('<div id="js-settings-side-nav" data-menu-id="settings_menu"></div>');

    expect(initSettingsSideNav({ sidebarData: { current_menu_items: [] } })).toBe(false);
    expect(findNav()).toBeNull();
  });

  it('does nothing when the sidebar data has no menu with the given id', () => {
    setHTMLFixture('<div id="js-settings-side-nav" data-menu-id="admin_settings_menu"></div>');

    expect(initSettingsSideNav({ sidebarData })).toBe(false);
    expect(findNav()).toBeNull();
  });

  it('renders the settings navigation from the sidebar data', () => {
    setHTMLFixture('<div id="js-settings-side-nav" data-menu-id="settings_menu"></div>');

    initSettingsSideNav({ sidebarData });

    expect(findNav().getAttribute('aria-label')).toBe('Settings');
    expect(findNav().textContent).toContain('General');
  });

  it('provides the sidebar panel type for tracking', () => {
    setHTMLFixture('<div id="js-settings-side-nav" data-menu-id="settings_menu"></div>');

    initSettingsSideNav({ sidebarData: { ...sidebarData, panel_type: 'project' } });

    expect(
      findNav().querySelector('[data-testid="settings-side-nav-item"]').dataset.trackProperty,
    ).toBe('nav_panel_project');
  });
});

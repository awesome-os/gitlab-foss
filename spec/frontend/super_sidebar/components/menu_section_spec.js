import Vue, { computed, nextTick } from 'vue';
import { GlNavItem, GlCollapse, GlDisclosureDropdown, GlDisclosureDropdownGroup } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import MenuSection from '~/super_sidebar/components/menu_section.vue';
import NavItem from '~/super_sidebar/components/nav_item.vue';
import FlyoutMenu from '~/super_sidebar/components/flyout_menu.vue';
import DisclosureNavItem from '~/super_sidebar/components/disclosure_nav_item.vue';
import { HIDDEN_NAV_ITEM_CLASS } from '~/super_sidebar/constants';
import { stubComponent } from 'helpers/stub_component';

describe('MenuSection component', () => {
  let wrapper;
  // eslint-disable-next-line no-restricted-properties
  const provideState = Vue.observable({ isIconOnly: false });

  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findFlyout = () => wrapper.findComponent(FlyoutMenu);
  const findDisclosure = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDisclosureNavItems = () => wrapper.findAllComponents(DisclosureNavItem);
  const findNavItems = () => wrapper.findAllComponents(NavItem);
  const findNavItem = () => wrapper.findComponent(GlNavItem);

  const createWrapper = (item, otherProps, { attachTooltip = false, ...provide } = {}) => {
    provideState.isIconOnly = provide.isIconOnly ?? false;

    wrapper = shallowMountExtended(MenuSection, {
      ...(attachTooltip && { directives: { GlTooltip: createMockDirective('gl-tooltip') } }),
      propsData: { item: { items: [], ...item }, ...otherProps },
      provide: {
        isIconOnly: computed(() => provideState.isIconOnly),
      },
      stubs: {
        GlNavItem,
        GlCollapse: stubComponent(GlCollapse, {
          props: ['visible'],
        }),
        GlDisclosureDropdown: stubComponent(GlDisclosureDropdown, {
          template: `<div><slot name="toggle" :accessibility-attributes="{}" /><slot /></div>`,
        }),
      },
    });
  };

  it('renders its title', () => {
    createWrapper({ title: 'Asdf' });
    expect(findNavItem().text()).toBe('Asdf');
  });

  it('uses title rather than disclosure_title when not rendered as a disclosure', () => {
    createWrapper({ title: 'Settings', disclosure_title: 'Project settings' });

    expect(findNavItem().text()).toBe('Settings');
    expect(findNavItem().attributes('aria-label')).toBe('Settings');
  });

  it('renders all its subitems', () => {
    createWrapper({
      title: 'Asdf',
      items: [
        { title: 'Item1', href: '/item1' },
        { title: 'Item2', href: '/item2' },
      ],
    });
    expect(findNavItems()).toHaveLength(2);
  });

  it('emits `nav-link-click` when a subitem link is clicked', () => {
    createWrapper({ title: 'Asdf', items: [{ title: 'Item1', href: '/item1' }] });
    findNavItems().at(0).vm.$emit('nav-link-click');

    expect(wrapper.emitted('nav-link-click')).toHaveLength(1);
  });

  it('associates button with list with aria-controls', () => {
    createWrapper({ title: 'Asdf' });
    expect(findNavItem().attributes('aria-controls')).toBe('asdf');
    expect(findCollapse().attributes('id')).toBe('asdf');
  });

  it('prefixes the ids with idPrefix', () => {
    createWrapper({ title: 'Asdf' }, { idPrefix: 'settings-side-nav' });
    expect(findNavItem().attributes('aria-controls')).toBe('settings-side-nav-asdf');
    expect(findCollapse().attributes('id')).toBe('settings-side-nav-asdf');
  });

  describe('collapse behavior', () => {
    describe('when active', () => {
      it('is expanded', () => {
        createWrapper({ title: 'Asdf', is_active: true });
        expect(findNavItem().props('expanded')).toBe(true);
        expect(findCollapse().props('visible')).toBe(true);
      });
    });

    describe('when active and set to collapse', () => {
      beforeEach(() => {
        createWrapper({ title: 'Asdf', is_active: true }, { collapseActive: true });
      });

      it('is not expanded', () => {
        expect(findNavItem().props('expanded')).toBe(false);
        expect(findCollapse().props('visible')).toBe(false);
      });

      it('shows the section header as active', () => {
        expect(findNavItem().props('selected')).toBe(true);
      });

      it('expands when no longer set to collapse', async () => {
        wrapper.setProps({ collapseActive: false });
        await nextTick();

        expect(findCollapse().props('visible')).toBe(true);
        expect(findNavItem().props('selected')).toBe(false);
      });
    });

    describe('when not active and collapseActive changes', () => {
      it('keeps its own expanded state', async () => {
        createWrapper({ title: 'Asdf' }, { expanded: true, collapseActive: false });

        wrapper.setProps({ collapseActive: true });
        await nextTick();

        expect(findCollapse().props('visible')).toBe(true);
      });
    });

    describe('when active and set to keep collapsed', () => {
      it('is not expanded', () => {
        createWrapper({ title: 'Asdf', is_active: true, keep_collapsed: true });
        expect(findNavItem().props('expanded')).toBe(false);
      });
    });

    describe('when set to expanded', () => {
      it('is expanded', () => {
        createWrapper({ title: 'Asdf' }, { expanded: true });
        expect(findNavItem().props('expanded')).toBe(true);
        expect(findCollapse().props('visible')).toBe(true);
      });
    });

    describe('when not active nor set to expanded', () => {
      it('is not expanded', () => {
        createWrapper({ title: 'Asdf' }, { expanded: false });
        expect(findNavItem().props('expanded')).toBe(false);
        expect(findCollapse().props('visible')).toBe(false);
      });
    });

    describe('when in icon-only mode', () => {
      it('does not show as expanded nor is expandable', () => {
        createWrapper({ title: 'Asdf' }, { expanded: true }, { isIconOnly: true });
        expect(findNavItem().props('isIconOnly')).toBe(true);
        expect(findCollapse().classes()).toContain('gl-hidden');
        expect(findCollapse().props('visible')).toBe(true);
      });
    });

    describe('when coming out of icon-only mode', () => {
      it('shows expanded as expanded again', async () => {
        createWrapper({ title: 'Asdf' }, { expanded: true }, { isIconOnly: true });
        expect(findCollapse().classes()).toContain('gl-hidden');

        provideState.isIconOnly = false;
        await nextTick();

        expect(findCollapse().classes()).not.toContain('gl-hidden');
        expect(findCollapse().props('visible')).toBe(true);
      });
    });

    describe('when in icon-only mode and headerless', () => {
      it('shows icons of pinned items', () => {
        createWrapper(
          { title: 'Pinned' },
          { expanded: true, headerless: true },
          { isIconOnly: true },
        );
        expect(findCollapse().classes()).not.toContain('gl-hidden');
      });
    });

    describe('when headerless and not expanded', () => {
      // Regression: a category collapsed in the expanded sidebar carried a
      // stale `expanded: false` into icon-only mode, where a headerless section
      // has no toggle to reopen it, so its pinned icons vanished.
      it('keeps the collapse open because there is no header to reopen it', () => {
        createWrapper({ title: 'Pinned' }, { expanded: false, headerless: true });

        expect(findCollapse().props('visible')).toBe(true);
      });
    });

    describe('when first mounted headerless then the header reappears', () => {
      // Regression: a section first mounted headerless (sidebar loads icon-only)
      // force-expanded isExpanded, so when the header reappeared it stayed open
      // regardless of its real collapse state.
      it('re-syncs to the collapsed expanded prop when the header reappears', async () => {
        createWrapper({ title: 'Pinned' }, { expanded: false, headerless: true });
        expect(findCollapse().props('visible')).toBe(true);

        await wrapper.setProps({ headerless: false });

        expect(findCollapse().props('visible')).toBe(false);
      });

      it('honors an expanded prop of true when the header reappears', async () => {
        createWrapper({ title: 'Pinned' }, { expanded: true, headerless: true });

        await wrapper.setProps({ headerless: false });

        expect(findCollapse().props('visible')).toBe(true);
      });
    });
  });

  describe('boldTitle prop', () => {
    const findTitleLabel = () => wrapper.find('.menu-section-button-label');

    it('renders the title in a heavier font weight when true', () => {
      createWrapper({ title: 'Asdf' }, { boldTitle: true });

      expect(findTitleLabel().classes()).toContain('gl-font-bold');
    });

    it('does not add the heavier font weight by default', () => {
      createWrapper({ title: 'Asdf' });

      expect(findTitleLabel().classes()).not.toContain('gl-font-bold');
    });
  });

  describe('revealChevronOnHover prop', () => {
    it('marks the header as the hover context when true', () => {
      createWrapper({ title: 'Asdf' }, { revealChevronOnHover: true });

      expect(findNavItem().classes()).toContain('super-sidebar-category-toggle');
      expect(wrapper.findByTestId('nav-item-chevron').exists()).toBe(true);
    });

    it('does not mark the header as the hover context by default', () => {
      createWrapper({ title: 'Asdf' });

      expect(findNavItem().classes()).not.toContain('super-sidebar-category-toggle');
    });
  });

  describe('flyout behavior', () => {
    describe('when hasFlyout is false', () => {
      it('is not rendered', () => {
        createWrapper({ title: 'Asdf' }, { 'has-flyout': false });
        expect(findFlyout().exists()).toBe(false);
      });
    });

    describe('when hasFlyout is true', () => {
      it('is not yet rendered', () => {
        createWrapper({ title: 'Asdf' }, { 'has-flyout': true });
        expect(findFlyout().exists()).toBe(false);
      });

      describe.each(['mouse', 'pen'])('on %s hover', (pointerType) => {
        describe('when section is expanded', () => {
          it('is not rendered', async () => {
            createWrapper({ title: 'Asdf' }, { 'has-flyout': true, expanded: true });
            await findNavItem().trigger('pointerover', { pointerType });
            expect(findFlyout().exists()).toBe(false);
          });
        });

        describe('when section is not expanded', () => {
          describe('when section has no items', () => {
            it('is not rendered', async () => {
              createWrapper({ title: 'Asdf' }, { 'has-flyout': true, expanded: false });
              await findNavItem().trigger('pointerover', { pointerType });
              expect(findFlyout().exists()).toBe(false);
            });
          });

          describe('when section has items', () => {
            beforeEach(() => {
              createWrapper(
                { title: 'Asdf', items: [{ title: 'Item1', href: '/item1' }] },
                { 'has-flyout': true, expanded: false },
              );
            });

            it('is rendered and shown', async () => {
              await findNavItem().trigger('pointerover', { pointerType });
              expect(findFlyout().isVisible()).toBe(true);
            });

            it('adds a class to keep hover effect on button while flyout is hovered', async () => {
              await findNavItem().trigger('pointerover', { pointerType });
              expect(findNavItem().classes()).not.toContain('with-mouse-over-flyout');
              await findFlyout().vm.$emit('mouseover');
              expect(findNavItem().classes()).toContain('with-mouse-over-flyout');
            });
          });
        });
      });

      describe('on mouse click (or mobile touch) while in icon-only mode', () => {
        beforeEach(() => {
          createWrapper(
            { title: 'Asdf', items: [{ title: 'Item1', href: '/item1' }] },
            { 'has-flyout': true, expanded: false },
            { isIconOnly: true },
          );
        });

        it('opens the flyout menu', async () => {
          expect(findFlyout().exists()).toBe(false);
          await findNavItem().trigger('click');
          expect(findFlyout().exists()).toBe(true);
        });

        it('closes the flyout menu on outside click', async () => {
          await findNavItem().trigger('click');
          expect(findFlyout().exists()).toBe(true);

          await document.body.click();
          expect(findFlyout().exists()).toBe(false);
        });
      });

      describe('when section gets closed', () => {
        describe('with mouse pointer', () => {
          beforeEach(async () => {
            createWrapper(
              { title: 'Asdf', items: [{ title: 'Item1', href: '/item1' }] },
              { expanded: true, 'has-flyout': true },
            );
            await findNavItem().trigger('click');
            await findNavItem().trigger('pointerover', { pointerType: 'mouse' });
          });

          it('shows the flyout only after section title gets hovered out and in again', async () => {
            expect(findCollapse().props('visible')).toBe(false);
            expect(findFlyout().exists()).toBe(false);

            await findNavItem().trigger('pointerleave');
            await findNavItem().trigger('pointerover', { pointerType: 'mouse' });

            expect(findCollapse().props('visible')).toBe(false);
            expect(findFlyout().isVisible()).toBe(true);
          });
        });

        describe('with pen pointer', () => {
          beforeEach(async () => {
            createWrapper(
              { title: 'Asdf', items: [{ title: 'Item1', href: '/item1' }] },
              { expanded: true, 'has-flyout': true },
            );
            await findNavItem().trigger('click');
            await findNavItem().trigger('pointerover', { pointerType: 'pen' });
          });

          it('shows the flyout only after section title gets hovered out and in again', async () => {
            expect(findCollapse().props('visible')).toBe(false);
            expect(findFlyout().exists()).toBe(false);

            await findNavItem().trigger('pointerleave');
            await findNavItem().trigger('pointerover', { pointerType: 'pen' });

            expect(findCollapse().props('visible')).toBe(false);
            expect(findFlyout().isVisible()).toBe(true);
          });
        });
      });
    });
  });

  describe('when `disclosure` is true', () => {
    beforeEach(() => {
      createWrapper(
        { title: 'Settings', items: [{ id: 'general', title: 'General', link: '/general' }] },
        { disclosure: true, 'has-flyout': true },
      );
    });

    it('renders a disclosure dropdown with its items and no collapse or flyout', () => {
      expect(findDisclosure().exists()).toBe(true);
      expect(findDisclosureNavItems()).toHaveLength(1);
      expect(findDisclosureNavItems().at(0).props('item')).toMatchObject({ title: 'General' });
      expect(findCollapse().exists()).toBe(false);
      expect(findFlyout().exists()).toBe(false);
    });

    it('renders the dropdown contents as a list (ul) for valid, accessible markup', async () => {
      wrapper = mountExtended(MenuSection, {
        propsData: {
          item: {
            title: 'Settings',
            icon: 'settings',
            items: [{ id: 'general', title: 'General', link: '/general' }],
          },
          disclosure: true,
        },
      });

      await wrapper.findByTestId('menu-section-button').trigger('click');
      await nextTick();

      expect(wrapper.find('[data-testid="disclosure-content"]').element.tagName).toBe('UL');
    });

    it('passes the panel type to every disclosure item, including those in nested sections', () => {
      createWrapper(
        {
          title: 'Settings',
          items: [
            { id: 'profile', title: 'Profile', link: '/profile' },
            {
              id: 'access',
              title: 'Access',
              items: [{ id: 'ssh_keys', title: 'SSH keys', link: '/ssh_keys' }],
            },
          ],
        },
        { disclosure: true, panelType: 'profile' },
      );

      expect(findDisclosureNavItems()).toHaveLength(2);
      findDisclosureNavItems().wrappers.forEach((navItem) => {
        expect(navItem.props('panelType')).toBe('profile');
      });
    });

    describe('with nested sections', () => {
      const hidden = { link_classes: HIDDEN_NAV_ITEM_CLASS };
      const item = {
        title: 'Settings',
        icon: 'settings',
        items: [
          { id: 'profile', title: 'Profile', link: '/profile', items: [] },
          {
            id: 'access',
            title: 'Access',
            items: [
              { id: 'ssh_keys', title: 'SSH keys', link: '/ssh_keys' },
              { id: 'hidden_page', title: 'Hidden page', link: '/hidden', ...hidden },
            ],
          },
          {
            id: 'all_hidden',
            title: 'All hidden',
            items: [{ id: 'other_hidden', title: 'Other', link: '/other', ...hidden }],
          },
        ],
      };
      const findGroups = () => wrapper.findAllComponents(GlDisclosureDropdownGroup);
      const groupItemTitles = (group) =>
        group.findAllComponents(DisclosureNavItem).wrappers.map((w) => w.props('item').title);

      it('renders top-level links first, then a bordered group per section', () => {
        createWrapper(item, { disclosure: true });

        expect(findGroups()).toHaveLength(2);
        expect(groupItemTitles(findGroups().at(0))).toEqual(['Profile']);
        expect(findGroups().at(0).props('bordered')).toBe(false);
        expect(groupItemTitles(findGroups().at(1))).toEqual(['SSH keys']);
        expect(findGroups().at(1).props('bordered')).toBe(true);
      });

      it('does not border the first section when there are no top-level links', () => {
        createWrapper({ ...item, items: item.items.slice(1) }, { disclosure: true });

        expect(findGroups()).toHaveLength(1);
        expect(findGroups().at(0).props('bordered')).toBe(false);
      });

      it('labels each section group with the section title', async () => {
        wrapper = mountExtended(MenuSection, { propsData: { item, disclosure: true } });

        await wrapper.findByTestId('menu-section-button').trigger('click');
        await nextTick();

        expect(wrapper.findByTestId('disclosure-section-group').text()).toContain('Access');
      });
    });

    describe('toggle label', () => {
      it('renders a labelled toggle in the expanded sidebar', () => {
        createWrapper(
          { title: 'Settings', items: [] },
          { disclosure: true },
          { isIconOnly: false },
        );

        expect(findNavItem().props('isIconOnly')).toBe(false);
      });

      it('renders an icon-only toggle in the collapsed sidebar', () => {
        createWrapper({ title: 'Settings', items: [] }, { disclosure: true }, { isIconOnly: true });

        expect(findNavItem().props('isIconOnly')).toBe(true);
      });

      it('uses disclosure_title for the label and aria-label when provided', () => {
        createWrapper(
          { title: 'Settings', disclosure_title: 'Project settings', items: [] },
          { disclosure: true },
          { isIconOnly: false },
        );

        expect(findNavItem().text()).toBe('Project settings');
        expect(findNavItem().attributes('aria-label')).toBe('Project settings');
      });

      it('falls back to title when disclosure_title is absent', () => {
        createWrapper(
          { title: 'Settings', items: [] },
          { disclosure: true },
          { isIconOnly: false },
        );

        expect(findNavItem().text()).toBe('Settings');
        expect(findNavItem().attributes('aria-label')).toBe('Settings');
      });

      it('keeps the unqualified title for QA selectors', () => {
        createWrapper(
          { title: 'Settings', disclosure_title: 'Project settings', items: [] },
          { disclosure: true },
          { isIconOnly: false },
        );

        expect(findNavItem().attributes('data-qa-section-name')).toBe('Settings');
      });
    });

    describe('toggle tooltip', () => {
      const createTooltipWrapper = (props, provide) =>
        createWrapper(
          { title: 'Settings' },
          { disclosure: true, ...props },
          { ...provide, attachTooltip: true },
        );

      const getTooltip = () => getBinding(findNavItem().element, 'gl-tooltip').value;

      it('has no tooltip title on the labelled (expanded) toggle', () => {
        createTooltipWrapper({}, { isIconOnly: false });

        expect(getTooltip().title).toBe('');
      });

      it('anchors the tooltip to the right in the collapsed sidebar', () => {
        createTooltipWrapper({}, { isIconOnly: true });

        expect(getTooltip()).toMatchObject({ title: 'Settings', placement: 'right' });
      });

      it('uses disclosure_title in the collapsed tooltip when provided', () => {
        createWrapper(
          { title: 'Settings', disclosure_title: 'Project settings' },
          { disclosure: true },
          { isIconOnly: true, attachTooltip: true },
        );

        expect(getTooltip()).toMatchObject({ title: 'Project settings', placement: 'right' });
      });
    });
  });

  describe('with nested sections', () => {
    const hidden = { link_classes: HIDDEN_NAV_ITEM_CLASS };
    const item = {
      title: 'Settings',
      items: [
        { id: 'profile', title: 'Profile', link: '/profile', items: [] },
        {
          id: 'access',
          title: 'Access',
          items: [
            { id: 'ssh_keys', title: 'SSH keys', link: '/ssh_keys' },
            { id: 'hidden_page', title: 'Hidden page', link: '/hidden', ...hidden },
          ],
        },
        {
          id: 'all_hidden',
          title: 'All hidden',
          items: [{ id: 'other_hidden', title: 'Other', link: '/other', ...hidden }],
        },
      ],
    };
    const findGroups = () => wrapper.findAllByTestId('menu-section-group');
    const itemTitles = (parent) =>
      parent.findAllComponents(NavItem).wrappers.map((w) => w.props('item').title);

    beforeEach(() => {
      createWrapper(item, { expanded: true });
    });

    it('renders top-level links first, then a headed group per section with visible pages', () => {
      expect(itemTitles(wrapper)).toEqual(['Profile', 'SSH keys']);
      expect(findGroups()).toHaveLength(1);
      expect(findGroups().at(0).text()).toContain('Access');
      expect(itemTitles(findGroups().at(0))).toEqual(['SSH keys']);
    });

    it('labels each group list with its heading', () => {
      const list = findGroups().at(0).find('ul');

      expect(
        findGroups()
          .at(0)
          .find(`#${list.attributes('aria-labelledby')}`)
          .text(),
      ).toBe('Access');
    });

    it('lists the top-level links and the pages of nested sections in the flyout', async () => {
      createWrapper(item, { 'has-flyout': true, expanded: false });

      await findNavItem().trigger('pointerover', { pointerType: 'mouse' });

      expect(
        findFlyout()
          .props('items')
          .map(({ title }) => title),
      ).toEqual(['Profile', 'SSH keys']);
    });
  });

  describe('`tag` prop', () => {
    describe('by default', () => {
      it('renders as <div> tag', () => {
        createWrapper({ title: 'Asdf' });
        expect(wrapper.element.tagName).toBe('DIV');
      });
    });

    describe('when set to "li"', () => {
      it('renders as <li> tag', () => {
        createWrapper({ title: 'Asdf' }, { tag: 'li' });
        expect(wrapper.element.tagName).toBe('LI');
      });
    });
  });
});

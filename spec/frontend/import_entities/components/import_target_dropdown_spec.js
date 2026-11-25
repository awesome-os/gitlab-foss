import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mount, shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

import ImportTargetDropdown from '~/import_entities/components/import_target_dropdown.vue';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import searchNamespacesWhereUserCanImportProjectsQuery from '~/import_entities/import_projects/graphql/queries/search_namespaces_where_user_can_import_projects.query.graphql';
import importTargetSyncAvailabilityQuery from '~/import_entities/import_projects/graphql/queries/import_target_sync_availability.query.graphql';

import {
  mockAvailableNamespaces,
  mockGroupFactory,
  mockNamespacesResponse,
  mockUserNamespace,
} from '../mock_data';

Vue.use(VueApollo);

describe('ImportTargetDropdown', () => {
  let wrapper;

  const defaultProps = {
    selected: mockUserNamespace,
  };

  // Renders every option through the list-item slot so tests can see the item markup
  const ListboxRenderingItemsStub = {
    props: ['items'],
    render(h) {
      return h(
        'ul',
        this.items.flatMap((group) =>
          group.options.map((option) => h('li', this.$scopedSlots['list-item']({ item: option }))),
        ),
      );
    },
  };

  const createComponent = ({
    props = {},
    namespacesResponse = mockNamespacesResponse,
    renderListItems = false,
    groupLookupHandler = jest.fn().mockResolvedValue({ data: { group: null } }),
  } = {}) => {
    const apolloProvider = createMockApollo([
      [
        searchNamespacesWhereUserCanImportProjectsQuery,
        jest.fn().mockResolvedValue(namespacesResponse),
      ],
      [importTargetSyncAvailabilityQuery, groupLookupHandler],
    ]);

    const options = {
      apolloProvider,
      propsData: {
        ...defaultProps,
        ...props,
      },
    };

    wrapper = renderListItems
      ? mount(ImportTargetDropdown, {
          ...options,
          stubs: { GlCollapsibleListbox: ListboxRenderingItemsStub },
          directives: { GlTooltip: createMockDirective('gl-tooltip') },
        })
      : shallowMount(ImportTargetDropdown, options);
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findListboxGroupOptions = (title) =>
    findListbox()
      .props('items')
      .find((item) => item.text === title).options;
  const findListboxGroupsItems = () => findListboxGroupOptions('Groups');

  const waitForQuery = async () => {
    jest.advanceTimersByTime(DEBOUNCE_DELAY);
    await waitForPromises();
  };

  it('renders listbox', () => {
    createComponent();

    expect(findListbox().exists()).toBe(true);
  });

  it('truncates "toggle-text" when "selected" is too long', () => {
    const mockSelected = 'a-group-path-that-is-longer-than-24-characters';

    createComponent({
      props: { selected: mockSelected },
    });

    expect(findListbox().props('toggleText')).toBe('a-group-path-that-is-lo…');
  });

  describe('when used on group import', () => {
    beforeEach(() => {
      createComponent();
    });

    it('adds "No parent" in "Parent" group', () => {
      expect(findListboxGroupOptions('Parent')).toEqual([{ text: 'No parent', value: '' }]);
    });

    it('emits "select" event with { fullPath: "", id: null } when "No parent" is selected', () => {
      findListbox().vm.$emit('select', '');

      expect(wrapper.emitted('select')[0]).toEqual([{ fullPath: '', id: null }]);
    });

    it('emits "select" event with { fullPath, id } when a group is selected', async () => {
      await waitForQuery();

      const mockGroupPath = 'match1';

      findListbox().vm.$emit('select', mockGroupPath);

      expect(wrapper.emitted('select')[0]).toEqual([
        { fullPath: mockGroupPath, id: `gid://gitlab/Group/${mockGroupPath}` },
      ]);
    });
  });

  describe('when used on project import', () => {
    beforeEach(() => {
      createComponent({
        props: { userNamespace: mockUserNamespace },
      });
    });

    it('lists "Groups" above "Users"', () => {
      expect(
        findListbox()
          .props('items')
          .map(({ text }) => text),
      ).toEqual(['Groups', 'Users']);
    });

    it('passes userNamespace as "Users" group item', () => {
      expect(findListboxGroupOptions('Users')).toEqual([
        { text: mockUserNamespace, value: mockUserNamespace },
      ]);
    });

    it('emits "select" event with path as value', () => {
      const mockProjectPath = 'mock-project';

      findListbox().vm.$emit('select', mockProjectPath);

      expect(wrapper.emitted('select')[0]).toEqual([mockProjectPath]);
    });
  });

  it('passes namespaces from GraphQL as "Groups" group item', async () => {
    createComponent();

    await waitForQuery();

    expect(findListboxGroupsItems()).toEqual(
      mockAvailableNamespaces.map((namespace) => ({
        text: namespace.fullPath,
        value: namespace.fullPath,
      })),
    );
  });

  it('filters namespaces based on user input', async () => {
    createComponent();

    findListbox().vm.$emit('search', 'match');

    await waitForQuery();

    expect(findListboxGroupsItems()).toEqual([
      { text: 'match1', value: 'match1' },
      { text: 'match2', value: 'match2' },
    ]);
  });

  it('sorts namespaces based on similarity to input', async () => {
    createComponent();

    findListbox().vm.$emit('search', 'sortme');

    await waitForQuery();

    expect(findListboxGroupsItems()).toEqual([
      { text: 'sortme', value: 'sortme' },
      { text: 'sortmea', value: 'sortmea' },
      { text: 'sortmeaa', value: 'sortmeaa' },
      { text: 'sortmeab', value: 'sortmeab' },
    ]);
  });

  (IS_EE ? describe : describe.skip)('when continuousSyncRequired is set', () => {
    const syncBlockedGroup = mockGroupFactory('no-sync', false);
    const syncAllowedGroup = mockGroupFactory('sync-ok');
    const syncBlockedUserNamespace = {
      ...mockNamespacesResponse.data.currentUser.namespace,
      fullPath: mockUserNamespace,
      licensedFeatureAvailability: { available: false, __typename: 'LicensedFeatureAvailability' },
    };

    const createNamespacesResponse = ({ groups, namespace }) => ({
      data: {
        currentUser: {
          ...mockNamespacesResponse.data.currentUser,
          groups: { nodes: groups, __typename: 'GroupConnection' },
          namespace,
        },
      },
    });

    it('disables groups that cannot keep updates on', async () => {
      createComponent({
        props: { continuousSyncRequired: true, continuousSyncOffered: true },
        namespacesResponse: createNamespacesResponse({
          groups: [syncBlockedGroup, syncAllowedGroup],
          namespace: mockNamespacesResponse.data.currentUser.namespace,
        }),
      });

      await waitForQuery();

      expect(findListboxGroupsItems()).toEqual([
        { text: 'no-sync', value: 'no-sync', disabled: true },
        { text: 'sync-ok', value: 'sync-ok' },
      ]);
    });

    it('disables the user namespace when it cannot keep updates on', async () => {
      createComponent({
        props: {
          continuousSyncRequired: true,
          continuousSyncOffered: true,
          userNamespace: mockUserNamespace,
        },
        namespacesResponse: createNamespacesResponse({
          groups: [],
          namespace: syncBlockedUserNamespace,
        }),
      });

      await waitForQuery();

      expect(findListboxGroupOptions('Users')).toEqual([
        { text: mockUserNamespace, value: mockUserNamespace, disabled: true },
      ]);
    });

    it('emits "sync-blocked-change" with true when the selected namespace cannot keep updates on', async () => {
      createComponent({
        props: { continuousSyncRequired: true, continuousSyncOffered: true, selected: 'no-sync' },
        namespacesResponse: createNamespacesResponse({
          groups: [syncBlockedGroup],
          namespace: mockNamespacesResponse.data.currentUser.namespace,
        }),
      });

      await waitForQuery();

      expect(wrapper.emitted('sync-blocked-change').at(-1)).toEqual([true]);
    });

    it('flags the listbox toggle with the error border', async () => {
      createComponent({
        props: { continuousSyncRequired: true, continuousSyncOffered: true, selected: 'no-sync' },
        namespacesResponse: createNamespacesResponse({
          groups: [syncBlockedGroup],
          namespace: mockNamespacesResponse.data.currentUser.namespace,
        }),
      });

      await waitForQuery();

      expect(findListbox().props('toggleClass')).toEqual([
        '!gl-rounded-tr-none !gl-rounded-br-none',
        { '!gl-border-feedback-danger': true },
      ]);
    });

    it('reports the blocked selection when continuous sync is checked afterwards', async () => {
      createComponent({
        props: { selected: 'no-sync', continuousSyncOffered: true },
        namespacesResponse: createNamespacesResponse({
          groups: [syncBlockedGroup],
          namespace: mockNamespacesResponse.data.currentUser.namespace,
        }),
      });

      await waitForQuery();

      expect(wrapper.emitted('sync-blocked-change').at(-1)).toEqual([false]);

      await wrapper.setProps({ continuousSyncRequired: true });

      expect(wrapper.emitted('sync-blocked-change').at(-1)).toEqual([true]);
      expect(findListboxGroupsItems()).toEqual([
        { text: 'no-sync', value: 'no-sync', disabled: true },
      ]);
    });

    describe('when the selected group is not on the search page', () => {
      const selectedPath = 'lookup-group';
      const searchPageWithoutSelected = () =>
        createNamespacesResponse({
          groups: [syncAllowedGroup],
          namespace: mockNamespacesResponse.data.currentUser.namespace,
        });
      const lookupResponse = (group) => ({ data: { group } });
      const lookupGroup = (available) => ({
        id: 'gid://gitlab/Group/1',
        fullPath: selectedPath,
        licensedFeatureAvailability: {
          available,
          __typename: 'LicensedFeatureAvailability',
        },
        __typename: 'Group',
      });

      it('blocks the selected group when the lookup says it cannot keep updates on', async () => {
        createComponent({
          props: {
            continuousSyncRequired: true,
            continuousSyncOffered: true,
            selected: selectedPath,
          },
          namespacesResponse: searchPageWithoutSelected(),
          groupLookupHandler: jest.fn().mockResolvedValue(lookupResponse(lookupGroup(false))),
        });

        await waitForQuery();

        expect(wrapper.emitted('sync-blocked-change').at(-1)).toEqual([true]);
      });

      it('does not look up a group that the search page already returned', async () => {
        const groupLookupHandler = jest.fn().mockResolvedValue(lookupResponse(lookupGroup(false)));
        createComponent({
          props: { continuousSyncRequired: true, continuousSyncOffered: true, selected: 'no-sync' },
          namespacesResponse: createNamespacesResponse({
            groups: [syncBlockedGroup],
            namespace: mockNamespacesResponse.data.currentUser.namespace,
          }),
          groupLookupHandler,
        });

        await waitForQuery();

        expect(groupLookupHandler).not.toHaveBeenCalled();
      });

      it('leaves the selected group unblocked when the lookup returns no group', async () => {
        createComponent({
          props: {
            continuousSyncRequired: true,
            continuousSyncOffered: true,
            selected: selectedPath,
          },
          namespacesResponse: searchPageWithoutSelected(),
          groupLookupHandler: jest.fn().mockResolvedValue(lookupResponse(null)),
        });

        await waitForQuery();

        expect(wrapper.emitted('sync-blocked-change').at(-1)).toEqual([false]);
      });
    });
  });

  (IS_EE ? describe : describe.skip)('when listing namespaces that cannot keep updates on', () => {
    const syncBlockedText = 'Not available with updates on. Choose a Premium or Ultimate group.';

    beforeEach(async () => {
      createComponent({
        renderListItems: true,
        props: { continuousSyncRequired: true, continuousSyncOffered: true },
        namespacesResponse: {
          data: {
            currentUser: {
              ...mockNamespacesResponse.data.currentUser,
              groups: {
                nodes: [mockGroupFactory('no-sync', false), mockGroupFactory('sync-ok')],
                __typename: 'GroupConnection',
              },
            },
          },
        },
      });

      await waitForQuery();
    });

    // Blocked items also contain the screen-reader reason, so match on the name prefix
    const findItem = (name) =>
      wrapper.findAll('li').wrappers.find((li) => li.text().startsWith(name));

    it('shows the reason as a tooltip on a blocked item', () => {
      const blockedItem = findItem('no-sync');

      expect(getBinding(blockedItem.find('span').element, 'gl-tooltip').value).toBe(
        syncBlockedText,
      );
    });

    it('gives screen readers the reason on a blocked item', () => {
      expect(findItem('no-sync').find('.gl-sr-only').text()).toBe(syncBlockedText);
    });

    it('renders an allowed item as plain text, without tooltip or screen-reader text', () => {
      const allowedItem = findItem('sync-ok');

      expect(allowedItem.find('span').exists()).toBe(false);
      expect(allowedItem.find('.gl-sr-only').exists()).toBe(false);
    });
  });

  describe('when continuousSyncRequired is not set', () => {
    it('does not disable namespaces or report a blocked selection', async () => {
      createComponent({
        props: { selected: 'no-sync' },
        namespacesResponse: {
          data: {
            currentUser: {
              ...mockNamespacesResponse.data.currentUser,
              groups: {
                nodes: [mockGroupFactory('no-sync', false)],
                __typename: 'GroupConnection',
              },
            },
          },
        },
      });

      await waitForQuery();

      expect(findListboxGroupsItems()).toEqual([{ text: 'no-sync', value: 'no-sync' }]);
      expect(wrapper.emitted('sync-blocked-change').at(-1)).toEqual([false]);
    });
  });
});

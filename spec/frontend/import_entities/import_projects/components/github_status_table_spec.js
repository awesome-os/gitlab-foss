import { GlButton, GlLink, GlTabs, GlSearchBoxByClick } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';

import { stubComponent } from 'helpers/stub_component';
import GithubStatusTable from '~/import_entities/import_projects/components/github_status_table.vue';
import GithubOrganizationsBox from '~/import_entities/import_projects/components/github_organizations_box.vue';
import ImportProjectsTable from '~/import_entities/import_projects/components/import_projects_table.vue';
import initialState from '~/import_entities/import_projects/store/state';
import * as getters from '~/import_entities/import_projects/store/getters';

const createImportProjectsTableStub = (importAllDisabled) =>
  stubComponent(ImportProjectsTable, {
    importAllButtonText: 'IMPORT_ALL_TEXT',
    importAllDisabled,
    methods: {
      showImportAllModal: jest.fn(),
    },
    template:
      '<div><p><slot name="repositories-notice">Select the repositories you want to import</slot></p><slot name="filter" v-bind="{ importAllButtonText: $options.importAllButtonText, showImportAllModal, importAllDisabled: $options.importAllDisabled }"></slot></div>',
  });

Vue.use(Vuex);

describe('GithubStatusTable', () => {
  let wrapper;

  const setFilterAction = jest.fn().mockImplementation(({ state }, filter) => {
    state.filter = { ...state.filter, ...filter };
  });

  const findFilterField = () => wrapper.findComponent(GlSearchBoxByClick);
  const findImportAllButton = () =>
    wrapper
      .findAllComponents(GlButton)
      .wrappers.find((button) => button.text() === 'IMPORT_ALL_TEXT');
  const selectTab = (idx) => {
    wrapper.findComponent(GlTabs).vm.$emit('input', idx);
    return nextTick();
  };

  function createComponent({ importAllDisabled = false, propsData = {} } = {}) {
    const store = new Vuex.Store({
      state: { ...initialState() },
      getters,
      actions: {
        setFilter: setFilterAction,
      },
    });

    wrapper = mount(GithubStatusTable, {
      store,
      propsData: {
        providerTitle: 'Github',
        ...propsData,
      },
      stubs: {
        ImportProjectsTable: createImportProjectsTableStub(importAllDisabled),
        GithubOrganizationsBox: stubComponent(GithubOrganizationsBox),
        GlTabs: false,
        GlTab: false,
      },
    });
  }

  beforeEach(() => {
    createComponent();
  });

  it('renders import table component', () => {
    expect(wrapper.findComponent(ImportProjectsTable).exists()).toBe(true);
  });

  describe('when a GitHub login is passed', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          githubLogin: 'octocat',
          githubReauthorizePath: '/import/github/new?reauthorize=true',
        },
      });
    });

    it('shows the account in the same paragraph as the repository hint', () => {
      expect(wrapper.find('p').text().replace(/\s+/g, ' ')).toBe(
        'Select the repositories you want to import. Importing from GitHub as @octocat. Use a different GitHub account.',
      );
    });

    it('links to the reauthorize path', () => {
      expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
        '/import/github/new?reauthorize=true',
      );
    });
  });

  describe('when no GitHub login is passed', () => {
    it('does not show the account notice', () => {
      expect(wrapper.text()).not.toContain('Importing from GitHub as');
      expect(wrapper.findComponent(GlLink).exists()).toBe(false);
    });
  });

  it('enables the import all button when import all is not disabled', () => {
    expect(findImportAllButton().props('disabled')).toBe(false);
  });

  it('disables the import all button when import all is disabled', async () => {
    createComponent({ importAllDisabled: true });
    await nextTick();

    expect(findImportAllButton().props('disabled')).toBe(true);
  });

  it('sets relation_type filter to owned repositories by default', () => {
    expect(setFilterAction).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ relation_type: 'owned' }),
    );
  });

  it('updates relation_type and resets organization filter when tab is switched', async () => {
    const NEW_ACTIVE_TAB_IDX = 1;
    await selectTab(NEW_ACTIVE_TAB_IDX);

    expect(setFilterAction).toHaveBeenCalledTimes(2);
    expect(setFilterAction).toHaveBeenCalledWith(expect.anything(), {
      ...GithubStatusTable.relationTypes[NEW_ACTIVE_TAB_IDX].backendFilter,
      organization_login: '',
      filter: '',
    });
  });

  it('updates filter when search box is changed', async () => {
    const NEW_FILTER = 'test';
    findFilterField().vm.$emit('submit', NEW_FILTER);
    await nextTick();

    expect(setFilterAction).toHaveBeenCalledWith(expect.anything(), {
      filter: NEW_FILTER,
    });
  });

  describe('when "Organization" tab is selected', () => {
    beforeEach(async () => {
      const organizationTabIndex = GithubStatusTable.relationTypes.findIndex(
        (entry) => entry.showOrganizationFilter,
      );
      await selectTab(organizationTabIndex);
    });

    it('renders disabled name filter when organization is not set', () => {
      expect(findFilterField().props('disabled')).toBe(true);
    });

    it('enables name filter when organization is set', async () => {
      wrapper.findComponent(GithubOrganizationsBox).vm.$emit('input', 'some-org');
      await nextTick();

      expect(findFilterField().props('disabled')).toBe(false);
    });

    it('updates organization_login filter when GithubOrganizationsBox emits input', () => {
      const NEW_ORG = 'some-org';
      wrapper.findComponent(GithubOrganizationsBox).vm.$emit('input', NEW_ORG);

      expect(setFilterAction).toHaveBeenCalledWith(expect.anything(), {
        organization_login: NEW_ORG,
      });
    });
  });
});

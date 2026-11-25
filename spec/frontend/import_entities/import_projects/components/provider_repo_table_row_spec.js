import { GlBadge, GlButton, GlDisclosureDropdownItem, GlModal, GlPopover } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { STATUSES } from '~/import_entities/constants';
import ImportTargetDropdown from '~/import_entities/components/import_target_dropdown.vue';
import ImportStatus from '~/import_entities/components/import_status.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import ProviderRepoTableRow from '~/import_entities/import_projects/components/provider_repo_table_row.vue';

describe('ProviderRepoTableRow', () => {
  let wrapper;
  const fetchImport = jest.fn();
  const cancelImport = jest.fn();
  const setImportTarget = jest.fn();
  const groupImportTarget = {
    targetNamespace: 'target',
    newName: 'newName',
  };

  const userNamespace = 'root';
  const glSprintfStub = {
    name: 'GlSprintfStub',
    props: ['message'],
    render(createElement) {
      return createElement('span', this.$scopedSlots.link({ content: 'Learn more' }));
    },
  };

  function initStore({ importTarget = groupImportTarget } = {}) {
    const store = new Vuex.Store({
      state: {},
      getters: {
        getImportTarget: () => () => importTarget,
      },
      actions: { fetchImport, cancelImport, setImportTarget },
    });

    return store;
  }

  const findButton = (text) => {
    const buttons = wrapper.findAllComponents(GlButton).filter((node) => node.text() === text);

    return buttons.length ? buttons.at(0) : buttons;
  };

  const findImportButton = () => findButton('Import');
  const findReimportButton = () => findButton('Re-import');
  const findRowMenu = () => wrapper.findByTestId('repo-row-menu');
  const findReimportItem = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findImportTargetDropdown = () => wrapper.findComponent(ImportTargetDropdown);
  const findImportStatus = () => wrapper.findComponent(ImportStatus);
  const findProviderLink = () => wrapper.findByTestId('provider-link');
  const findMembershipsWarning = () => wrapper.findByTestId('memberships-warning');
  const findGlModal = () => wrapper.findComponent(GlModal);
  const findCancelImportPopover = () => wrapper.findComponent(GlPopover);

  const findCancelButton = () => {
    const buttons = wrapper
      .findAllComponents(GlButton)
      .filter((node) => node.attributes('aria-label') === 'Cancel');

    return buttons.length ? buttons.at(0) : buttons;
  };

  function mountComponent(props, { storeOptions = {}, stubs = {} } = {}) {
    Vue.use(Vuex);

    const store = initStore(storeOptions);

    wrapper = shallowMountExtended(ProviderRepoTableRow, {
      store,
      stubs,
      propsData: { optionalStages: {}, ...props },
      provide: {
        userNamespace,
      },
    });
  }

  describe('when rendering importable project', () => {
    const repo = {
      importSource: {
        id: 'remote-1',
        fullName: 'fullName',
        providerLink: 'providerLink',
      },
    };

    beforeEach(() => {
      mountComponent({ repo });
    });

    it('renders project information', () => {
      const providerLink = findProviderLink();

      expect(providerLink.attributes().href).toMatch(repo.importSource.providerLink);
      expect(providerLink.text()).toMatch(repo.importSource.fullName);
    });

    it('renders empty import status', () => {
      expect(findImportStatus().props().status).toBe(STATUSES.NONE);
    });

    it('renders a group namespace select', () => {
      expect(findImportTargetDropdown().exists()).toBe(true);
    });

    describe('when user namespace is selected as import target', () => {
      beforeEach(() => {
        mountComponent(
          { repo },
          { storeOptions: { importTarget: { targetNamespace: userNamespace } } },
        );
      });

      it('shows memberships warning', () => {
        expect(findMembershipsWarning().isVisible()).toBe(true);
      });

      it('shows modal with warning message when import button is clicked', async () => {
        findImportButton().vm.$emit('click');
        await nextTick();

        const modal = findGlModal();
        expect(modal.props('title')).toBe(
          'Are you sure you want to import the project to a personal namespace?',
        );
        expect(modal.text()).toContain(
          'When you import to a personal namespace, all contributions are assigned to the personal namespace owner and they cannot be reassigned. To map contributions to real users, import to a group instead.',
        );
      });

      it('triggers import when clicking modal primary button', async () => {
        findImportButton().vm.$emit('click');
        await nextTick();

        findGlModal().vm.$emit('primary');

        expect(fetchImport).toHaveBeenCalledWith(expect.anything(), {
          repoId: repo.importSource.id,
          optionalStages: {},
        });
      });
    });

    describe('when group namespace is selected as import target', () => {
      it('does not show memberships warning', () => {
        expect(findMembershipsWarning().isVisible()).toBe(false);
      });

      it('does not show modal when import button is clicked', async () => {
        findImportButton().vm.$emit('click');
        await nextTick();

        expect(findGlModal().exists()).toBe(false);
      });
    });

    it('renders import button', () => {
      expect(findImportButton().exists()).toBe(true);
    });

    it('imports repo when clicking import button', async () => {
      findImportButton().vm.$emit('click');

      await nextTick();

      expect(fetchImport).toHaveBeenCalledWith(expect.anything(), {
        repoId: repo.importSource.id,
        optionalStages: {},
      });
    });

    it('includes optionalStages to import', async () => {
      const OPTIONAL_STAGES = { stage1: true, stage2: false };

      mountComponent({
        repo,
        optionalStages: OPTIONAL_STAGES,
      });

      findImportButton().vm.$emit('click');

      await nextTick();

      expect(fetchImport).toHaveBeenCalledWith(expect.anything(), {
        repoId: repo.importSource.id,
        optionalStages: OPTIONAL_STAGES,
      });
    });

    it('does not render re-import button', () => {
      expect(findReimportButton().exists()).toBe(false);
    });
  });

  describe('when rendering importing project', () => {
    const repo = {
      importSource: {
        id: 'remote-1',
        fullName: 'fullName',
        providerLink: 'providerLink',
      },
      importedProject: {
        id: 1,
        fullPath: 'fullPath',
        importSource: 'importSource',
        importStatus: STATUSES.STARTED,
      },
    };

    describe('when cancelable is true', () => {
      beforeEach(() => {
        mountComponent({ repo, cancelable: true }, { stubs: { GlSprintf: glSprintfStub } });
      });

      it('shows cancel button', () => {
        expect(findCancelButton().isVisible()).toBe(true);
      });

      it('cancels import when clicking cancel button', async () => {
        findCancelButton().vm.$emit('click');

        await nextTick();

        expect(cancelImport).toHaveBeenCalledWith(expect.anything(), {
          repoId: repo.importSource.id,
        });
      });

      describe('cancel import popover', () => {
        it('targets the cancel button', () => {
          expect(findCancelImportPopover().props('target')()).toBe(findCancelButton().element);
        });

        it('opens on hover and keyboard focus', () => {
          expect(findCancelImportPopover().props('triggers')).toBe('hover focus');
        });

        it('renders the title and translated description with a link placeholder', () => {
          expect(findCancelImportPopover().props('title')).toBe('Cancel import');
          expect(
            findCancelImportPopover().findComponent({ name: 'GlSprintfStub' }).props('message'),
          ).toBe(
            'Imported files will be kept. You can import this repository again later. %{linkStart}Learn more%{linkEnd}.',
          );
        });

        it('renders a reachable link to the import documentation', () => {
          const link = findCancelImportPopover().findComponent(HelpPageLink);

          expect(link.props('href')).toBe('/user/project/import/github');
          expect(link.text()).toBe('Learn more');
        });
      });
    });

    describe('when cancelable is false', () => {
      beforeEach(() => {
        mountComponent({ repo, cancelable: false });
      });

      it('hides cancel button', () => {
        expect(findCancelButton().isVisible()).toBe(false);
      });
    });
  });

  describe('when rendering imported project', () => {
    const FAKE_STATS = {};

    const repo = {
      importSource: {
        id: 'remote-1',
        fullName: 'fullName',
        providerLink: 'providerLink',
      },
      importedProject: {
        id: 1,
        fullPath: 'fullPath',
        importSource: 'importSource',
        importStatus: STATUSES.FINISHED,
        stats: FAKE_STATS,
      },
    };

    beforeEach(() => {
      mountComponent({ repo });
    });

    it('renders project information', () => {
      const providerLink = findProviderLink();

      expect(providerLink.attributes().href).toMatch(repo.importSource.providerLink);
      expect(providerLink.text()).toMatch(repo.importSource.fullName);
    });

    it('links the GitLab column and the View project action to the project', () => {
      expect(wrapper.find('[data-testid="imported-project-link"]').attributes('href')).toBe(
        repo.importedProject.fullPath,
      );
      const viewProject = wrapper.find('[data-testid="go-to-project-link"]');

      expect(viewProject.text()).toBe('View project');
      expect(viewProject.attributes('href')).toBe(repo.importedProject.fullPath);
      expect(viewProject.attributes('target')).toBe('_blank');
    });

    it('renders the row menu with the re-import item and its help text', () => {
      expect(findRowMenu().exists()).toBe(true);
      expect(findReimportItem().text()).toContain(
        'Re-import creates a new project. It does not sync with the existing project.',
      );
    });

    it('does not render the help popover on the finished row', () => {
      const iconNames = wrapper.findAllComponents(HelpPopover).wrappers.map((c) => c.props('icon'));

      expect(iconNames).not.toContain('information-o');
    });

    it('does not render the "Last imported to" line', () => {
      expect(wrapper.text()).not.toContain('Last imported to');
    });

    it('renders proper import status', () => {
      expect(findImportStatus().props().status).toBe(repo.importedProject.importStatus);
    });

    it('does not render a namespace select', () => {
      expect(findImportTargetDropdown().exists()).toBe(false);
    });

    it('does not render import button', () => {
      expect(findImportButton().exists()).toBe(false);
    });

    it('renders namespace select and import button after choosing re-import', async () => {
      findReimportItem().vm.$emit('action');

      await nextTick();

      expect(findImportTargetDropdown().exists()).toBe(true);
      expect(findReimportButton().exists()).toBe(true);
    });

    it('imports repo when clicking re-import button', async () => {
      findReimportItem().vm.$emit('action');

      await nextTick();

      findReimportButton().vm.$emit('click');

      expect(fetchImport).toHaveBeenCalledWith(expect.anything(), {
        repoId: repo.importSource.id,
        optionalStages: {},
      });
    });

    it('passes props to import status component', () => {
      expect(findImportStatus().props()).toMatchObject({
        projectId: repo.importedProject.id,
        stats: FAKE_STATS,
      });
    });
  });

  describe('when rendering failed project', () => {
    const repo = {
      importSource: {
        id: 'remote-1',
        fullName: 'fullName',
        providerLink: 'providerLink',
      },
      importedProject: {
        id: 1,
        fullPath: 'fullPath',
        importSource: 'importSource',
        importStatus: STATUSES.FAILED,
      },
    };

    beforeEach(() => {
      mountComponent({ repo });
    });

    it('render import button', () => {
      expect(findImportButton().exists()).toBe(true);
    });
  });

  describe('when rendering incompatible project', () => {
    const repo = {
      importSource: {
        id: 'remote-1',
        fullName: 'fullName',
        providerLink: 'providerLink',
        incompatible: true,
      },
    };

    beforeEach(() => {
      mountComponent({ repo });
    });

    it('renders project information', () => {
      const providerLink = findProviderLink();

      expect(providerLink.attributes().href).toMatch(repo.importSource.providerLink);
      expect(providerLink.text()).toMatch(repo.importSource.fullName);
    });

    it('renders badge with error', () => {
      expect(wrapper.findComponent(GlBadge).text()).toBe('Incompatible project');
    });
  });

  describe('when continuous sync is offered', () => {
    const repo = {
      importSource: {
        id: 'remote-1',
        fullName: 'fullName',
        providerLink: 'providerLink',
      },
    };

    it('tells the namespace dropdown that sync is required when it is checked', () => {
      mountComponent({ repo, optionalStages: { continuous_sync: true } });

      expect(findImportTargetDropdown().props('continuousSyncRequired')).toBe(true);
    });

    it('does not require sync for a stage that is not offered', () => {
      mountComponent({ repo, optionalStages: { other_stage: true } });

      expect(findImportTargetDropdown().props('continuousSyncRequired')).toBe(false);
    });

    it('tells the namespace dropdown that sync is offered, even when unchecked', () => {
      mountComponent({ repo, optionalStages: { continuous_sync: false } });

      expect(findImportTargetDropdown().props('continuousSyncOffered')).toBe(true);
    });

    it('does not tell the namespace dropdown that sync is offered for a stage not offered', () => {
      mountComponent({ repo, optionalStages: { other_stage: true } });

      expect(findImportTargetDropdown().props('continuousSyncOffered')).toBe(false);
    });

    it('shows the error and disables import when the selected namespace cannot keep updates on', async () => {
      mountComponent({ repo, optionalStages: { continuous_sync: true } });

      findImportTargetDropdown().vm.$emit('sync-blocked-change', true);
      await nextTick();

      expect(wrapper.findByTestId('sync-blocked-message').exists()).toBe(true);
      expect(findImportButton().props('disabled')).toBe(true);
      expect(wrapper.emitted('sync-blocked-change')).toEqual([[true]]);
    });

    it('announces the blocked message politely through a live region that exists before the message', async () => {
      mountComponent({ repo, optionalStages: { continuous_sync: true } });
      const liveRegion = () => wrapper.find('[aria-live="polite"]');

      expect(liveRegion().exists()).toBe(true);
      expect(liveRegion().text()).toBe('');

      findImportTargetDropdown().vm.$emit('sync-blocked-change', true);
      await nextTick();

      expect(liveRegion().text()).toBe(
        'Not available with updates on. Choose a Premium or Ultimate group.',
      );
    });

    it('clears the error and re-enables import when the namespace is allowed again', async () => {
      mountComponent({ repo, optionalStages: { continuous_sync: true } });

      findImportTargetDropdown().vm.$emit('sync-blocked-change', true);
      findImportTargetDropdown().vm.$emit('sync-blocked-change', false);
      await nextTick();

      expect(wrapper.findByTestId('sync-blocked-message').exists()).toBe(false);
      expect(findImportButton().props('disabled')).toBe(false);
    });

    it('never shows the error for a provider without the sync stage', async () => {
      mountComponent({ repo, optionalStages: {} });

      findImportTargetDropdown().vm.$emit('sync-blocked-change', false);
      await nextTick();

      expect(wrapper.findByTestId('sync-blocked-message').exists()).toBe(false);
      expect(findImportButton().props('disabled')).toBe(false);
    });
  });
});

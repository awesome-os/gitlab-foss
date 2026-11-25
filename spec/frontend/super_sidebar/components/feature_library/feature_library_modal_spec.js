import MockAdapter from 'axios-mock-adapter';
import { GlModal, GlSearchBoxByType, GlCollapse, GlEmptyState } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import axios from '~/lib/utils/axios_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  HTTP_STATUS_OK,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_TOO_MANY_REQUESTS,
} from '~/lib/utils/http_status';
import ScrollScrim from '~/vue_shared/components/scroll_scrim/scroll_scrim.vue';
import FeatureLibraryModal from '~/super_sidebar/components/feature_library/feature_library_modal.vue';
import FeatureLibraryItem from '~/super_sidebar/components/feature_library/feature_library_item.vue';
import FeatureLibraryExplorePageButton from '~/super_sidebar/components/feature_library/feature_library_explore_page_button.vue';
import FeatureLibraryExplorePage from '~/super_sidebar/components/feature_library/feature_library_explore_page.vue';
import FeatureLibraryUpgradeCta from 'ee_else_ce/super_sidebar/components/feature_library/feature_library_upgrade_cta.vue';
import {
  EVENT_OPEN_FEATURE_LIBRARY_MODAL,
  EVENT_SEARCH_FEATURES_IN_FEATURE_LIBRARY_MODAL,
  EVENT_CLICK_CATEGORY_FILTER_IN_FEATURE_LIBRARY_MODAL,
  EVENT_PIN_ITEM_IN_FEATURE_LIBRARY_MODAL,
  EVENT_UNPIN_ITEM_IN_FEATURE_LIBRARY_MODAL,
  EVENT_NAVIGATE_TO_FEATURE_FROM_FEATURE_LIBRARY_MODAL,
} from '~/super_sidebar/tracking_constants';
import { HIDDEN_NAV_ITEM_CLASS } from '~/super_sidebar/constants';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));
jest.mock('~/lib/utils/path_helpers/feature_library', () => ({
  onboardingFeatureLibrarySearchPath: () => '/-/onboarding/feature_library/search',
  onboardingFeatureLibraryCatalogPath: () => '/-/onboarding/feature_library/catalog',
}));

const SEARCH_URL = '/-/onboarding/feature_library/search';
const CATALOG_URL = '/-/onboarding/feature_library/catalog';

// Mirrors the nav tree shape passed down from sidebar_menu.vue: sections (menu
// groups) holding leaf nav items enriched with feature-library metadata.
const defaultSections = [
  {
    id: 'plan_menu',
    title: 'Plan',
    items: [
      {
        id: 'project_issue_list',
        title: 'Work items',
        description: 'Track tasks and issues',
        library_icon: 'issues',
      },
      {
        id: 'boards',
        title: 'Boards',
        description: 'Visualize work with boards',
        library_icon: 'list-numbered',
        link: '/group/project/-/boards',
      },
      {
        id: 'milestones',
        title: 'Milestones',
        description: 'Manage project milestones',
        library_icon: 'milestone',
      },
    ],
  },
  {
    id: 'code_menu',
    title: 'Code',
    items: [
      {
        id: 'repository',
        title: 'Repository',
        description: 'Browse and manage your code',
        library_icon: 'code',
        tier: 'free',
      },
    ],
  },
  {
    id: 'manage_menu',
    title: 'Manage',
    items: [
      {
        id: 'members',
        title: 'Members',
        description: 'Manage project members',
        library_icon: 'users',
        link: '/group/project/-/project_members',
      },
    ],
  },
  {
    id: 'settings_menu',
    title: 'Settings',
    items: [
      {
        id: 'general_settings',
        title: 'General',
      },
    ],
  },
];

describe('FeatureLibraryModal', () => {
  let wrapper;
  let mockAxios;

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  const hideModal = jest.fn();
  const focusInput = jest.fn();
  const focusItem = jest.fn();

  const createWrapper = ({
    currentPinnedIds = [],
    panelType = 'project',
    sections = defaultSections,
    resourceId = null,
    supportsPins,
    explorePagesAvailable = false,
    attachTo,
  } = {}) => {
    wrapper = shallowMountExtended(FeatureLibraryModal, {
      propsData: { sections, currentPinnedIds, supportsPins },
      provide: { panelType, resourceId, explorePagesAvailable },
      attachTo,
      // Stub GlModal: declared props stay props, everything else surfaces as attrs.
      stubs: {
        GlModal: stubComponent(GlModal, { methods: { hide: hideModal } }),
        GlSearchBoxByType: stubComponent(GlSearchBoxByType, { methods: { focusInput } }),
        // Render collapse slot content so grouped items are inspectable.
        GlCollapse: stubComponent(GlCollapse, {
          template: '<div v-if="visible"><slot></slot></div>',
          props: ['visible'],
        }),
        FeatureLibraryItem: stubComponent(FeatureLibraryItem, { methods: { focus: focusItem } }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findSearch = () => wrapper.findComponent(GlSearchBoxByType);
  const findSectionToggles = () =>
    wrapper.findAllComponentsByTestId('feature-library-section-toggle');
  const findSectionTitles = () => findSectionToggles().wrappers.map((w) => w.text());
  const findCollapses = () => wrapper.findAllComponents(GlCollapse);
  const findItems = () => wrapper.findAllComponents(FeatureLibraryItem);
  const findItemIds = () => findItems().wrappers.map((w) => w.props('item').id);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findLoadingIcon = () => wrapper.findByTestId('search-loading');
  const findScrollArea = () => wrapper.findByTestId('feature-library-scroll-area');
  const findGrid = () => wrapper.findByTestId('feature-library-grid');
  const findSectionGrid = () => wrapper.findByTestId('feature-library-section-grid');
  const findCategoryFilters = () =>
    wrapper.findAllComponentsByTestId('feature-library-category-filter');
  const findCategoryFilterLabels = () => findCategoryFilters().wrappers.map((w) => w.text());
  const selectCategory = async (label) => {
    const button = findCategoryFilters().wrappers.find((w) => w.text() === label);
    await button.vm.$emit('click');
  };
  const findSearchStatusRegion = () => wrapper.findByTestId('search-status-region');

  const emitSearch = async (query) => {
    await findSearch().vm.$emit('input', query);
  };

  const mockSearch = (response = { ids: [] }) =>
    mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, response);

  describe('rendering', () => {
    beforeEach(() => createWrapper());

    it('renders one section heading per section that has enriched items', () => {
      expect(findSectionTitles()).toEqual(['Plan', 'Code', 'Manage']);
    });

    it('excludes settings menus', () => {
      expect(findSectionTitles()).not.toContain('Settings');
    });

    it('wraps content in a scroll-scrim area so overflow fades at the edges', () => {
      expect(findScrollArea().exists()).toBe(true);
      expect(wrapper.findComponent(ScrollScrim).exists()).toBe(true);
    });

    it('renders a search input', () => {
      expect(findSearch().exists()).toBe(true);
    });

    it('names the modal "Feature catalog"', () => {
      expect(findModal().props('ariaLabel')).toBe('Feature catalog');
    });

    it.each([
      ['project', 'Search features in this project'],
      ['group', 'Search features in this group'],
      ['your_work', 'Search GitLab features'],
    ])('uses a %s-specific search placeholder', (panelType, expected) => {
      createWrapper({ panelType });
      expect(findSearch().attributes('placeholder')).toBe(expected);
    });

    it('debounces search input using the shared default interval', () => {
      expect(Number(findSearch().attributes('debounce'))).toBe(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    });

    it('does not show a loading indicator by default', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('hidden nav items', () => {
    beforeEach(() => {
      createWrapper({
        sections: [
          {
            id: 'plan_menu',
            title: 'Plan',
            items: [
              {
                id: 'issue_list',
                title: 'Work items',
                description: 'Plan, track, and manage work in one place',
                library_icon: 'work-items',
              },
              {
                id: 'group_epic_list',
                title: 'Work items',
                description: 'Break down large initiatives into smaller, manageable work items',
                library_icon: 'epic',
                tier: 'premium',
                link_classes: HIDDEN_NAV_ITEM_CLASS,
              },
            ],
          },
        ],
      });
    });

    it('excludes items hidden in the super sidebar', () => {
      expect(findItemIds()).toEqual(['issue_list']);
    });
  });

  describe('modal layout', () => {
    describe('with default props', () => {
      beforeEach(() => createWrapper());

      it('does not use centered so the top edge stays anchored during search', () => {
        expect(findModal().attributes('centered')).toBeUndefined();
      });

      it('applies the feature-library-modal class for top-anchored positioning', () => {
        expect(findModal().props('modalClass')).toContain('feature-library-modal');
      });

      it('hides the footer', () => {
        expect(findModal().attributes('hide-footer')).toBeDefined();
      });

      it('removes the modal body bottom padding', () => {
        expect(findModal().vm.$attrs['body-class']).toContain('!gl-pb-0');
      });
    });
  });

  describe('catalog', () => {
    beforeEach(() => createWrapper());

    it('lists nav items', () => {
      const ids = findItems().wrappers.map((w) => w.props('item').id);
      expect(ids.sort()).toEqual([
        'boards',
        'members',
        'milestones',
        'project_issue_list',
        'repository',
      ]);
    });

    it('maps library_icon onto the item icon', () => {
      const repository = findItems().wrappers.find((w) => w.props('item').id === 'repository');
      expect(repository.props('item').icon).toBe('code');
    });

    it('maps tier_gated onto the item tierGated', () => {
      createWrapper({
        sections: [
          {
            id: 'plan_menu',
            title: 'Plan',
            items: [{ id: 'iterations', title: 'Iterations', tier: 'premium', tier_gated: false }],
          },
        ],
      });

      expect(findItems().at(0).props('item')).toMatchObject({ tier: 'premium', tierGated: false });
    });

    it('tags each item with the id of its parent section as its category', () => {
      const items = findItems().wrappers.map((w) => w.props('item'));
      expect(items.filter((i) => i.category === 'plan_menu').map((i) => i.id)).toEqual([
        'project_issue_list',
        'boards',
        'milestones',
      ]);
      expect(items.filter((i) => i.category === 'code_menu').map((i) => i.id)).toEqual([
        'repository',
      ]);
    });
  });

  describe('grouping when browsing', () => {
    beforeEach(() => createWrapper());

    it('groups items into a section per category, each under its own heading', () => {
      expect(findSectionTitles()).toEqual(['Plan', 'Code', 'Manage']);
    });

    it('renders each group as a collapsible section, expanded by default', () => {
      const collapses = findCollapses();
      expect(collapses).toHaveLength(3);
      collapses.wrappers.forEach((collapse) => {
        expect(collapse.props('visible')).toBe(true);
      });
    });

    it('collapses a section when its toggle is clicked', async () => {
      await findSectionToggles().at(0).vm.$emit('click');

      expect(findCollapses().at(0).props('visible')).toBe(false);
      // Other sections stay expanded.
      expect(findCollapses().at(1).props('visible')).toBe(true);
    });

    it('re-expands a collapsed section when its toggle is clicked again', async () => {
      await findSectionToggles().at(0).vm.$emit('click');
      await findSectionToggles().at(0).vm.$emit('click');

      expect(findCollapses().at(0).props('visible')).toBe(true);
    });

    it('renders each section’s items in order, grouped under its heading', () => {
      // Sections render in catalog order (Plan, then Code), so the flattened
      // item order reflects the per-section grouping.
      expect(findItemIds()).toEqual([
        'project_issue_list',
        'boards',
        'milestones',
        'repository',
        'members',
      ]);
    });

    it('wires each toggle to its collapse via aria-controls and a matching id', () => {
      const toggle = findSectionToggles().at(0);
      const collapse = findCollapses().at(0);
      const controls = toggle.attributes('aria-controls');

      expect(controls).toBe('feature-library-section-plan_menu');
      expect(collapse.attributes('id')).toBe(controls);
    });
  });

  describe('feature discovery search', () => {
    describe('title/description matching (client-side, instant)', () => {
      beforeEach(() => createWrapper());

      it('keeps title/description matches visible without a loading indicator while the endpoint is in flight', async () => {
        mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
        await emitSearch('repo');

        expect(findGrid().exists()).toBe(true);
        expect(findItemIds()).toEqual(['repository']);
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('does not flash the grouped browsing view while the endpoint is in flight', async () => {
        // 'sprint' matches no title or description, so nothing but the
        // loading indicator should show while the endpoint is in flight.
        mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
        await emitSearch('sprint');

        expect(findSectionToggles()).toHaveLength(0);
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('marks the search box as loading while the endpoint is in flight', async () => {
        mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
        await emitSearch('repo');

        expect(findSearch().props('isLoading')).toBe(true);
      });

      it('adds endpoint synonym results to the visible list once the endpoint resolves', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards'] });
        await emitSearch('repo');
        await waitForPromises();

        expect(findGrid().exists()).toBe(true);
        expect(findItemIds()).toContain('repository');
        expect(findItemIds()).toContain('boards');
      });

      it('renders results as one flat, ungrouped list rather than collapsible sections', async () => {
        // Search deliberately drops the category grouping: matches are ranked
        // across the whole catalog, so section headings would be noise.
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards'] });
        await emitSearch('repo');
        await waitForPromises();

        expect(findGrid().exists()).toBe(true);
        expect(findSectionGrid().exists()).toBe(false);
        expect(findSectionToggles()).toHaveLength(0);
        expect(findCollapses()).toHaveLength(0);
      });

      it('shows a loading indicator only while nothing is visible, hiding it once the endpoint resolves', async () => {
        // 'sprint' matches no title or description, so there is nothing to
        // show until the endpoint returns its synonym matches.
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards'] });
        await emitSearch('sprint');
        expect(findLoadingIcon().exists()).toBe(true);

        await waitForPromises();
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findItemIds()).toEqual(['boards']);
      });

      // Ranking and sort order are unit-tested in search_spec.js. These two
      // cover the component's integration with the util via the real endpoint.
      it('ranks a title match above a synonym-only match from the endpoint', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards', 'repository'] });
        await emitSearch('repo');
        await waitForPromises();

        expect(findItemIds()).toEqual(['repository', 'boards']);
      });

      it('ranks a title match above a description-only match', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
        await emitSearch('work');
        await waitForPromises();

        expect(findItemIds()).toEqual(['project_issue_list', 'boards']);
      });

      it('does not duplicate items that match both title and endpoint', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['repository'] });
        await emitSearch('repo');
        await waitForPromises();

        expect(findItemIds().filter((id) => id === 'repository')).toHaveLength(1);
      });

      it('works on non-endpoint panels (e.g. organization) via title/description only', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
        createWrapper({ panelType: 'organization' });
        await emitSearch('repo');
        await waitForPromises();

        expect(findItemIds()).toEqual(['repository']);
      });
    });

    describe('endpoint synonym matching', () => {
      beforeEach(() => createWrapper());

      it('does not call the endpoint for queries shorter than 2 characters', async () => {
        await emitSearch('r');
        await waitForPromises();

        expect(mockAxios.history.get).toHaveLength(0);
      });

      it('sends the trimmed query and panel type as request params', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
        await emitSearch('  repo  ');
        await waitForPromises();

        expect(mockAxios.history.get).toHaveLength(1);
        expect(mockAxios.history.get[0].params).toEqual({ query: 'repo', panel: 'project' });
      });

      it('appends synonym-only results after title matches resolve', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards'] });
        await emitSearch('sprint');
        await waitForPromises();

        expect(findItemIds()).toContain('boards');
      });

      it('passes the endpoint order through to synonym-only results', async () => {
        mockAxios
          .onGet(SEARCH_URL)
          .reply(HTTP_STATUS_OK, { ids: ['project_issue_list', 'boards'] });
        await emitSearch('sprint');
        await waitForPromises();

        expect(findItemIds()).toEqual(['project_issue_list', 'boards']);
      });

      it('silently drops endpoint ids that have no catalog entry', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['nonexistent_id', 'boards'] });
        await emitSearch('sprint');
        await waitForPromises();

        expect(findItemIds()).not.toContain('nonexistent_id');
        expect(findItemIds()).toContain('boards');
      });

      it('treats a response with no ids field as no synonym matches', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, {});
        await emitSearch('repo');
        await waitForPromises();

        expect(findItemIds()).toEqual(['repository']);
      });

      it('on rate limit (429), falls back to title-only without reporting to Sentry', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_TOO_MANY_REQUESTS);
        await emitSearch('repo');
        await waitForPromises();

        expect(Sentry.captureException).not.toHaveBeenCalled();
        expect(findItemIds()).toEqual(['repository']);
      });

      it('on error, reports to Sentry and falls back to title-only results', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        await emitSearch('repo');
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error), {
          tags: { feature_category: 'onboarding' },
        });
        expect(findItemIds()).toEqual(['repository']);
      });

      describe('previous results while a new query is in flight', () => {
        it('keeps them visible instead of flashing to a loading state', async () => {
          mockAxios
            .onGet(SEARCH_URL)
            .replyOnce(HTTP_STATUS_OK, { ids: ['boards'] })
            .onGet(SEARCH_URL)
            .replyOnce(() => new Promise(() => {}));

          await emitSearch('sprint');
          await waitForPromises();

          expect(findItemIds()).toEqual(['boards']);

          await emitSearch('repo');

          expect(findGrid().exists()).toBe(true);
          expect(findItemIds()).toEqual(['repository', 'boards']);
          expect(findLoadingIcon().exists()).toBe(false);
        });

        it('replaces kept synonym results once the new response lands', async () => {
          mockAxios
            .onGet(SEARCH_URL)
            .replyOnce(HTTP_STATUS_OK, { ids: ['boards'] })
            .onGet(SEARCH_URL)
            .replyOnce(HTTP_STATUS_OK, { ids: ['members'] });

          await emitSearch('sprint');
          await waitForPromises();

          await emitSearch('iteration');
          await waitForPromises();

          expect(findItemIds()).toEqual(['members']);
        });

        it('drops synonym results when the query falls below the minimum length', async () => {
          mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards'] });
          await emitSearch('sprint');
          await waitForPromises();

          expect(findItemIds()).toEqual(['boards']);

          await emitSearch('q');

          expect(findItems()).toHaveLength(0);
          expect(findGrid().exists()).toBe(false);
        });
      });

      describe('stale response guard', () => {
        it('ignores endpoint results from a superseded query', async () => {
          let resolveFirst;
          mockAxios
            .onGet(SEARCH_URL)
            .replyOnce(
              () =>
                new Promise((resolve) => {
                  resolveFirst = resolve;
                }),
            )
            .onGet(SEARCH_URL)
            .replyOnce(HTTP_STATUS_OK, { ids: ['boards'] });

          await emitSearch('wo');
          await emitSearch('repository');
          await waitForPromises();

          resolveFirst([HTTP_STATUS_OK, { ids: ['project_issue_list'] }]);
          await waitForPromises();

          expect(findItemIds()).not.toContain('project_issue_list');
        });
      });
    });

    describe('empty state', () => {
      beforeEach(() => createWrapper());

      it('shows empty state when neither title nor endpoint matches anything', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
        await emitSearch('zzznomatch');
        await waitForPromises();

        expect(findItems()).toHaveLength(0);
        expect(findEmptyState().exists()).toBe(true);
      });

      it('does not show empty state while the endpoint is still in flight (title results visible)', async () => {
        mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
        await emitSearch('repo');

        expect(findEmptyState().exists()).toBe(false);
      });

      it('does not show empty state when query is less than 2 characters', async () => {
        await emitSearch('r');
        expect(findEmptyState().exists()).toBe(false);
      });

      it('uses the generic no-results title', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
        await emitSearch('zzznomatch');
        await waitForPromises();

        expect(findEmptyState().props('title')).toBe('No features match your search');
      });
    });

    describe('clearing search', () => {
      beforeEach(() => createWrapper());

      it('hides the loading indicator when the box is cleared mid-flight', async () => {
        mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
        await emitSearch('sprint');
        expect(findLoadingIcon().exists()).toBe(true);

        await emitSearch('');
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('restores the full catalog when the query is cleared', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['repository'] });
        await emitSearch('repo');
        await waitForPromises();

        await emitSearch('');
        await waitForPromises();

        expect(findItemIds().sort()).toEqual([
          'boards',
          'members',
          'milestones',
          'project_issue_list',
          'repository',
        ]);
      });
    });

    describe('on modal hide', () => {
      beforeEach(() => createWrapper());

      it('resets search and endpoint state so reopening shows the full catalog', async () => {
        mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['boards'] });
        await emitSearch('sprint');
        await waitForPromises();

        findModal().vm.$emit('hidden');
        await nextTick();

        expect(findSearch().props('value')).toBe('');
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findItemIds().sort()).toEqual([
          'boards',
          'members',
          'milestones',
          'project_issue_list',
          'repository',
        ]);
      });

      it('re-expands any collapsed sections so reopening shows them expanded', async () => {
        await findSectionToggles().at(0).vm.$emit('click');
        expect(findCollapses().at(0).props('visible')).toBe(false);

        findModal().vm.$emit('hidden');
        await nextTick();

        findCollapses().wrappers.forEach((collapse) => {
          expect(collapse.props('visible')).toBe(true);
        });
      });
    });
  });

  describe('progressive reveal', () => {
    const largeSections = [
      {
        id: 'plan_menu',
        title: 'Plan',
        items: Array.from({ length: 25 }, (_, i) => ({
          id: `plan_item_${i}`,
          title: `Plan item ${i}`,
          description: `Description ${i}`,
          library_icon: 'issues',
        })),
      },
      {
        id: 'code_menu',
        title: 'Code',
        items: Array.from({ length: 15 }, (_, i) => ({
          id: `code_item_${i}`,
          title: `Code item ${i}`,
          description: `Description ${i}`,
          library_icon: 'code',
        })),
      },
    ];

    beforeEach(() => {
      jest.spyOn(window, 'requestAnimationFrame').mockImplementation((cb) => {
        cb();
        return 1;
      });
      createWrapper({ sections: largeSections });
    });

    it('only mounts the first chunk of the catalog synchronously', () => {
      expect(findItems()).toHaveLength(18);
    });

    it('reveals the full catalog once the modal starts opening', async () => {
      findModal().vm.$emit('show');
      await nextTick();
      expect(findItems()).toHaveLength(40);
    });

    it('does not start the reveal when the opening transition ends', async () => {
      findModal().vm.$emit('shown');
      await nextTick();
      expect(findItems()).toHaveLength(18);
    });

    it('resets to the first chunk when the modal is hidden, so reopening stays fast', async () => {
      findModal().vm.$emit('show');
      await nextTick();
      findModal().vm.$emit('hidden');
      await nextTick();
      expect(findItems()).toHaveLength(18);
    });

    it('shows all search matches even before the reveal has run', async () => {
      mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
      await emitSearch('Plan item');
      await waitForPromises();
      expect(findItems()).toHaveLength(25);
    });

    describe('frame by frame', () => {
      let nextFrameId;
      let frames;
      const runFrame = async () => {
        const pending = [...frames.values()];
        frames.clear();
        pending.forEach((cb) => cb());
        await nextTick();
      };

      beforeEach(() => {
        nextFrameId = 0;
        frames = new Map();
        window.requestAnimationFrame.mockImplementation((cb) => {
          nextFrameId += 1;
          frames.set(nextFrameId, cb);
          return nextFrameId;
        });
        jest.spyOn(window, 'cancelAnimationFrame').mockImplementation((id) => frames.delete(id));
      });

      it('keeps the first painted frame to the first chunk, then adds a chunk per frame', async () => {
        findModal().vm.$emit('show');
        await nextTick();
        expect(findItems()).toHaveLength(18);

        await runFrame();
        expect(findItems()).toHaveLength(18);

        await runFrame();
        expect(findItems()).toHaveLength(36);

        await runFrame();
        expect(findItems()).toHaveLength(40);
      });

      it('stops the reveal when the modal hides before the deferred frame runs', async () => {
        findModal().vm.$emit('show');
        findModal().vm.$emit('hidden');
        await runFrame();
        await runFrame();

        expect(findItems()).toHaveLength(18);
      });

      it('runs a single reveal when show is emitted twice', async () => {
        findModal().vm.$emit('show');
        findModal().vm.$emit('show');
        await nextTick();

        await runFrame();
        expect(findItems()).toHaveLength(18);

        await runFrame();
        expect(findItems()).toHaveLength(36);
      });
    });

    it('renders every section heading even when the first section exceeds the reveal budget', () => {
      // The first section (25 items) alone exceeds the initial 18-item budget,
      // but both section headings must still be present so collapsing the
      // first section immediately surfaces the second.
      expect(findSectionTitles()).toEqual(['Plan', 'Code']);
    });
  });

  describe('keyboard-first navigation', () => {
    describe('when the modal is shown', () => {
      beforeEach(() => {
        createWrapper();
        findModal().vm.$emit('shown');
      });

      it('focuses the search box', () => {
        expect(focusInput).toHaveBeenCalled();
      });
    });

    describe('search input description', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('links the search input to an sr-only hint teaching the focus keys', () => {
        const describedBy = findSearch().attributes('aria-describedby');
        const hint = wrapper.find(`#${describedBy}`);

        expect(hint.classes()).toContain('gl-sr-only');
        expect(hint.text()).toBe(
          'Press Enter or the down arrow key to move to the first search result.',
        );
      });
    });

    describe.each(['Enter', 'ArrowDown'])('via the %s key', (key) => {
      const pressKey = () => {
        const event = new KeyboardEvent('keydown', { key, cancelable: true });
        findSearch().vm.$emit('keydown', event);
        return event;
      };

      describe('when a query has results', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
          createWrapper();
          await emitSearch('board');
          await waitForPromises();
        });

        it('focuses the first displayed result, without navigating or closing the modal', () => {
          const event = pressKey();

          // Assert identity, not just that some item was focused: focusItem is
          // one shared mock across every stubbed item, and $refs.searchResultItems[0]
          // (Vue 2 v-for ref array registration order) isn't guaranteed to track
          // the current filteredItems order, so this also guards the ref-ordering fix.
          expect(focusItem).toHaveBeenCalled();
          expect(focusItem.mock.contexts[0].item.id).toBe('boards');
          expect(event.defaultPrevented).toBe(true);
          expect(visitUrl).not.toHaveBeenCalled();
          expect(hideModal).not.toHaveBeenCalled();
        });
      });

      describe('when the modal is closed and reopened with a stale query', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
          createWrapper();
          await emitSearch('board');
          await waitForPromises();

          findModal().vm.$emit('hidden');
          findModal().vm.$emit('shown');
        });

        it('does not focus a result', () => {
          pressKey();

          expect(focusItem).not.toHaveBeenCalled();
        });
      });

      describe('when synonym matches exist', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: ['members'] });
          createWrapper();
          await emitSearch('sprint');
          await waitForPromises();
        });

        it('focuses the first displayed result', () => {
          pressKey();

          expect(focusItem).toHaveBeenCalled();
          expect(focusItem.mock.contexts[0].item.id).toBe('members');
        });
      });

      describe('when the query is empty', () => {
        beforeEach(() => {
          createWrapper();
        });

        it('does nothing, leaving the default key behavior intact', () => {
          const event = pressKey();

          expect(focusItem).not.toHaveBeenCalled();
          expect(event.defaultPrevented).toBe(false);
        });
      });

      describe('while the search endpoint is in flight with visible title matches', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
          createWrapper();
          await emitSearch('board');
        });

        it('focuses the first visible result', () => {
          const event = pressKey();

          expect(focusItem).toHaveBeenCalled();
          expect(focusItem.mock.contexts[0].item.id).toBe('boards');
          expect(event.defaultPrevented).toBe(true);
        });
      });

      describe('while the search endpoint is in flight with nothing visible yet', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
          createWrapper();
          // 'sprint' matches no title or description, so nothing renders
          // until the endpoint resolves.
          await emitSearch('sprint');
        });

        it('does nothing, leaving the default key behavior intact', () => {
          const event = pressKey();

          expect(focusItem).not.toHaveBeenCalled();
          expect(event.defaultPrevented).toBe(false);
        });
      });

      describe('when there are no results', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
          createWrapper();
          await emitSearch('nonexistent feature');
          await waitForPromises();
        });

        it('does nothing, leaving the default key behavior intact', () => {
          const event = pressKey();

          expect(focusItem).not.toHaveBeenCalled();
          expect(event.defaultPrevented).toBe(false);
        });
      });

      describe('when the first displayed result has no link', () => {
        beforeEach(async () => {
          mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
          createWrapper();
          // 'milestones' has no link in defaultSections and is the only match.
          await emitSearch('milestones');
          await waitForPromises();
        });

        it('delegates to focus(), which intentionally no-ops for link-less items, rather than navigating', () => {
          // The no-op here is intentional: a link-less item isn't navigable, so
          // there's nothing to focus into for that row. The modal itself
          // doesn't special-case this — FeatureLibraryItem#focus() is a no-op
          // when there's no title link to focus (see feature_library_item_spec.js).
          pressKey();

          expect(focusItem).toHaveBeenCalled();
          expect(visitUrl).not.toHaveBeenCalled();
          expect(hideModal).not.toHaveBeenCalled();
        });
      });
    });

    describe('when a kept result holds focus while a new query is in flight', () => {
      // 'sprint' has no title/description match, so 'boards' is on screen only
      // because of the endpoint; the follow-up query keeps it visible until its
      // own response lands.
      const focusKeptResult = async (secondResponse) => {
        mockAxios
          .onGet(SEARCH_URL)
          .replyOnce(HTTP_STATUS_OK, { ids: ['boards'] })
          .onGet(SEARCH_URL)
          .replyOnce(HTTP_STATUS_OK, secondResponse);
        createWrapper();
        await emitSearch('sprint');
        await waitForPromises();

        await emitSearch('zzz');
        jest.spyOn(document, 'activeElement', 'get').mockReturnValue(findItems().at(0).element);
        await waitForPromises();
      };

      it('returns focus to the search input when the response drops the focused result', async () => {
        await focusKeptResult({ ids: [] });

        expect(findItems()).toHaveLength(0);
        expect(focusInput).toHaveBeenCalled();
      });

      it('leaves focus alone when the response keeps the focused result', async () => {
        await focusKeptResult({ ids: ['boards'] });

        expect(findItemIds()).toEqual(['boards']);
        expect(focusInput).not.toHaveBeenCalled();
      });
    });
  });

  describe('search status live region', () => {
    it('renders as a polite, atomic status region that is empty while browsing', () => {
      createWrapper();

      expect(findSearchStatusRegion().attributes('aria-live')).toBe('polite');
      expect(findSearchStatusRegion().attributes('aria-atomic')).toBe('true');
      expect(findSearchStatusRegion().text()).toBe('');
    });

    it('announces the loading state while the endpoint is in flight with nothing visible', async () => {
      mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
      createWrapper();
      await emitSearch('sprint');

      expect(findSearchStatusRegion().text()).toBe('Searching for features …');
    });

    it('announces the visible result count while the endpoint is still in flight', async () => {
      mockAxios.onGet(SEARCH_URL).reply(() => new Promise(() => {}));
      createWrapper();
      await emitSearch('board');

      expect(findSearchStatusRegion().text()).toBe('1 feature found.');
    });

    it('announces a singular result count', async () => {
      mockSearch();
      createWrapper();
      await emitSearch('board');
      await waitForPromises();

      expect(findSearchStatusRegion().text()).toBe('1 feature found.');
    });

    it('announces a plural result count', async () => {
      mockSearch();
      createWrapper();
      await emitSearch('manage');
      await waitForPromises();

      expect(findSearchStatusRegion().text()).toBe('3 features found.');
    });

    it('announces when nothing matches, so keyboard users know Enter and ArrowDown will not act', async () => {
      mockSearch();
      createWrapper();
      await emitSearch('nonexistent feature');
      await waitForPromises();

      expect(findSearchStatusRegion().text()).toBe('No features match your search');
    });

    it('clears the announcement when the query is cleared', async () => {
      mockSearch();
      createWrapper();
      await emitSearch('board');
      await waitForPromises();
      await emitSearch('');

      expect(findSearchStatusRegion().text()).toBe('');
    });
  });

  describe('pin toggle', () => {
    beforeEach(() => createWrapper());

    it('re-emits pin-toggle (with title) from grid items', () => {
      findItems().at(0).vm.$emit('pin-toggle', 'some_id', true, 'Some title');
      expect(wrapper.emitted('pin-toggle')).toEqual([['some_id', true, 'Some title']]);
    });
  });

  describe('currentPinnedIds', () => {
    beforeEach(() => createWrapper({ currentPinnedIds: ['repository'] }));

    it('passes pinned=true to items whose id is in currentPinnedIds', () => {
      const matchingItem = findItems().wrappers.find((w) => w.props('item').id === 'repository');
      expect(matchingItem.props('pinned')).toBe(true);
    });
  });

  describe('supportsPins', () => {
    it('defaults to not supporting pins', () => {
      createWrapper();
      expect(findItems().at(0).props('supportsPins')).toBe(false);
    });

    describe('when pins are supported', () => {
      beforeEach(() => createWrapper({ supportsPins: true }));

      it('forwards supportsPins to every grid item', () => {
        expect(findItems().wrappers.every((w) => w.props('supportsPins') === true)).toBe(true);
      });
    });

    describe('when pins are not supported', () => {
      beforeEach(() => createWrapper({ supportsPins: false }));

      it('forwards supportsPins to every grid item', () => {
        expect(findItems().wrappers.every((w) => w.props('supportsPins') === false)).toBe(true);
      });
    });
  });

  describe('internal events tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    // The mixin forwards a third `category` arg (undefined) to InternalEvents.trackEvent.
    const CATEGORY = undefined;

    beforeEach(() => {
      createWrapper();
    });

    it('tracks opening the modal when it is shown', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findModal().vm.$emit('shown');
      expect(trackEventSpy).toHaveBeenCalledWith(EVENT_OPEN_FEATURE_LIBRARY_MODAL, {}, CATEGORY);
    });

    it('tracks selecting a category, labelled with the category id', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      await selectCategory('Plan');
      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_CLICK_CATEGORY_FILTER_IN_FEATURE_LIBRARY_MODAL,
        { label: 'plan_menu' },
        CATEGORY,
      );
    });

    it('tracks clearing the category back to "All", labelled "all"', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      await selectCategory('Plan');
      await selectCategory('Plan');
      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_CLICK_CATEGORY_FILTER_IN_FEATURE_LIBRARY_MODAL,
        { label: 'all' },
        CATEGORY,
      );
    });

    it('tracks pinning an item, labelled with the item id', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findItems().at(0).vm.$emit('pin-toggle', 'repository', true, 'Repository');
      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_PIN_ITEM_IN_FEATURE_LIBRARY_MODAL,
        { label: 'repository' },
        CATEGORY,
      );
    });

    it('tracks unpinning an item, labelled with the item id', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findItems().at(0).vm.$emit('pin-toggle', 'repository', false, 'Repository');
      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_UNPIN_ITEM_IN_FEATURE_LIBRARY_MODAL,
        { label: 'repository' },
        CATEGORY,
      );
    });

    it('tracks navigating to a feature, labelled with the item id', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findItems().at(0).vm.$emit('navigate', 'repository');
      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_NAVIGATE_TO_FEATURE_FROM_FEATURE_LIBRARY_MODAL,
        { label: 'repository' },
        CATEGORY,
      );
    });

    it('does not track a navigate event on Enter in the search box, since it only focuses the first result', async () => {
      mockAxios.onGet(SEARCH_URL).reply(HTTP_STATUS_OK, { ids: [] });
      await emitSearch('board');
      await waitForPromises();

      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findSearch().vm.$emit('keydown', new KeyboardEvent('keydown', { key: 'Enter' }));

      expect(trackEventSpy).not.toHaveBeenCalledWith(
        EVENT_NAVIGATE_TO_FEATURE_FROM_FEATURE_LIBRARY_MODAL,
        expect.anything(),
        CATEGORY,
      );
    });

    it('tracks a search event when the user types a query', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findSearch().vm.$emit('input', 'repo');
      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_SEARCH_FEATURES_IN_FEATURE_LIBRARY_MODAL,
        {},
        CATEGORY,
      );
    });

    it('does not track a search event when the query is blank', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findSearch().vm.$emit('input', '   ');
      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it('tracks a search event exactly once per input', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      findSearch().vm.$emit('input', 'repo');
      expect(trackEventSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('destroy', () => {
    it('cancels a pending reveal animation frame', () => {
      createWrapper();
      const cancelSpy = jest.spyOn(window, 'cancelAnimationFrame');

      wrapper.vm.renderLimit = 0;
      wrapper.vm.revealRemainingItems();
      const scheduledFrameId = wrapper.vm.revealFrameId;
      expect(scheduledFrameId).not.toBeNull();

      wrapper.destroy();

      expect(cancelSpy).toHaveBeenCalledWith(scheduledFrameId);
    });
  });

  describe('category filters', () => {
    beforeEach(() => createWrapper());

    it('renders an "All" button plus one button per catalog section, excluding settings', () => {
      expect(findCategoryFilterLabels()).toEqual(['All', 'Plan', 'Code', 'Manage']);
    });

    it('selects "All" by default', () => {
      const allButton = findCategoryFilters().at(0);
      expect(allButton.props('selected')).toBe(true);
    });

    it('lets the filter row scroll horizontally instead of wrapping', () => {
      expect(wrapper.findByTestId('feature-library-category-filters').classes()).toContain(
        'gl-overflow-x-auto',
      );
    });

    describe('when a category button is selected', () => {
      beforeEach(() => selectCategory('Plan'));

      it('marks the selected category button as pressed', () => {
        const planButton = findCategoryFilters().wrappers.find((w) => w.text() === 'Plan');
        expect(planButton.props('selected')).toBe(true);
        expect(planButton.attributes('aria-pressed')).toBe('true');
      });

      it('deselects the "All" button', () => {
        expect(findCategoryFilters().at(0).props('selected')).toBe(false);
      });

      it('scopes the flat grid to that category', () => {
        expect(findGrid().exists()).toBe(true);
        expect(findItemIds()).toEqual(['project_issue_list', 'boards', 'milestones']);
      });

      it('drops the collapsible section headers while filtered', () => {
        expect(findSectionToggles()).toHaveLength(0);
      });

      it('announces the active category and result count via a live region', () => {
        const status = wrapper.findByTestId('feature-library-category-status');
        expect(status.attributes('aria-live')).toBe('polite');
        expect(status.text()).toBe('Showing 3 features in Plan');
      });
    });

    describe('when no category filter is active', () => {
      beforeEach(() => createWrapper());

      it('leaves the category status live region empty', () => {
        expect(wrapper.findByTestId('feature-library-category-status').text()).toBe('');
      });
    });

    describe('when a category filter and a text query are both active', () => {
      beforeEach(async () => {
        mockSearch();
        await selectCategory('Plan');
        await emitSearch('board');
        await waitForPromises();
      });

      it('restricts search results to the selected category', () => {
        expect(findItemIds()).toEqual(['boards']);
      });
    });

    describe('when the selected category button is clicked again', () => {
      beforeEach(async () => {
        await selectCategory('Plan');
        await selectCategory('Plan');
      });

      it('clears the filter back to "All"', () => {
        expect(findCategoryFilters().at(0).props('selected')).toBe(true);
      });

      it('restores the grouped section view', () => {
        expect(findSectionTitles()).toEqual(['Plan', 'Code', 'Manage']);
      });
    });

    describe('when "All" is selected after a category', () => {
      beforeEach(async () => {
        await selectCategory('Plan');
        await selectCategory('All');
      });

      it('restores the grouped section view', () => {
        expect(findCategoryFilters().at(0).props('selected')).toBe(true);
        expect(findSectionTitles()).toEqual(['Plan', 'Code', 'Manage']);
      });
    });

    describe('when a category has no matches', () => {
      beforeEach(async () => {
        mockSearch();
        await selectCategory('Code');
        await emitSearch('zzznomatch');
        await waitForPromises();
      });

      it('shows the empty state', () => {
        expect(findEmptyState().exists()).toBe(true);
      });
    });

    describe('on modal hide', () => {
      it('resets the selected category back to "All"', async () => {
        await selectCategory('Plan');
        expect(findCategoryFilters().at(0).props('selected')).toBe(false);

        findModal().vm.$emit('hidden');
        await nextTick();

        expect(findCategoryFilters().at(0).props('selected')).toBe(true);
      });
    });
  });

  describe('explore pages', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    const buildExploreItem = (id, label = { type: 'new', plan: 'premium' }) => ({
      id,
      source: 'nav_item',
      title: id,
      description: `${id} description`,
      icon: 'rocket',
      docs_url: `/help/${id}`,
      label,
    });

    const buildExploreCatalog = ({ pages, trial = false } = {}) => ({
      current_plan_context: {
        deployment: 'saas',
        current_plan: 'free',
        base_plan: 'free',
        trial,
      },
      pages: pages || [
        {
          plan: 'premium',
          title: 'Explore Premium features',
          subtitle: 'Control merges and plan work across teams',
          highlights_title: 'Premium highlights',
          cta: { type: 'upgrade', text: 'Upgrade to Premium', url: 'https://example.com/premium' },
          highlights: [{ id: 'merge_controls', source: 'capability', title: 'Merge controls' }],
          credits: [],
          categories: [
            { id: 'secure_menu', title: 'Secure', items: [buildExploreItem('audit_events')] },
            // The sidebar already shows Boards.
            { id: 'plan_menu', title: 'Plan', items: [buildExploreItem('boards')] },
          ],
        },
        {
          plan: 'ultimate',
          title: 'Explore Ultimate features',
          subtitle: 'All of Premium, plus security, analytics, and more',
          highlights_title: 'Ultimate highlights',
          cta: null,
          highlights: [],
          credits: [],
          categories: [
            { id: 'secure_menu', title: 'Secure', items: [buildExploreItem('dashboard')] },
          ],
        },
      ],
    });

    const findHeader = () => wrapper.findByTestId('feature-library-header');
    const findTitle = () => wrapper.findByTestId('feature-library-title');
    const findExplorePageButtons = () => wrapper.findAllComponents(FeatureLibraryExplorePageButton);
    const findLoadedPageButtons = () =>
      findExplorePageButtons().wrappers.filter((w) => !w.props('loading'));
    const findLoadingPageButtons = () =>
      findExplorePageButtons().wrappers.filter((w) => w.props('loading'));
    const findPageButtonTitles = () => findLoadedPageButtons().map((w) => w.props('title'));
    const findCategoryFilterGroup = () => wrapper.findByTestId('feature-library-category-filters');
    const findBackButton = () => wrapper.findComponentByTestId('feature-library-back');
    const findExplorePage = () => wrapper.findComponent(FeatureLibraryExplorePage);
    const exploreCategoryItemIds = () =>
      findExplorePage()
        .props('page')
        .categories.map(({ title, items }) => [title, items.map(({ id }) => id)]);
    const catalogRequests = () => mockAxios.history.get.filter(({ url }) => url === CATALOG_URL);

    // GlModal emits `show` before it opens, then `shown` once it's open.
    const showModal = async () => {
      findModal().vm.$emit('show');
      await waitForPromises();
      findModal().vm.$emit('shown');
      await nextTick();
    };

    const closeModal = async () => {
      findModal().vm.$emit('hidden');
      await nextTick();
    };

    const openExplorePage = async (title) => {
      findLoadedPageButtons()
        .find((w) => w.props('title') === title)
        .vm.$emit('select');
      await nextTick();
    };

    const entryCardViews = (trackEventSpy) =>
      trackEventSpy.mock.calls.filter(([name]) => name.startsWith('view_explore_entry_card'));

    let exploreCatalog;

    const createExploreWrapper = (options = {}) =>
      createWrapper({ explorePagesAvailable: true, resourceId: 1, ...options });

    const mockPendingCatalog = () => {
      let respond;
      mockAxios.onGet(CATALOG_URL).reply(
        () =>
          new Promise((resolve) => {
            respond = () => resolve([HTTP_STATUS_OK, exploreCatalog]);
          }),
      );
      return () => respond();
    };

    beforeEach(() => {
      exploreCatalog = buildExploreCatalog();
      mockAxios.onGet(CATALOG_URL).reply(() => [HTTP_STATUS_OK, exploreCatalog]);
    });

    describe('when the explore pages are not available', () => {
      let trackEventSpy;

      beforeEach(async () => {
        createWrapper({ explorePagesAvailable: false, resourceId: 1 });
        ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
        await showModal();
      });

      it('renders no header and no page buttons', () => {
        expect(findHeader().exists()).toBe(false);
        expect(findExplorePageButtons()).toHaveLength(0);
      });

      it('does not request the catalog', () => {
        expect(catalogRequests()).toHaveLength(0);
      });

      it('keeps the spacing around the search field and category filters', () => {
        expect(findSearch().classes()).toContain('gl-mt-3');
        expect(findCategoryFilterGroup().classes()).toEqual(
          expect.arrayContaining(['gl-mb-1', 'gl-mt-1']),
        );
      });

      it('does not track page buttons being viewed', () => {
        expect(entryCardViews(trackEventSpy)).toEqual([]);
      });
    });

    describe('when the explore pages are available', () => {
      describe('before the modal is shown', () => {
        beforeEach(() => createExploreWrapper());

        it('does not request the catalog or render page buttons', () => {
          expect(catalogRequests()).toHaveLength(0);
          expect(findExplorePageButtons()).toHaveLength(0);
        });
      });

      describe('when the modal is shown', () => {
        beforeEach(async () => {
          createExploreWrapper();
          await showModal();
        });

        it('renders a page button for each page with its title and subtitle', () => {
          expect(findLoadedPageButtons().map((w) => w.props())).toEqual([
            {
              title: 'Explore Premium features',
              subtitle: 'Control merges and plan work across teams',
              loading: false,
            },
            {
              title: 'Explore Ultimate features',
              subtitle: 'All of Premium, plus security, analytics, and more',
              loading: false,
            },
          ]);
        });

        it('renders the page buttons after the category filters', () => {
          const pageButtons = wrapper.findByTestId('feature-library-explore-page-buttons').element;

          expect(findCategoryFilterGroup().element.compareDocumentPosition(pageButtons)).toBe(
            Node.DOCUMENT_POSITION_FOLLOWING,
          );
        });

        it('renders the page buttons side by side', () => {
          expect(wrapper.findByTestId('feature-library-explore-page-buttons').classes()).toContain(
            'sm:gl-grid-cols-2',
          );
        });
      });

      describe('when the modal is shown with a single page', () => {
        beforeEach(async () => {
          exploreCatalog.pages = exploreCatalog.pages.filter(({ plan }) => plan === 'ultimate');
          createExploreWrapper();
          await showModal();
        });

        it('renders the page button across the full row', () => {
          expect(findPageButtonTitles()).toEqual(['Explore Ultimate features']);
          expect(
            wrapper.findByTestId('feature-library-explore-page-buttons').classes(),
          ).not.toContain('sm:gl-grid-cols-2');
        });
      });

      describe('when the modal is shown in a group', () => {
        beforeEach(async () => {
          createExploreWrapper({ panelType: 'group' });
          await showModal();
        });

        it('requests the catalog for the panel and resource', () => {
          expect(catalogRequests()).toHaveLength(1);
          expect(catalogRequests()[0].params).toEqual({ panel: 'group', resource_id: 1 });
        });
      });

      describe('without a resource', () => {
        beforeEach(async () => {
          createExploreWrapper({ resourceId: null });
          await showModal();
        });

        it('does not request the catalog or render the header and page buttons', () => {
          expect(catalogRequests()).toHaveLength(0);
          expect(findHeader().exists()).toBe(false);
          expect(findExplorePageButtons()).toHaveLength(0);
        });
      });

      describe.each([
        [HTTP_STATUS_INTERNAL_SERVER_ERROR, 1, 2],
        [HTTP_STATUS_TOO_MANY_REQUESTS, 0, 1],
      ])('when the catalog request fails with %s', (status, sentryCalls, requestsAfterReopen) => {
        beforeEach(async () => {
          mockAxios.onGet(CATALOG_URL).reply(status);
          createExploreWrapper();
          await showModal();
        });

        it('renders no header and no page buttons', () => {
          expect(findHeader().exists()).toBe(false);
          expect(findExplorePageButtons()).toHaveLength(0);
        });

        it(`reports it to Sentry ${sentryCalls} time(s)`, () => {
          expect(Sentry.captureException).toHaveBeenCalledTimes(sentryCalls);
        });

        it(`makes ${requestsAfterReopen} request(s) in total when the modal opens again`, async () => {
          await closeModal();
          await showModal();

          expect(catalogRequests()).toHaveLength(requestsAfterReopen);
        });
      });

      describe('when no page comes back', () => {
        beforeEach(async () => {
          exploreCatalog = buildExploreCatalog({ pages: [] });
          createExploreWrapper();
          await showModal();
        });

        it('renders no header and no page buttons', () => {
          expect(findHeader().exists()).toBe(false);
          expect(findExplorePageButtons()).toHaveLength(0);
        });
      });

      describe('while the catalog loads', () => {
        let respond;
        let trackEventSpy;

        beforeEach(async () => {
          respond = mockPendingCatalog();
          createExploreWrapper();
          ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
          await showModal();
        });

        it('renders the "Feature catalog" header', () => {
          expect(findTitle().text()).toBe('Feature catalog');
        });

        it('renders two loading page buttons', () => {
          expect(findLoadingPageButtons()).toHaveLength(2);
          expect(findLoadedPageButtons()).toHaveLength(0);
        });

        it('does not track the loading page buttons', () => {
          expect(entryCardViews(trackEventSpy)).toEqual([]);
        });

        describe('when the modal is shown again', () => {
          beforeEach(async () => {
            await closeModal();
            await showModal();
          });

          it('does not request the catalog again', () => {
            expect(catalogRequests()).toHaveLength(1);
          });
        });

        describe('when the catalog loads', () => {
          beforeEach(async () => {
            respond();
            await waitForPromises();
          });

          it('replaces the loading page buttons with the pages', () => {
            expect(findLoadingPageButtons()).toHaveLength(0);
            expect(findLoadedPageButtons()).toHaveLength(2);
          });
        });

        describe('when the catalog has fewer pages', () => {
          beforeEach(async () => {
            exploreCatalog = buildExploreCatalog({
              pages: [buildExploreCatalog().pages[1]],
            });
            respond();
            await waitForPromises();
          });

          it('renders only the pages that came back', () => {
            expect(findPageButtonTitles()).toEqual(['Explore Ultimate features']);
          });
        });

        describe('when the modal is closed before the catalog loads', () => {
          beforeEach(async () => {
            await closeModal();
            respond();
            await waitForPromises();
          });

          it('does not track the page buttons until the modal opens again', async () => {
            expect(entryCardViews(trackEventSpy)).toEqual([]);

            await showModal();

            expect(trackEventSpy).toHaveBeenCalledWith(
              'view_explore_entry_card_in_feature_library_modal',
              { label: 'premium' },
              undefined,
            );
          });
        });
      });

      describe('when an entry card is selected', () => {
        let trackEventSpy;

        beforeEach(async () => {
          mockSearch();
          createExploreWrapper({ attachTo: document.body });
          await showModal();
          await emitSearch('re');
          await waitForPromises();
          ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
          await openExplorePage('Explore Premium features');
        });

        it('renders the page title and a back button in the header', () => {
          expect(findTitle().text()).toBe('Explore Premium features');
          expect(findBackButton().attributes('aria-label')).toBe('Back to all features');
        });

        it('renders the Explore page in place of the list view', () => {
          expect(findExplorePage().props('page')).toMatchObject({ plan: 'premium' });
          expect(wrapper.findAllComponents(ScrollScrim)).toHaveLength(0);
          expect(findSearch().exists()).toBe(false);
          expect(findCategoryFilterGroup().exists()).toBe(false);
          expect(findExplorePageButtons()).toHaveLength(0);
          expect(findScrollArea().exists()).toBe(false);
        });

        it('leaves out new items the sidebar already shows', () => {
          expect(exploreCategoryItemIds()).toEqual([
            ['Secure', ['audit_events']],
            ['Plan', []],
          ]);
        });

        it('hides the footer', () => {
          expect(findModal().attributes('hide-footer')).toBeDefined();
        });

        it('does not announce the hidden search results', () => {
          expect(findSearchStatusRegion().text()).toBe('');
        });

        it('moves focus to the title', () => {
          expect(document.activeElement).toBe(findTitle().element);
        });

        it('tracks the entry card click and the page view', () => {
          expect(trackEventSpy).toHaveBeenCalledWith(
            'click_explore_entry_card_in_feature_library_modal',
            { label: 'premium' },
            undefined,
          );
          expect(trackEventSpy).toHaveBeenCalledWith(
            'view_explore_page_in_feature_library_modal',
            { label: 'premium', property: 'free' },
            undefined,
          );
        });

        it('tracks a Learn more click with the page plan and the feature', async () => {
          findExplorePage().vm.$emit('learn-more', 'audit_events');
          await nextTick();

          expect(trackEventSpy).toHaveBeenCalledWith(
            'click_learn_more_in_feature_library_modal',
            { label: 'premium', property: 'audit_events' },
            undefined,
          );
        });

        describe('when the back button is clicked', () => {
          beforeEach(async () => {
            findBackButton().vm.$emit('click');
            await nextTick();
          });

          it('returns to the list with the "Feature catalog" title', () => {
            expect(findTitle().text()).toBe('Feature catalog');
            expect(findBackButton().exists()).toBe(false);
            expect(findPageButtonTitles()).toEqual([
              'Explore Premium features',
              'Explore Ultimate features',
            ]);
            expect(findScrollArea().exists()).toBe(true);
          });

          it('keeps the search query', () => {
            expect(findSearch().props('value')).toBe('re');
          });

          it('moves focus to the search field', () => {
            expect(findSearch().attributes('autofocus')).toBeDefined();
          });

          it('does not track the entry cards being viewed again', () => {
            expect(entryCardViews(trackEventSpy)).toHaveLength(2);
          });
        });

        describe('when the modal is hidden', () => {
          beforeEach(() => closeModal());

          it('returns to the list', () => {
            expect(findBackButton().exists()).toBe(false);
            expect(findSearch().exists()).toBe(true);
            expect(findPageButtonTitles()).toEqual([
              'Explore Premium features',
              'Explore Ultimate features',
            ]);
          });
        });
      });

      describe('when the sidebar already shows an enhanced item', () => {
        beforeEach(async () => {
          exploreCatalog = buildExploreCatalog();
          exploreCatalog.pages[0].categories[1].items = [
            buildExploreItem('boards', { type: 'enhanced', plan: 'premium' }),
          ];
          createExploreWrapper();
          await showModal();
          await openExplorePage('Explore Premium features');
        });

        it('keeps the item', () => {
          expect(exploreCategoryItemIds()).toEqual([
            ['Secure', ['audit_events']],
            ['Plan', ['boards']],
          ]);
        });
      });

      describe('when a highlight has the id of an item in the sidebar', () => {
        beforeEach(async () => {
          exploreCatalog = buildExploreCatalog();
          exploreCatalog.pages[0].highlights = [
            { id: 'members', source: 'capability', title: 'Members' },
          ];
          createExploreWrapper();
          await showModal();
          await openExplorePage('Explore Premium features');
        });

        it('keeps the highlight', () => {
          expect(
            findExplorePage()
              .props('page')
              .highlights.map(({ id }) => id),
          ).toEqual(['members']);
        });
      });

      describe('during a trial', () => {
        let trackEventSpy;

        beforeEach(async () => {
          exploreCatalog = buildExploreCatalog({ trial: true });
          createExploreWrapper();
          await showModal();
          ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
          await openExplorePage('Explore Premium features');
        });

        it('tracks the page view as a trial', () => {
          expect(trackEventSpy).toHaveBeenCalledWith(
            'view_explore_page_in_feature_library_modal',
            { label: 'premium', property: 'trial' },
            undefined,
          );
        });

        it('keeps the new items the sidebar already shows', () => {
          expect(exploreCategoryItemIds()).toEqual([
            ['Secure', ['audit_events']],
            ['Plan', ['boards']],
          ]);
        });
      });

      describe('when a page offers Migrate to Enterprise Edition', () => {
        const migrateCta = {
          type: 'migrate',
          text: 'Migrate to Enterprise Edition',
          url: '/help/update/convert_to_ee/_index.md#convert-to-enterprise-edition',
          new_tab: true,
        };
        const findUpgradeCta = () => wrapper.findComponent(FeatureLibraryUpgradeCta);

        beforeEach(async () => {
          exploreCatalog = buildExploreCatalog();
          exploreCatalog.pages[0].cta = migrateCta;
          createExploreWrapper();
          await showModal();
          await openExplorePage('Explore Premium features');
        });

        it('renders it in the header', () => {
          expect(findUpgradeCta().props('cta')).toEqual(migrateCta);
        });

        it('tracks a click with the page plan and the CTA type', () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findUpgradeCta().vm.$emit('click', 'migrate');

          expect(trackEventSpy).toHaveBeenCalledWith(
            'click_upgrade_cta_in_feature_library_modal',
            { label: 'premium', property: 'migrate' },
            undefined,
          );
        });
      });

      describe('when the modal is shown again after the catalog loaded', () => {
        let trackEventSpy;

        beforeEach(async () => {
          createExploreWrapper();
          ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
          await showModal();
          await closeModal();
          await showModal();
        });

        it('shows the pages without loading or requesting the catalog again', () => {
          expect(findLoadingPageButtons()).toHaveLength(0);
          expect(catalogRequests()).toHaveLength(1);
        });

        it('tracks the page buttons being viewed on each open', () => {
          expect(entryCardViews(trackEventSpy).map(([, { label }]) => label)).toEqual([
            'premium',
            'ultimate',
            'premium',
            'ultimate',
          ]);
        });
      });
    });
  });
});

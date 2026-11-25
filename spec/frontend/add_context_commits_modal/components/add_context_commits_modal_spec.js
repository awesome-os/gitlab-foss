import { GlModal, GlFilteredSearch } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import getDiffWithCommit from 'test_fixtures/merge_request_diffs/with_commit.json';
import AddReviewItemsModal from '~/add_context_commits_modal/components/add_context_commits_modal_wrapper.vue';
import { useAddContextCommits } from '~/add_context_commits_modal/store';

Vue.use(PiniaVuePlugin);

describe('AddContextCommitsModal', () => {
  let wrapper;
  let pinia;
  let store;
  const { commit } = getDiffWithCommit;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AddReviewItemsModal, {
      pinia,
      propsData: {
        contextCommitsPath: '',
        targetBranch: 'main',
        mergeRequestIid: 1,
        projectId: 1,
        ...props,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findAuthorToken = () =>
    findSearch()
      .props('availableTokens')
      .find((token) => token.type === 'author');

  beforeEach(() => {
    pinia = createTestingPinia();
    store = useAddContextCommits();
    createWrapper();
  });

  it('renders modal with 2 tabs', () => {
    expect(wrapper.element).toMatchSnapshot();
  });

  it('an ok button labeled "Save changes"', () => {
    expect(findModal().attributes('ok-title')).toEqual('Save changes');
  });

  describe('when in first tab, renders a modal with', () => {
    it('renders the search box component', () => {
      expect(findSearch().exists()).toBe(true);
    });

    it('wires the author token to the fetchAuthors action via the `fetchUsers` config key', () => {
      const authorToken = findAuthorToken();

      expect(authorToken.fetchUsers).toEqual(expect.any(Function));
    });

    it('when user submits after entering filters in search box, then it calls action "searchCommits"', () => {
      const search = [
        'abcd',
        {
          type: 'author',
          value: { operator: '=', data: 'abhi' },
        },
        {
          type: 'committed-before-date',
          value: { operator: '=', data: '2022-10-31' },
        },
        {
          type: 'committed-after-date',
          value: { operator: '=', data: '2022-10-28' },
        },
      ];
      findSearch().vm.$emit('submit', search);
      expect(store.searchCommits).toHaveBeenCalledWith({
        searchText: 'abcd',
        author: 'abhi',
        committed_before: '2022-10-31',
        committed_after: '2022-10-28',
      });
    });

    it('disabled ok button when no row is selected', () => {
      expect(findModal().attributes('ok-disabled')).toBe('true');
    });

    it('enabled ok button when atleast one row is selected', async () => {
      store.selectedCommits = [{ ...commit, isSelected: true }];
      await nextTick();
      expect(findModal().attributes('ok-disabled')).toBe(undefined);
    });
  });

  describe('when in second tab, renders a modal with', () => {
    beforeEach(() => {
      store.tabIndex = 1;
    });
    it('a disabled ok button when no row is selected', () => {
      expect(findModal().attributes('ok-disabled')).toBe('true');
    });

    it('an enabled ok button when atleast one row is selected', async () => {
      store.selectedCommits = [{ ...commit, isSelected: true }];
      await nextTick();
      expect(findModal().attributes('ok-disabled')).toBe(undefined);
    });

    it('a disabled ok button in first tab, when row is selected in second tab', () => {
      createWrapper({ selectedContextCommits: [commit] });
      expect(wrapper.findComponent(GlModal).attributes('ok-disabled')).toBe('true');
    });
  });

  describe('has an ok button when clicked calls action', () => {
    describe('when only new commits are to be added', () => {
      beforeEach(async () => {
        store.selectedCommits = [{ ...commit, isSelected: true }];
        findModal().vm.$emit('ok');
        await nextTick();
      });

      it('"createContextCommits"', () => {
        expect(store.createContextCommits).toHaveBeenCalledWith({
          commits: [{ ...commit, isSelected: true }],
          forceReload: true,
        });
      });
    });

    describe('when only added commits are to be removed', () => {
      beforeEach(async () => {
        store.toRemoveCommits = [commit.short_id];
        findModal().vm.$emit('ok');
        await nextTick();
      });

      it('"removeContextCommits"', () => {
        expect(store.removeContextCommits).toHaveBeenCalledWith(true);
      });
    });

    describe('when new commits are to be added and old commits are to be removed', () => {
      beforeEach(async () => {
        store.selectedCommits = [{ ...commit, isSelected: true }];
        store.toRemoveCommits = [commit.short_id];
        findModal().vm.$emit('ok');
        await nextTick();
      });

      it('"createContextCommits" and "removeContextCommits"', () => {
        expect(store.createContextCommits).toHaveBeenCalledWith({
          commits: [{ ...commit, isSelected: true }],
        });
        expect(store.removeContextCommits).toHaveBeenCalledWith();
      });
    });
  });

  describe('has a cancel button when clicked', () => {
    it('does not call "createContextCommits" or "removeContextCommits"', () => {
      findModal().vm.$emit('cancel');
      expect(store.createContextCommits).not.toHaveBeenCalled();
      expect(store.removeContextCommits).not.toHaveBeenCalled();
    });
    it('"resetModalState" to reset all the modal state', () => {
      findModal().vm.$emit('cancel');
      expect(store.resetModalState).toHaveBeenCalledWith();
    });
  });

  describe('when model is closed by clicking the "X" button or by pressing "ESC" key', () => {
    it('does not call "createContextCommits" or "removeContextCommits"', () => {
      findModal().vm.$emit('close');
      expect(store.createContextCommits).not.toHaveBeenCalled();
      expect(store.removeContextCommits).not.toHaveBeenCalled();
    });
    it('"resetModalState" to reset all the modal state', () => {
      findModal().vm.$emit('close');
      expect(store.resetModalState).toHaveBeenCalledWith();
    });
  });
});

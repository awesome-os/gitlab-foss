import { GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import { createWrapper as createRootWrapper } from '@vue/test-utils';
import WikiApp from '~/wikis/app.vue';
import WikiAlert from '~/wikis/components/wiki_alert.vue';
import WikiHeader from '~/wikis/components/wiki_header.vue';
import WikiContent from '~/wikis/components/wiki_content.vue';
import WikiForm from '~/wikis/components/wiki_form.vue';
import WikiNotesApp from '~/wikis/wiki_notes/components/wiki_notes_app.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';

describe('WikiApp', () => {
  let wrapper;

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(WikiApp, {
      provide: {
        wikiUrl: 'foo/bar',
        historyUrl: 'foo/history',
        ...provide,
      },
    });
  };

  const expectEditingInterface = () => {
    it('does not show the wiki content', () => {
      expect(wrapper.findComponent(WikiContent).exists()).toBe(false);
    });

    it('does show the wiki edit form', () => {
      expect(wrapper.findComponent(WikiForm).exists()).toBe(true);
    });

    it('does not show the wiki header', () => {
      expect(wrapper.findComponent(WikiHeader).exists()).toBe(false);
    });
  };

  describe('with default settings', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders without error', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('does not show any alert', () => {
      expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
      expect(wrapper.findComponent(WikiAlert).exists()).toBe(false);
    });

    it('does show the wiki header', () => {
      expect(wrapper.findComponent(WikiHeader).exists()).toBe(true);
    });

    it('does show the wiki content', () => {
      expect(wrapper.findComponent(WikiContent).exists()).toBe(true);
    });

    it('does not show the wiki edit form', () => {
      expect(wrapper.findComponent(WikiForm).exists()).toBe(false);
    });

    it('does show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(true);
    });

    it('toggles editing state', async () => {
      expect(wrapper.findComponent(WikiContent).exists()).toBe(true);
      expect(wrapper.findComponent(WikiForm).exists()).toBe(false);

      wrapper.getComponent(WikiHeader).vm.$emit('is-editing', true);
      await nextTick();

      expect(wrapper.findComponent(WikiContent).exists()).toBe(false);
      expect(wrapper.findComponent(WikiForm).exists()).toBe(true);

      wrapper.getComponent(WikiForm).vm.$emit('is-editing', false);
      await nextTick();

      expect(wrapper.findComponent(WikiContent).exists()).toBe(true);
      expect(wrapper.findComponent(WikiForm).exists()).toBe(false);
    });
  });

  describe('when creating a new page', () => {
    beforeEach(() => {
      setWindowLocation('?view=create');
      createComponent({ pagePersisted: false });
    });

    expectEditingInterface();

    it('does not show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(false);
    });
  });

  describe('when opening an edit URL on an existing page', () => {
    beforeEach(() => {
      setWindowLocation('?edit=true');
      createComponent({ pagePersisted: true });
    });

    expectEditingInterface();

    it('does show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(true);
    });
  });

  describe('when editing the custom sidebar', () => {
    beforeEach(() => {
      setWindowLocation('?edit=true');
      createComponent({ pagePersisted: true, wikiUrl: '_sidebar' });
    });

    expectEditingInterface();

    it('does not show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(false);
    });
  });

  describe('when editing a saved wiki page', () => {
    beforeEach(() => {
      setWindowLocation('?edit=true');
      createComponent({ pagePersisted: true });
    });

    it('does show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(true);
    });
  });

  describe('when viewing a historical page', () => {
    beforeEach(() => {
      createComponent({ isPageHistorical: true });
    });

    it('does show a notification', () => {
      const alert = wrapper.getComponent(GlAlert);
      expect(alert.text()).toContain('This is an old version of this page.');
      expect(alert.props('primaryButtonText')).toBe('Go to most recent version');
      expect(alert.props('primaryButtonLink')).toBe('foo/bar');
      expect(alert.props('secondaryButtonText')).toBe('Browse history');
      expect(alert.props('secondaryButtonLink')).toBe('foo/history');
    });
  });

  describe('when the page has an error', () => {
    beforeEach(() => {
      createComponent({
        error: 'Some Error',
      });
    });

    it('does show a notification', () => {
      const alert = wrapper.getComponent(WikiAlert);
      expect(alert.props('error')).toBe('Some Error');
    });

    it('enters edit mode', () => {
      expect(wrapper.findComponent(WikiForm).exists()).toBe(true);
      expect(wrapper.findComponent(WikiContent).exists()).toBe(false);
    });

    it('does not show the wiki header', () => {
      expect(wrapper.findComponent(WikiHeader).exists()).toBe(false);
    });
  });

  describe('when the page has an error on a new page', () => {
    beforeEach(() => {
      createComponent({
        error: 'Validation failed',
        pagePersisted: false,
      });
    });

    it('enters edit mode', () => {
      expect(wrapper.findComponent(WikiForm).exists()).toBe(true);
      expect(wrapper.findComponent(WikiContent).exists()).toBe(false);
    });

    it('does show the error notification', () => {
      const alert = wrapper.getComponent(WikiAlert);
      expect(alert.props('error')).toBe('Validation failed');
    });

    it('does not show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(false);
    });
  });

  describe('when the page has an error on an existing page', () => {
    beforeEach(() => {
      createComponent({
        error: 'Validation failed',
        pagePersisted: true,
      });
    });

    it('enters edit mode', () => {
      expect(wrapper.findComponent(WikiForm).exists()).toBe(true);
      expect(wrapper.findComponent(WikiContent).exists()).toBe(false);
    });

    it('does show the wiki notes', () => {
      expect(wrapper.findComponent(WikiNotesApp).exists()).toBe(true);
    });
  });

  describe('when the last save failed because someone else edited the page', () => {
    beforeEach(() => {
      setWindowLocation('?edit=true');
      createComponent({ pagePersisted: true, pageChanged: true });
    });

    it('tells the edit form', () => {
      expect(wrapper.getComponent(WikiForm).props('pageChanged')).toBe(true);
    });

    it('does not tell a form opened after leaving edit mode', async () => {
      wrapper.getComponent(WikiForm).vm.$emit('is-editing', false);
      await nextTick();
      wrapper.getComponent(WikiHeader).vm.$emit('is-editing', true);
      await nextTick();

      expect(wrapper.getComponent(WikiForm).props('pageChanged')).toBe(false);
    });
  });

  describe('saved drafts', () => {
    const pageInfo = {
      persisted: true,
      title: 'My page',
      content: 'My page content',
      format: 'markdown',
      path: '/wikis/my-page',
      createPath: '/wikis/new',
    };

    const seedDraft = (path, { title = 'My page', content = 'My page content' } = {}) => {
      localStorage.setItem(`autosave/${path}/title`, title);
      localStorage.setItem(`autosave/${path}/content`, content);
      localStorage.setItem(`autosave/${path}/commit`, 'Update My page');
    };

    const draftExists = (path) => localStorage.getItem(`autosave/${path}/content`) !== null;

    afterEach(() => {
      localStorage.clear();
    });

    describe.each`
      scenario               | path
      ${'the page'}          | ${'/wikis/my-page'}
      ${'a new page create'} | ${'/wikis/new'}
    `('when a draft for $scenario matches the shown page', ({ path }) => {
      beforeEach(() => {
        seedDraft(path, { content: 'My page content\n' });
        createComponent({ pageInfo });
      });

      it('clears the draft', () => {
        expect(draftExists(path)).toBe(false);
        expect(localStorage.getItem(`autosave/${path}/commit`)).toBeNull();
      });
    });

    describe('when the page was saved with CRLF line endings', () => {
      const crlfPageInfo = { ...pageInfo, content: 'First line\r\n\r\nSecond line\r\n' };

      it('clears a matching LF draft', () => {
        seedDraft('/wikis/my-page', { content: 'First line\n\nSecond line\n' });
        createComponent({ pageInfo: crlfPageInfo });

        expect(draftExists('/wikis/my-page')).toBe(false);
      });

      it('keeps a different LF draft', () => {
        seedDraft('/wikis/my-page', { content: 'First line\n\nChanged second line\n' });
        createComponent({ pageInfo: crlfPageInfo });

        expect(draftExists('/wikis/my-page')).toBe(true);
      });
    });

    describe('when the draft differs from the shown page', () => {
      beforeEach(() => {
        seedDraft('/wikis/my-page', { content: 'unsaved changes' });
        createComponent({ pageInfo });
      });

      it('keeps the draft', () => {
        expect(draftExists('/wikis/my-page')).toBe(true);
      });
    });

    describe('when the edit form is shown', () => {
      beforeEach(() => {
        seedDraft('/wikis/my-page');
        setWindowLocation('?edit=true');
        createComponent({ pageInfo, pagePersisted: true });
      });

      it('keeps the draft', () => {
        expect(draftExists('/wikis/my-page')).toBe(true);
      });
    });
  });

  describe('when URL has view=create param', () => {
    beforeEach(() => {
      setWindowLocation('?view=create');
      createComponent();
    });

    it('enters edit mode', () => {
      expect(wrapper.findComponent(WikiForm).exists()).toBe(true);
      expect(wrapper.findComponent(WikiContent).exists()).toBe(false);
    });
  });

  describe('when exiting edit mode', () => {
    let pushStateSpy;

    beforeEach(async () => {
      setWindowLocation('?edit=true&view=create');
      pushStateSpy = jest.spyOn(window.history, 'pushState').mockImplementation(() => {});
      createComponent();
      await nextTick();

      wrapper.getComponent(WikiForm).vm.$emit('is-editing', false);
      await nextTick();
    });

    afterEach(() => {
      pushStateSpy.mockRestore();
    });

    it('removes both edit and view params from URL', () => {
      expect(pushStateSpy).toHaveBeenCalled();
      const pushedUrl = pushStateSpy.mock.calls[0][2];
      expect(pushedUrl).not.toContain('edit=');
      expect(pushedUrl).not.toContain('view=');
    });
  });

  describe('when URL has open_clone_modal param', () => {
    let replaceStateSpy;

    beforeEach(() => {
      setWindowLocation('?open_clone_modal=true');
      replaceStateSpy = jest.spyOn(window.history, 'replaceState').mockImplementation(() => {});
      createComponent();
    });

    afterEach(() => {
      replaceStateSpy.mockRestore();
    });

    it('removes the open_clone_modal param from the URL', () => {
      expect(replaceStateSpy).toHaveBeenCalled();
      const replacedUrl = replaceStateSpy.mock.calls[0][2].toString();
      expect(replacedUrl).not.toContain('open_clone_modal');
    });

    it('emits BV_SHOW_MODAL to open the clone modal', () => {
      const emitted = createRootWrapper(wrapper.vm.$root).emitted('bv::show::modal');
      expect(emitted).toHaveLength(1);
      expect(emitted[0]).toContain('clone-wiki-modal');
    });
  });
});

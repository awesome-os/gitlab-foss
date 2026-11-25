import { mount } from '@vue/test-utils';
import { MountingPortal } from 'portal-vue';
import { stubComponent } from 'helpers/stub_component';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import PanelActionsPortal from '~/vue_shared/components/panel_actions_portal.vue';

const MountingPortalStub = stubComponent(MountingPortal);

describe('PanelActionsPortal', () => {
  let wrapper;

  const findMountingPortal = () => wrapper.findComponent(MountingPortalStub);
  const $ = (selector) => document.querySelector(selector);

  const createComponent = (mountEl, options = {}) => {
    wrapper = mount(PanelActionsPortal, {
      attachTo: mountEl,
      stubs: { MountingPortal: MountingPortalStub },
      slots: { default: 'Test portal content' },
      ...options,
    });
  };

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('when not inside a .js-paneled-view element', () => {
    beforeEach(() => {
      setHTMLFixture('<div id="mount-here"></div>');
      createComponent($('#mount-here'));
    });

    it('does not render a MountingPortal', () => {
      expect(findMountingPortal().exists()).toBe(false);
    });
  });

  describe('when inside a .js-paneled-view with no .js-panel-actions-portal-target', () => {
    beforeEach(() => {
      setHTMLFixture(`
        <div class="js-paneled-view">
          <div id="mount-here"></div>
        </div>
      `);
      createComponent($('#mount-here'));
    });

    it('does not render a MountingPortal', () => {
      expect(findMountingPortal().exists()).toBe(false);
    });
  });

  describe('when inside a .js-paneled-view with a .js-panel-actions-portal-target', () => {
    beforeEach(() => {
      setHTMLFixture(`
        <div class="js-paneled-view">
          <div class="js-panel-actions-portal-target"></div>
          <div id="mount-here"></div>
        </div>
      `);
      createComponent($('#mount-here'));
    });

    it('renders a MountingPortal', () => {
      expect(findMountingPortal().exists()).toBe(true);
    });

    it('assigns a unique id to the target and uses it as mount-to', () => {
      const uniqueId = $('.js-panel-actions-portal-target').id;

      expect(uniqueId).toMatch(/.+/);

      const mountTo = findMountingPortal().attributes('mount-to');

      expect(mountTo).toBe(`#${uniqueId}`);
    });

    it('passes slot content through to the MountingPortal', () => {
      expect(wrapper.text()).toContain('Test portal content');
    });
  });

  describe('when the .js-panel-actions-portal-target already has an id', () => {
    beforeEach(() => {
      setHTMLFixture(`
        <div class="js-paneled-view">
          <div class="js-panel-actions-portal-target" id="my-existing-id"></div>
          <div id="mount-here"></div>
        </div>
      `);
      createComponent($('#mount-here'));
    });

    it('reuses the existing id as mount-to', () => {
      expect(findMountingPortal().attributes('mount-to')).toBe('#my-existing-id');
    });
  });

  describe('page actions landmark', () => {
    const findLandmark = () => $('.js-panel-actions-landmark');

    const setupLandmark = ({ serverActions = '', portalContent = '' } = {}) => {
      setHTMLFixture(`
        <div class="js-paneled-view">
          <section class="js-panel-actions-landmark" data-label="Page actions">
            ${serverActions}
            <div class="js-panel-actions-portal-target">${portalContent}</div>
          </section>
          <div id="mount-here"></div>
        </div>
      `);
    };

    it('labels the landmark when it has content to mount', () => {
      setupLandmark();
      createComponent($('#mount-here'));

      expect(findLandmark().getAttribute('aria-label')).toBe('Page actions');
    });

    it('does not label the landmark without content to mount', () => {
      setupLandmark();
      createComponent($('#mount-here'), { slots: {} });

      expect(findLandmark().hasAttribute('aria-label')).toBe(false);
    });

    it('removes the label when the last actions unmount', () => {
      setupLandmark();
      createComponent($('#mount-here'));

      wrapper.destroy();

      expect(findLandmark().hasAttribute('aria-label')).toBe(false);
    });

    it.each`
      description                   | fixture
      ${'another portal'}           | ${{ portalContent: '<div>Other portal content</div>' }}
      ${'the server-rendered slot'} | ${{ serverActions: '<button>Server action</button>' }}
    `('keeps the label on unmount while $description still has actions', ({ fixture }) => {
      setupLandmark(fixture);
      createComponent($('#mount-here'));

      wrapper.destroy();

      expect(findLandmark().getAttribute('aria-label')).toBe('Page actions');
    });
  });
});

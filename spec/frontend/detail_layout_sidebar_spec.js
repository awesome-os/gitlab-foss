import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { useFakeRequestAnimationFrame } from 'helpers/fake_request_animation_frame';
import { useMockResizeObserver } from 'helpers/mock_dom_observer';
import initDetailLayoutSidebars from '~/detail_layout_sidebar';

describe('initDetailLayoutSidebars', () => {
  const SPACE_VAR = '--detail-layout-sidebar-space';
  let container;
  let sidebar;

  useFakeRequestAnimationFrame();
  const { trigger: triggerResize } = useMockResizeObserver();

  const findSidebar = () => document.querySelector('.js-detail-layout-sidebar');
  const getSpace = () => sidebar.style.getPropertyValue(SPACE_VAR);
  const setSidebarTop = (top) =>
    jest.spyOn(sidebar, 'getBoundingClientRect').mockReturnValue({ top });

  const setup = ({ insideScrollContainer = true } = {}) => {
    const layout = `
      <div class="gl-base-layout">
        <div class="gl-detail-layout-container">
          <aside class="gl-detail-layout-sidebar js-detail-layout-sidebar"></aside>
        </div>
      </div>`;
    setHTMLFixture(
      insideScrollContainer ? `<div class="panel-content-inner">${layout}</div>` : layout,
    );
    container = document.querySelector('.panel-content-inner');
    sidebar = findSidebar();
    if (container) jest.spyOn(container, 'getBoundingClientRect').mockReturnValue({ top: 0 });
  };

  afterEach(() => {
    resetHTMLFixture();
  });

  it('sets the space to the distance from the panel top to the sidebar top', () => {
    setup();
    setSidebarTop(120);

    initDetailLayoutSidebars();

    expect(getSpace()).toBe('120px');
  });

  it('re-measures when the panel scrolls', () => {
    setup();
    setSidebarTop(120);
    initDetailLayoutSidebars();

    setSidebarTop(40);
    container.dispatchEvent(new Event('scroll'));

    expect(getSpace()).toBe('40px');
  });

  it('re-measures when the layout above the sidebar changes size', () => {
    setup();
    setSidebarTop(120);
    initDetailLayoutSidebars();

    setSidebarTop(160);
    triggerResize(document.querySelector('.gl-base-layout'));

    expect(getSpace()).toBe('160px');
  });

  it('does nothing outside a panel', () => {
    setup({ insideScrollContainer: false });

    initDetailLayoutSidebars();

    expect(getSpace()).toBe('');
  });
});

export const SCROLL_CONTAINER_SELECTOR = '.panel-content-inner';
const SIDEBAR_SELECTOR = '.js-detail-layout-sidebar';
const LAYOUT_SELECTOR = '.gl-base-layout';

const measureSidebarSpace = (sidebar, container) => {
  const containerRect = container.getBoundingClientRect();
  const style = window.getComputedStyle(sidebar);

  if (style.position !== 'sticky') {
    return sidebar.getBoundingClientRect().top - containerRect.top;
  }

  // Derived from the layout, not the sidebar's own rect, which can be stale mid-scroll.
  // The sticky inset applies to the border box, so the margin only affects naturalTop.
  const scrollportTop = containerRect.top + container.clientTop;
  const marginTop = parseFloat(style.marginTop) || 0;
  const inset = parseFloat(style.top);
  const naturalTop = sidebar.parentElement.getBoundingClientRect().top + marginTop;
  const stuckTop = Number.isNaN(inset) ? -Infinity : scrollportTop + inset;

  return Math.max(naturalTop, stuckTop) - scrollportTop;
};

// Caps the sidebar's height, see `--detail-layout-sidebar-space` in detail_layout.scss
export const syncSidebarSpace = (sidebar, container) => {
  const space = measureSidebarSpace(sidebar, container);
  sidebar.style.setProperty('--detail-layout-sidebar-space', `${Math.max(space, 0)}px`);
};

const initSidebar = (sidebar) => {
  const container = sidebar.closest(SCROLL_CONTAINER_SELECTOR);
  if (!container) return;

  let frame;
  const schedule = () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => syncSidebarSpace(sidebar, container));
  };

  container.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  if (typeof ResizeObserver !== 'undefined') {
    new ResizeObserver(schedule).observe(sidebar.closest(LAYOUT_SELECTOR) ?? sidebar.parentElement);
  }

  syncSidebarSpace(sidebar, container);
};

// For the HAML DetailLayout. detail_layout.vue wires its own sidebar.
export default () => {
  document.querySelectorAll(SIDEBAR_SELECTOR).forEach((sidebar) => initSidebar(sidebar));
};

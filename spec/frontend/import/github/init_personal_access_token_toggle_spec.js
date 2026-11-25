import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initPersonalAccessTokenToggle } from '~/pages/import/github/new/init_personal_access_token_toggle';

describe('initPersonalAccessTokenToggle', () => {
  let toggle;
  let panel;
  let icon;

  beforeEach(() => {
    setHTMLFixture(`
    <div>
      <button type="button" class="js-import-github-pat-toggle" aria-expanded="false" aria-controls="personal-access-token-panel">
        <svg><use href="/assets/icons.svg#chevron-lg-right"></use></svg>
        Use a personal access token instead
      </button>
      <div id="personal-access-token-panel" class="gl-hidden"></div>
    </div>
    `);

    toggle = document.querySelector('.js-import-github-pat-toggle');
    panel = document.getElementById('personal-access-token-panel');
    icon = toggle.querySelector('svg use');

    initPersonalAccessTokenToggle();
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('expands the panel and syncs aria-expanded on click', () => {
    toggle.click();

    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(panel.classList.contains('gl-hidden')).toBe(false);
  });

  it('swaps the chevron icon when expanded and back when collapsed', () => {
    toggle.click();

    expect(icon.getAttribute('href')).toBe('/assets/icons.svg#chevron-lg-down');

    toggle.click();

    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(panel.classList.contains('gl-hidden')).toBe(true);
    expect(icon.getAttribute('href')).toBe('/assets/icons.svg#chevron-lg-right');
  });

  it('does nothing when the toggle or panel is missing', () => {
    resetHTMLFixture();
    setHTMLFixture('<div></div>');

    expect(() => initPersonalAccessTokenToggle()).not.toThrow();
  });
});

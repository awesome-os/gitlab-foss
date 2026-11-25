const COLLAPSED_ICON = 'chevron-lg-right';
const EXPANDED_ICON = 'chevron-lg-down';

export const initPersonalAccessTokenToggle = () => {
  const toggle = document.querySelector('.js-import-github-pat-toggle');
  const panel = document.getElementById('personal-access-token-panel');

  if (!toggle || !panel) {
    return;
  }

  const setIcon = (name) => {
    const use = toggle.querySelector('svg use');

    if (use) {
      use.setAttribute('href', use.getAttribute('href').replace(/#.*/, `#${name}`));
    }
  };

  toggle.addEventListener('click', () => {
    const expanded = toggle.getAttribute('aria-expanded') === 'true';

    toggle.setAttribute('aria-expanded', String(!expanded));
    panel.classList.toggle('gl-hidden', expanded);
    setIcon(expanded ? COLLAPSED_ICON : EXPANDED_ICON);
  });
};

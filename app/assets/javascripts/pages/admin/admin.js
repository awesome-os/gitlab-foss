import { refreshCurrentPage } from '~/lib/utils/url_utility';

export default function adminInit() {
  document.querySelectorAll('.js-toggle-colors-link').forEach((link) => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      document
        .querySelectorAll('.js-toggle-colors-container')
        .forEach((container) => container.classList.toggle('hide'));
    });
  });

  document
    .querySelectorAll('li.project_member, li.group_member')
    .forEach((member) => member.addEventListener('ajax:success', refreshCurrentPage));
}

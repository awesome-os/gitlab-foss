import { fixTitle } from '~/tooltips';
import { createAlert } from '~/alert';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import axios from '~/lib/utils/axios_utils';
import { __ } from '~/locale';

const tooltipTitles = {
  group: {
    subscribed: __('Unsubscribe at group level'),
    unsubscribed: __('Subscribe at group level'),
  },
  project: {
    subscribed: __('Unsubscribe at project level'),
    unsubscribed: __('Subscribe at project level'),
  },
};

export default class ProjectLabelSubscription {
  constructor(container) {
    this.buttons = container.querySelectorAll('.js-subscribe-button');

    this.buttons.forEach((button) =>
      button.addEventListener('click', this.toggleSubscription.bind(this)),
    );
  }

  toggleSubscription(event) {
    event.preventDefault();

    const btn = event.currentTarget;
    const url = btn.getAttribute('data-url');
    const oldStatus = btn.getAttribute('data-status');

    btn.classList.add('disabled');

    axios
      .post(url)
      .then(() => {
        let newStatus;
        let newAction;

        if (oldStatus === 'unsubscribed') {
          [newStatus, newAction] = ['subscribed', __('Unsubscribe')];
        } else {
          [newStatus, newAction] = ['unsubscribed', __('Subscribe')];
        }

        btn.classList.remove('disabled');

        this.buttons.forEach((button) => {
          button.setAttribute('data-status', newStatus);
          button.querySelectorAll(':scope > span').forEach((span) => {
            // eslint-disable-next-line no-param-reassign
            span.textContent = newAction;
          });
        });

        this.buttons.forEach((button) => {
          const originalTitle = button.getAttribute('data-original-title');

          if (originalTitle) {
            ProjectLabelSubscription.setNewTitle(button, originalTitle, newStatus);
          }
        });
      })
      .catch(() =>
        createAlert({
          message: __('There was an error subscribing to this label.'),
        }),
      );
  }

  static setNewTitle(button, originalTitle, newStatus) {
    const type = /group/.test(originalTitle) ? NAMESPACE_GROUP : NAMESPACE_PROJECT;
    const newTitle = tooltipTitles[type][newStatus];

    button.setAttribute('title', newTitle);
    fixTitle(button);
  }
}

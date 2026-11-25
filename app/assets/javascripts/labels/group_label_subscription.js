import { __ } from '~/locale';
import { fixTitle, hide } from '~/tooltips';
import { createAlert } from '~/alert';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import axios from '~/lib/utils/axios_utils';

const tooltipTitles = {
  group: __('Unsubscribe at group level'),
  project: __('Unsubscribe at project level'),
};

export default class GroupLabelSubscription {
  constructor(container) {
    this.dropdowns = container.querySelectorAll('.dropdown');
    this.subscribeButtons = container.querySelectorAll('.js-subscribe-button');
    this.unsubscribeButtons = container.querySelectorAll('.js-unsubscribe-button');

    this.subscribeButtons.forEach((button) =>
      button.addEventListener('click', this.subscribe.bind(this)),
    );
    this.unsubscribeButtons.forEach((button) =>
      button.addEventListener('click', this.unsubscribe.bind(this)),
    );
  }

  unsubscribe(event) {
    event.preventDefault();

    const url = this.unsubscribeButtons[0]?.getAttribute('data-url');
    axios
      .post(url)
      .then(() => {
        this.toggleSubscriptionButtons();
        this.unsubscribeButtons.forEach((button) => button.removeAttribute('data-url'));
      })
      .catch(() =>
        createAlert({
          message: __('There was an error when unsubscribing from this label.'),
        }),
      );
  }

  subscribe(event) {
    event.preventDefault();

    const btn = event.currentTarget;
    const url = btn.getAttribute('data-url');

    this.unsubscribeButtons.forEach((button) => button.setAttribute('data-url', url));

    axios
      .post(url)
      .then(() => GroupLabelSubscription.setNewTooltip(btn))
      .then(() => this.toggleSubscriptionButtons())
      .catch(() =>
        createAlert({
          message: __('There was an error when subscribing to this label.'),
        }),
      );
  }

  toggleSubscriptionButtons() {
    [this.dropdowns, this.subscribeButtons, this.unsubscribeButtons].forEach((elements) =>
      elements.forEach((element) => element.classList.toggle('hidden')),
    );
  }

  static setNewTooltip(button) {
    if (!button.classList.contains('js-subscribe-button')) return;

    const type = button.classList.contains('js-group-level') ? NAMESPACE_GROUP : NAMESPACE_PROJECT;
    const newTitle = tooltipTitles[type];

    const unsubscribeButtons =
      button.closest('.label-actions-list')?.querySelectorAll('.js-unsubscribe-button') ?? [];
    hide(unsubscribeButtons);
    unsubscribeButtons.forEach((element) => element.setAttribute('title', `${newTitle}`));
    fixTitle(unsubscribeButtons);
  }
}

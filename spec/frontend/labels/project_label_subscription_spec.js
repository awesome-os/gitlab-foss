import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import axios from '~/lib/utils/axios_utils';
import ProjectLabelSubscription from '~/labels/project_label_subscription';
import { fixTitle } from '~/tooltips';

jest.mock('~/alert');
jest.mock('~/tooltips');

describe('ProjectLabelSubscription', () => {
  let mock;
  let container;

  const url = '/gitlab-org/gitlab/labels/1/toggle_subscription';

  const findButtons = () => [...container.querySelectorAll('.js-subscribe-button')];

  beforeEach(() => {
    mock = new MockAdapter(axios);

    setHTMLFixture(`
      <div class="js-label-subscription">
        <button class="js-subscribe-button" data-status="unsubscribed" data-url="${url}" data-original-title="Subscribe at project level"><span>Subscribe</span><i>icon</i></button>
        <button class="js-subscribe-button" data-status="unsubscribed" data-url="${url}" data-original-title="Subscribe at group level"><span>Subscribe</span></button>
        <button class="js-subscribe-button" data-status="unsubscribed" data-url="${url}"><span>Subscribe</span></button>
      </div>
    `);
    container = document.querySelector('.js-label-subscription');

    // eslint-disable-next-line no-new
    new ProjectLabelSubscription(container);
  });

  afterEach(() => {
    mock.restore();
    resetHTMLFixture();
    jest.clearAllMocks();
  });

  it('disables the clicked button while the request is running', () => {
    mock.onPost(url).reply(HTTP_STATUS_OK);

    findButtons()[0].click();

    expect(findButtons()[0].classList.contains('disabled')).toBe(true);
    expect(mock.history.post).toHaveLength(0);
  });

  it('subscribes and updates the status and label of every button', async () => {
    mock.onPost(url).reply(HTTP_STATUS_OK);

    findButtons()[0].click();
    await waitForPromises();

    expect(mock.history.post[0].url).toBe(url);
    expect(findButtons()[0].classList.contains('disabled')).toBe(false);
    findButtons().forEach((button) => {
      expect(button.getAttribute('data-status')).toBe('subscribed');
      expect(button.querySelector('span').textContent).toBe('Unsubscribe');
    });
    expect(findButtons()[0].querySelector('i').textContent).toBe('icon');
  });

  it('subscribes again after unsubscribing', async () => {
    mock.onPost(url).reply(HTTP_STATUS_OK);

    findButtons()[0].click();
    await waitForPromises();
    findButtons()[1].click();
    await waitForPromises();

    findButtons().forEach((button) => {
      expect(button.getAttribute('data-status')).toBe('unsubscribed');
      expect(button.querySelector('span').textContent).toBe('Subscribe');
    });
  });

  it('updates the tooltip of buttons that have one, using the namespace of the old title', async () => {
    mock.onPost(url).reply(HTTP_STATUS_OK);

    findButtons()[0].click();
    await waitForPromises();

    expect(findButtons()[0].getAttribute('title')).toBe('Unsubscribe at project level');
    expect(findButtons()[1].getAttribute('title')).toBe('Unsubscribe at group level');
    expect(findButtons()[2].hasAttribute('title')).toBe(false);
    expect(fixTitle).toHaveBeenCalledTimes(2);
    expect(fixTitle).toHaveBeenCalledWith(findButtons()[0]);
    expect(fixTitle).toHaveBeenCalledWith(findButtons()[1]);
  });

  it('shows an alert and leaves the buttons as they are when the request fails', async () => {
    mock.onPost(url).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

    findButtons()[0].click();
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: 'There was an error subscribing to this label.',
    });
    expect(findButtons()[0].getAttribute('data-status')).toBe('unsubscribed');
    expect(findButtons()[0].querySelector('span').textContent).toBe('Subscribe');
  });
});

import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import axios from '~/lib/utils/axios_utils';
import GroupLabelSubscription from '~/labels/group_label_subscription';
import { fixTitle, hide } from '~/tooltips';

jest.mock('~/alert');
jest.mock('~/tooltips');

describe('GroupLabelSubscription', () => {
  let mock;
  let container;

  const groupUrl = '/groups/gitlab-org/labels/1/toggle_subscription';
  const projectUrl = '/gitlab-org/gitlab/labels/1/toggle_subscription';

  const findDropdown = () => container.querySelector('.dropdown');
  const findUnsubscribeButton = () => container.querySelector('.js-unsubscribe-button');
  const findGroupButton = () => container.querySelector('.js-group-level');
  const findProjectButton = () =>
    container.querySelector('.js-subscribe-button:not(.js-group-level)');
  const isHidden = (element) => element.classList.contains('hidden');

  beforeEach(() => {
    mock = new MockAdapter(axios);

    setHTMLFixture(`
      <ul class="label-actions-list">
        <li class="js-label-subscription">
          <button class="js-unsubscribe-button hidden" data-url="${groupUrl}" title="Unsubscribe"></button>
          <div class="dropdown dropdown-group-label">
            <button class="js-subscribe-button" data-url="${projectUrl}"></button>
            <button class="js-subscribe-button js-group-level" data-url="${groupUrl}"></button>
          </div>
        </li>
      </ul>
    `);
    container = document.querySelector('.js-label-subscription');

    // eslint-disable-next-line no-new
    new GroupLabelSubscription(container);
  });

  afterEach(() => {
    mock.restore();
    resetHTMLFixture();
    jest.clearAllMocks();
  });

  describe('subscribing', () => {
    it('posts to the url of the clicked button and swaps the dropdown for the unsubscribe button', async () => {
      mock.onPost(groupUrl).reply(HTTP_STATUS_OK);

      findGroupButton().click();
      await waitForPromises();

      expect(mock.history.post).toHaveLength(1);
      expect(mock.history.post[0].url).toBe(groupUrl);
      expect(isHidden(findDropdown())).toBe(true);
      expect(isHidden(findUnsubscribeButton())).toBe(false);
    });

    it('remembers the url of the clicked button for unsubscribing', async () => {
      mock.onPost(projectUrl).reply(HTTP_STATUS_OK);

      findProjectButton().click();
      await waitForPromises();

      expect(findUnsubscribeButton().getAttribute('data-url')).toBe(projectUrl);
    });

    it('updates the tooltip of the unsubscribe button for a group level subscription', async () => {
      mock.onPost(groupUrl).reply(HTTP_STATUS_OK);

      findGroupButton().click();
      await waitForPromises();

      expect([...hide.mock.calls[0][0]]).toEqual([findUnsubscribeButton()]);
      expect(findUnsubscribeButton().getAttribute('title')).toBe('Unsubscribe at group level');
      expect([...fixTitle.mock.calls[0][0]]).toEqual([findUnsubscribeButton()]);
    });

    it('updates the tooltip of the unsubscribe button for a project level subscription', async () => {
      mock.onPost(projectUrl).reply(HTTP_STATUS_OK);

      findProjectButton().click();
      await waitForPromises();

      expect(findUnsubscribeButton().getAttribute('title')).toBe('Unsubscribe at project level');
    });

    it('shows an alert and keeps the buttons as they are when the request fails', async () => {
      mock.onPost(groupUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      findGroupButton().click();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error when subscribing to this label.',
      });
      expect(isHidden(findDropdown())).toBe(false);
      expect(isHidden(findUnsubscribeButton())).toBe(true);
    });
  });

  describe('unsubscribing', () => {
    beforeEach(() => {
      findDropdown().classList.add('hidden');
      findUnsubscribeButton().classList.remove('hidden');
    });

    it('posts to the stored url, shows the dropdown again and forgets the url', async () => {
      mock.onPost(groupUrl).reply(HTTP_STATUS_OK);

      findUnsubscribeButton().click();
      await waitForPromises();

      expect(mock.history.post[0].url).toBe(groupUrl);
      expect(isHidden(findDropdown())).toBe(false);
      expect(isHidden(findUnsubscribeButton())).toBe(true);
      expect(findUnsubscribeButton().hasAttribute('data-url')).toBe(false);
    });

    it('shows an alert and keeps the buttons as they are when the request fails', async () => {
      mock.onPost(groupUrl).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      findUnsubscribeButton().click();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error when unsubscribing from this label.',
      });
      expect(isHidden(findUnsubscribeButton())).toBe(false);
      expect(findUnsubscribeButton().getAttribute('data-url')).toBe(groupUrl);
    });
  });
});

import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import initAwardsApp from '~/emoji/awards_app';
import { useAwardsApp } from '~/emoji/awards_app/store';
import { EMOJI_THUMBS_UP } from '~/emoji/constants';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { pinia } from '~/pinia/instance';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/vue_shared/components/awards_list.vue', () => ({
  render: () => null,
}));

describe('Awards app', () => {
  let mock;

  beforeEach(() => {
    window.gon = { current_user_id: 1 };
    mock = new MockAdapter(axios);
    mock
      .onGet('/awards')
      .reply(HTTP_STATUS_OK, [{ id: 5, name: EMOJI_THUMBS_UP, user: { id: 1 } }]);
    setHTMLFixture(
      '<div id="js-vue-awards-block" data-path="/awards" data-can-award-emoji="true"></div>',
    );
  });

  afterEach(() => {
    mock.restore();
    resetHTMLFixture();
  });

  it('returns null without an element', () => {
    expect(initAwardsApp(null)).toBeNull();
  });

  it('seeds the store from the dataset and fetches awards', async () => {
    initAwardsApp(document.getElementById('js-vue-awards-block'));
    await waitForPromises();
    await nextTick();

    const store = useAwardsApp(pinia);
    expect(store.path).toBe('/awards');
    expect(store.currentUserId).toBe(1);
    expect(store.canAwardEmoji).toBe(true);
    expect(store.awards).toHaveLength(1);
  });
});

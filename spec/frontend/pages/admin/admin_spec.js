import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { refreshCurrentPage } from '~/lib/utils/url_utility';
import initAdmin from '~/pages/admin/admin';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  refreshCurrentPage: jest.fn(),
}));

describe('pages/admin/admin', () => {
  const findColorsContainers = () => document.querySelectorAll('.js-toggle-colors-container');

  beforeEach(() => {
    setHTMLFixture(`
      <div class="js-toggle-colors-container"><button class="js-toggle-colors-link"><span>Customize colors</span></button></div>
      <div class="js-toggle-colors-container hide"></div>
      <div class="js-toggle-colors-container hide"></div>
      <ul>
        <li class="project_member"></li>
        <li class="group_member"></li>
        <li class="other_member"></li>
      </ul>
    `);

    initAdmin();
  });

  afterEach(() => {
    resetHTMLFixture();
    jest.clearAllMocks();
  });

  describe('colors link', () => {
    it('toggles the hidden state of every colors container', () => {
      document.querySelector('.js-toggle-colors-link span').click();

      expect([...findColorsContainers()].map((el) => el.classList.contains('hide'))).toEqual([
        true,
        false,
        false,
      ]);

      document.querySelector('.js-toggle-colors-link').click();

      expect([...findColorsContainers()].map((el) => el.classList.contains('hide'))).toEqual([
        false,
        true,
        true,
      ]);
    });

    it('prevents the default action of the click', () => {
      const event = new MouseEvent('click', { bubbles: true, cancelable: true });

      document.querySelector('.js-toggle-colors-link').dispatchEvent(event);

      expect(event.defaultPrevented).toBe(true);
    });
  });

  describe('member rows', () => {
    it.each(['.project_member', '.group_member'])(
      'refreshes the page on ajax:success of %s',
      (selector) => {
        document.querySelector(selector).dispatchEvent(new CustomEvent('ajax:success'));

        expect(refreshCurrentPage).toHaveBeenCalledTimes(1);
      },
    );

    it('ignores other rows', () => {
      document.querySelector('.other_member').dispatchEvent(new CustomEvent('ajax:success'));

      expect(refreshCurrentPage).not.toHaveBeenCalled();
    });
  });
});

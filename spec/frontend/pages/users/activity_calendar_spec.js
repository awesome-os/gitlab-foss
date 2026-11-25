import MockAdapter from 'axios-mock-adapter';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import ActivityCalendar, { getLevelFromContributions } from '~/pages/users/activity_calendar';

describe('getLevelFromContributions', () => {
  it.each([
    [0, 0],
    [1, 1],
    [9, 1],
    [10, 2],
    [19, 2],
    [20, 3],
    [30, 4],
    [99, 4],
  ])('.getLevelFromContributions(%i, %i)', (count, expected) => {
    expect(getLevelFromContributions(count)).toBe(expected);
  });
});

describe('ActivityCalendar', () => {
  let container;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
  });

  afterEach(() => {
    container.remove();
  });

  it('passes the clicked day to onClickDay', () => {
    const onClickDay = jest.fn();
    // eslint-disable-next-line no-new
    new ActivityCalendar({ container, timestamps: {}, onClickDay });

    const cells = container.querySelectorAll('.user-contrib-cell');
    cells[cells.length - 1].dispatchEvent(new MouseEvent('click'));

    const today = new Date();
    expect(onClickDay).toHaveBeenCalledWith(
      [today.getFullYear(), today.getMonth() + 1, today.getDate()].join('-'),
    );
  });

  describe('without onClickDay', () => {
    let mock;
    let cell;

    beforeEach(() => {
      mock = new MockAdapter(axios);
      mock.onGet('/calendar_activities').reply(HTTP_STATUS_OK, '<p>Activities</p>');
      container.insertAdjacentHTML(
        'beforeend',
        '<div class="js-activities"></div><div class="js-recent"></div>',
      );

      // eslint-disable-next-line no-new
      new ActivityCalendar({
        container,
        timestamps: {},
        calendarActivitiesPath: '/calendar_activities',
        activitiesContainer: '.js-activities',
        recentActivitiesContainer: '.js-recent',
      });

      const cells = container.querySelectorAll('.user-contrib-cell');
      cell = cells[cells.length - 1];
    });

    afterEach(() => {
      mock.restore();
    });

    it('marks the clicked day as active and loads its activities', async () => {
      cell.dispatchEvent(new MouseEvent('click'));
      await waitForPromises();

      expect(cell.classList.contains('is-active')).toBe(true);
      expect(container.querySelector('.js-activities').textContent).toBe('Activities');
    });

    it('clears the active day on a second click', async () => {
      cell.dispatchEvent(new MouseEvent('click'));
      await waitForPromises();
      cell.dispatchEvent(new MouseEvent('click'));

      expect(cell.classList.contains('is-active')).toBe(false);
      expect(container.querySelector('.js-activities').textContent).toBe('');
    });
  });
});

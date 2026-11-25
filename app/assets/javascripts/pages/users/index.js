import UserCallout from '~/user_callout';
import { initUserAchievements } from '~/profile';
import { initUserActionsApp } from '~/users/profile/actions';
import { initContributionMusic } from '~/easter_eggs/contribution_music';
import UserTabs from './user_tabs';

function initUserProfile(action) {
  // eslint-disable-next-line no-new
  new UserTabs({ parentEl: '.user-profile', action });
}

const { page } = document.body.dataset;
const action = page.split(':')[1];
// Before initUserProfile: mounting the Vue activity calendar replaces the
// element this reads the profile's username from.
initContributionMusic();
initUserProfile(action);
initUserAchievements();
initUserActionsApp();
new UserCallout(); // eslint-disable-line no-new

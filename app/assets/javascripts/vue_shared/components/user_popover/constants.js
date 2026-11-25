import { __ } from '~/locale';

export const USER_POPOVER_DELAY = 200;
export const LONG_STATUS_MESSAGE_LENGTH = 40;
export const WIDE_CHARACTERS_REGEX = /[\u2E80-\u9FFF\uAC00-\uD7AF\uF900-\uFAFF\uFF00-\uFF60]/g;
export const I18N_ERROR_FOLLOW = __(
  'An error occurred while trying to follow this user, please try again.',
);
export const I18N_ERROR_UNFOLLOW = __(
  'An error occurred while trying to unfollow this user, please try again.',
);
export const I18N_USER_BLOCKED = __('User is blocked');
export const I18N_USER_BUSY = __('Busy');
export const I18N_USER_LEARN = __('Learn more about %{name}');
export const I18N_USER_FOLLOW = __('Follow');
export const I18N_USER_UNFOLLOW = __('Unfollow');

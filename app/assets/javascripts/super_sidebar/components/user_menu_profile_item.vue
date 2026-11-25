<script>
import { GlBadge, GlDisclosureDropdownItem, GlTooltip } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { userPath } from '~/lib/utils/path_helpers/user';
import { s__ } from '~/locale';
import UserStatusBubble from '~/vue_shared/components/user_status_bubble.vue';
import { USER_MENU_TRACKING_DEFAULTS } from '../constants';

export default {
  name: 'UserMenuProfileItem',
  i18n: {
    user: {
      busy: s__('UserProfile|Busy'),
    },
  },
  components: {
    GlBadge,
    GlDisclosureDropdownItem,
    GlTooltip,
    UserStatusBubble,
  },
  directives: {
    SafeHtml,
  },
  props: {
    user: {
      required: true,
      type: Object,
    },
  },
  computed: {
    menuItem() {
      return {
        text: this.user.name,
        href: userPath(this.user.username),
        extraAttrs: {
          ...USER_MENU_TRACKING_DEFAULTS,
          'data-track-label': 'user_profile',
          'data-testid': 'user-profile-link',
        },
      };
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown-item :item="menuItem">
    <template #list-item>
      <span class="gl-flex gl-flex-col">
        <span class="gl-flex gl-gap-2">
          <span class="gl-truncate gl-font-bold">
            {{ user.name }}
          </span>
          <gl-badge v-if="user.status.busy" variant="warning">
            {{ $options.i18n.user.busy }}
          </gl-badge>
        </span>

        <span class="gl-break-all gl-text-subtle">@{{ user.username }}</span>

        <user-status-bubble
          v-if="user.status.customized"
          ref="statusTooltipTarget"
          data-testid="user-menu-status"
          class="gl-mt-3"
        >
          <gl-emoji :data-name="user.status.emoji" class="gl-tracking-normal" />
          <span
            v-if="user.status.message_html"
            v-safe-html="user.status.message_html"
            class="gl-truncate"
          ></span>
          <gl-tooltip
            v-if="user.status.message_html"
            :target="() => $refs.statusTooltipTarget"
            placement="bottom"
          >
            <span v-safe-html="user.status.message_html"></span>
          </gl-tooltip>
        </user-status-bubble>
      </span>
    </template>
  </gl-disclosure-dropdown-item>
</template>

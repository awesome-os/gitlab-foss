<script>
import { GlDisclosureDropdownGroup, GlDisclosureDropdownItem } from '@gitlab/ui';
import { __ } from '~/locale';
import Shortcuts from '~/behaviors/shortcuts/shortcuts';
import { keysFor, START_SEARCH_PROJECT_FILE } from '~/behaviors/shortcuts/keybindings';
import { keyboardShortcutsDisabled } from '~/behaviors/shortcuts/shortcuts_disabled';
import { InternalEvents } from '~/tracking';
import { FIND_FILE_BUTTON_CLICK } from '~/tracking/constants';
import { showBlameButton } from '~/repository/utils/storage_info_utils';
import PermalinkDropdownItem from '~/repository/components/header_area/permalink_dropdown_item.vue';

export default {
  name: 'BlobRepositoryActionsGroup',
  components: {
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    PermalinkDropdownItem,
  },
  inject: ['blobInfo'],
  props: {
    permalinkPath: {
      type: String,
      required: true,
    },
    isBinaryFileType: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    findFileShortcutKey() {
      return keysFor(START_SEARCH_PROJECT_FILE)[0];
    },
    shortcutsDisabled() {
      return keyboardShortcutsDisabled();
    },
    isBlameShown() {
      return this.$route.query.blame === '1';
    },
    blameItem() {
      return {
        text: this.isBlameShown ? __('Hide blame') : __('Blame'),
        extraAttrs: {
          'data-testid': 'blame',
        },
      };
    },
    showBlameButton() {
      return !this.isBinaryFileType && showBlameButton(this.blobInfo);
    },
  },
  methods: {
    handleFindFile() {
      InternalEvents.trackEvent(FIND_FILE_BUTTON_CLICK);
      Shortcuts.focusSearchFile();
    },
    handleBlame() {
      const { blame, ...queryWithoutBlame } = this.$route.query;
      let query;

      if (this.isBlameShown) {
        // Like the header toggle, turning blame off keeps the source viewer
        query = { ...queryWithoutBlame, plain: '1' };
      } else {
        query = { ...this.$route.query, blame: '1' };
        InternalEvents.trackEvent('open_blame_viewer_on_blob_page');
      }

      // The header shares the blob viewer's router, which toggles blame when the query changes.
      // Line highlighting can still set the hash outside the router, so read it from window.location.
      this.$router.push({ query, hash: window.location.hash });
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown-group>
    <gl-disclosure-dropdown-item
      :aria-keyshortcuts="findFileShortcutKey"
      data-testid="find"
      class="@md/panel:gl-hidden"
      @action="handleFindFile"
    >
      <template #list-item>
        <span class="gl-flex gl-items-center gl-justify-between">
          <span>{{ __('Find file') }}</span>
          <kbd v-if="findFileShortcutKey && !shortcutsDisabled" class="flat">{{
            findFileShortcutKey
          }}</kbd>
        </span>
      </template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item
      v-if="showBlameButton"
      :item="blameItem"
      class="js-blob-blame-link @sm/panel:gl-hidden"
      data-testid="blame-dropdown-item"
      @action="handleBlame"
    />
    <permalink-dropdown-item :permalink-path="permalinkPath" source="blob" />
  </gl-disclosure-dropdown-group>
</template>

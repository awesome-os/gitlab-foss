// Zen Mode (full screen) textarea
//
/*= provides zen_mode:enter */
/*= provides zen_mode:leave */

import autosize from 'autosize';
import Dropzone from 'dropzone';
import { Mousetrap } from '~/lib/mousetrap';
import { ESC_KEY_CODE } from '~/lib/utils/keycodes';
import { scrollToElement } from '~/lib/utils/scroll_utils';

Dropzone.autoDiscover = false;

const dispatchZenModeEvent = (target, name) =>
  target.dispatchEvent(new CustomEvent(name, { bubbles: true }));

//
// ### Events
//
// Both events are native `CustomEvent`s. Listen to them with `addEventListener`.
//
// `zen_mode:enter`
//
// Fired when the "Edit in fullscreen" link is clicked.
//
// **Synchronicity** Sync
// **Bubbles** Yes
// **Cancelable** No
// **Target** a.js-zen-enter
//
// `zen_mode:leave`
//
// Fired when the "Leave Fullscreen" link is clicked, or when Escape is pressed.
//
// **Synchronicity** Sync
// **Bubbles** Yes
// **Cancelable** No
// **Target** a.js-zen-leave, or `document` when triggered by Escape
//

export default class ZenMode {
  constructor() {
    this.active_backdrop = null;
    this.active_textarea = null;
    this.storedStyle = null;
    this.abortController = new AbortController();
    const { signal } = this.abortController;

    document.addEventListener(
      'click',
      (e) => {
        const enterLink = e.target.closest?.('.js-zen-enter');
        const leaveLink = e.target.closest?.('.js-zen-leave');

        if (enterLink) {
          e.preventDefault();
          dispatchZenModeEvent(enterLink, 'zen_mode:enter');
        } else if (leaveLink) {
          e.preventDefault();
          dispatchZenModeEvent(leaveLink, 'zen_mode:leave');
        }
      },
      { signal },
    );
    document.addEventListener(
      'zen_mode:enter',
      (e) => {
        // Ensure the top bar is not fixed when entering zen mode so it doesn't cover the textarea
        document.querySelectorAll('.js-panel-header-inner').forEach((el) => {
          el.style.position = 'static';
        });
        this.enter(e.target.closest?.('.md-area')?.querySelectorAll('.zen-backdrop') ?? []);
      },
      { signal },
    );
    document.addEventListener(
      'zen_mode:leave',
      () => {
        // Restore the top bar to its original position
        document.querySelectorAll('.js-panel-header-inner').forEach((el) => {
          el.style.position = '';
        });
        this.exit();
      },
      { signal },
    );
    document.addEventListener(
      'keydown',
      (e) => {
        if (e.keyCode === ESC_KEY_CODE) {
          e.preventDefault();
          dispatchZenModeEvent(document, 'zen_mode:leave');
        }
      },
      { signal },
    );
  }

  destroy() {
    this.abortController.abort();
  }

  enter(backdrops) {
    document.body.classList.add('zen-mode-fullscreen');
    Mousetrap.pause();
    this.active_backdrop = Array.from(backdrops);
    this.active_backdrop.forEach((backdrop) => backdrop.classList.add('fullscreen'));
    this.active_textarea = this.active_backdrop.flatMap((backdrop) => [
      ...backdrop.querySelectorAll('textarea'),
    ]);
    // Prevent a user-resized textarea from persisting to fullscreen
    this.storedStyle = this.active_textarea[0]?.getAttribute('style');
    this.active_textarea.forEach((textarea) => {
      textarea.removeAttribute('style');
    });
    this.active_textarea.forEach((textarea) => textarea.focus());
  }

  exit() {
    document.body.classList.remove('zen-mode-fullscreen');
    if (this.active_textarea) {
      Mousetrap.unpause();
      this.active_textarea.forEach((textarea) => {
        textarea.closest('.zen-backdrop')?.classList.remove('fullscreen');
      });
      scrollToElement(this.active_textarea[0], { behavior: 'auto', offset: -100 });
      if (typeof this.storedStyle === 'string') {
        this.active_textarea.forEach((textarea) => {
          textarea.setAttribute('style', this.storedStyle);
        });
      }

      autosize(this.active_textarea);
      autosize.update(this.active_textarea);

      this.active_textarea.forEach((textarea) => textarea.focus());
      this.active_textarea = null;
      this.active_backdrop = null;

      const dropzone = document.querySelector('.div-dropzone');
      if (dropzone && !dropzone.classList.contains('js-invalid-dropzone')) {
        Dropzone.forElement('.div-dropzone').enable();
      }
    }
  }
}

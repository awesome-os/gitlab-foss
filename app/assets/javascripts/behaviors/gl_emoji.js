// The element is defined on every page, but the emoji map and the unicode
// support checks only load once a <gl-emoji> is attached to the document.
class GlEmoji extends HTMLElement {
  connectedCallback() {
    this.initialize();
  }
  initialize() {
    return import(/* webpackChunkName: 'emoji' */ './gl_emoji_render').then(
      ({ default: renderGlEmoji }) => renderGlEmoji(this),
    );
  }
}

export default function installGlEmojiElement() {
  if (!customElements.get('gl-emoji')) {
    customElements.define('gl-emoji', GlEmoji);
  }
}

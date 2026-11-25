import {
  initEmojiMap,
  getEmojiInfo,
  emojiFallbackImageSrc,
  emojiImageTag,
  findCustomEmoji,
} from '../emoji';
import isEmojiUnicodeSupported from '../emoji/support';

export default function renderGlEmoji(element) {
  let emojiUnicode = element.textContent.trim();
  const { fallbackSpriteClass, fallbackSrc } = element.dataset;
  let { name, unicodeVersion } = element.dataset;

  return initEmojiMap().then(() => {
    if (!unicodeVersion) {
      const emojiInfo = getEmojiInfo(name);

      if (emojiInfo) {
        if (name !== emojiInfo.name) {
          ({ name } = emojiInfo);
          element.dataset.name = emojiInfo.name;
        }
        unicodeVersion = emojiInfo.u;
        element.dataset.unicodeVersion = unicodeVersion;

        emojiUnicode = emojiInfo.e;
        element.textContent = emojiInfo.e;

        element.title = emojiInfo.d;
      }
    }

    const isEmojiUnicode =
      element.childNodes &&
      Array.prototype.every.call(element.childNodes, (childNode) => childNode.nodeType === 3);

    const customEmoji = findCustomEmoji(name);
    const hasImageFallback = fallbackSrc?.length > 0;
    const hasCssSpriteFallback = fallbackSpriteClass?.length > 0;

    if (emojiUnicode && isEmojiUnicode && isEmojiUnicodeSupported(emojiUnicode, unicodeVersion)) {
      // noop
    } else if (hasCssSpriteFallback) {
      if (!gon.emoji_sprites_css_added && gon.emoji_sprites_css_path) {
        const emojiSpriteLinkTag = document.createElement('link');
        emojiSpriteLinkTag.setAttribute('rel', 'stylesheet');
        emojiSpriteLinkTag.setAttribute('href', gon.emoji_sprites_css_path);
        document.head.appendChild(emojiSpriteLinkTag);
        gon.emoji_sprites_css_added = true;
      }
      // IE 11 doesn't like adding multiple at once :(
      element.classList.add('emoji-icon');
      element.classList.add(fallbackSpriteClass);
    } else if (hasImageFallback) {
      element.innerHTML = '';
      element.appendChild(emojiImageTag(name, customEmoji?.src || fallbackSrc));
    } else {
      const src = emojiFallbackImageSrc(name);
      element.innerHTML = '';
      element.appendChild(emojiImageTag(name, src));
    }
  });
}

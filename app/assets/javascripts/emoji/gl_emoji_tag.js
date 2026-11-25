import { escape } from 'lodash-es';

/**
 * Builds <gl-emoji> markup without loading the emoji map or aliases.
 * The element resolves aliases itself when it renders, so `name` can be
 * an alias. Use `glEmojiTag` from `~/emoji` if the markup needs the
 * normalized name up front.
 */
export function buildGlEmojiTag(name, options) {
  const opts = { sprite: false, ...options };
  const fallbackSpriteClass = `emoji-${name}`;

  const fallbackSpriteAttribute = opts.sprite
    ? `data-fallback-sprite-class="${escape(fallbackSpriteClass)}" `
    : '';

  const fallbackUrl = opts.url;
  const fallbackSrcAttribute = fallbackUrl
    ? `data-fallback-src="${escape(fallbackUrl)}" data-unicode-version="custom"`
    : '';

  return `<gl-emoji ${fallbackSrcAttribute}${fallbackSpriteAttribute}data-name="${escape(
    name,
  )}"></gl-emoji>`;
}

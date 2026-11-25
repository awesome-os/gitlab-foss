import { buildGlEmojiTag } from '~/emoji/gl_emoji_tag';

describe('buildGlEmojiTag', () => {
  it('builds markup with the name', () => {
    expect(buildGlEmojiTag('bomb')).toBe('<gl-emoji data-name="bomb"></gl-emoji>');
  });

  it('keeps an alias as given, for the element to resolve when it renders', () => {
    expect(buildGlEmojiTag('person_with_ball')).toBe(
      '<gl-emoji data-name="person_with_ball"></gl-emoji>',
    );
  });

  it('adds the sprite fallback class', () => {
    expect(buildGlEmojiTag('bomb', { sprite: true })).toBe(
      '<gl-emoji data-fallback-sprite-class="emoji-bomb" data-name="bomb"></gl-emoji>',
    );
  });

  it('escapes the name and fallback URL #security', () => {
    const markup = buildGlEmojiTag('"x" onload="alert(1)"', { url: '" onload="alert(1)' });

    expect(markup).toContain('data-fallback-src="&quot; onload=&quot;alert(1)"');
    expect(markup).toContain('data-name="&quot;x&quot; onload=&quot;alert(1)&quot;"');
  });
});

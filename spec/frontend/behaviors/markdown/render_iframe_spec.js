import { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import { resetHTMLFixture } from 'helpers/fixtures';
import { iframeProviders, YOUTUBE_SANDBOX, FIGMA_SANDBOX } from 'helpers/iframe_providers';
import {
  YOUTUBE_URL,
  YOUTUBE_EMBED_URL,
  buildParagraphWithIframeEmbed,
} from 'helpers/iframe_embeds';
import renderIframes, {
  iframeEmbedFor,
  isIframeProviderHost,
} from '~/behaviors/markdown/render_iframe';
import { CopyAsGFM } from '~/behaviors/markdown/copy_as_gfm';

describe('Embedded iframe renderer', () => {
  const findEmbeddedIframes = (src = null) => {
    const iframes = document.querySelectorAll('iframe');
    if (src === null) return iframes;

    return Array.from(iframes).filter((iframe) => iframe.src === src);
  };

  const renderAllIframes = () => {
    renderIframes([...document.querySelectorAll('.js-render-iframe')]);
    jest.runAllTimers();
  };

  const mountEmbed = (options) => document.body.append(buildParagraphWithIframeEmbed(options));

  const findContainer = () => document.querySelector('.js-render-iframe');
  const findFallbackLink = () => document.querySelector('.js-render-iframe > a');
  const findWarning = () => document.querySelector('[data-testid="external-content-warning"]');
  const findOpenInNewTab = () =>
    document.querySelector('[data-testid="external-content-open-in-new-tab"]');
  const findActivationButton = () =>
    document.querySelector('[data-testid="activate-external-content"]');
  const findPlaceholder = () =>
    document.querySelector('[data-testid="external-content-placeholder"]');

  beforeEach(() => {
    window.gon = {
      iframe_rendering_providers: iframeProviders(),
    };
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('renders an embedded iframe', () => {
    mountEmbed();

    expect(findEmbeddedIframes()).toHaveLength(0);

    renderAllIframes();

    expect(findEmbeddedIframes(YOUTUBE_EMBED_URL)).toHaveLength(1);
  });

  it("applies the provider's sandbox", () => {
    mountEmbed();

    renderAllIframes();

    expect(findEmbeddedIframes(YOUTUBE_EMBED_URL)[0].getAttribute('sandbox')).toBe(YOUTUBE_SANDBOX);
  });

  it("applies the matched provider's sandbox", async () => {
    const figmaEmbedUrl = 'https://embed.figma.com/design/abc?embed-host=gitlab';
    mountEmbed({
      src: figmaEmbedUrl,
      canonicalSrc: 'https://www.figma.com/design/abc',
      viewUrl: 'https://www.figma.com/design/abc',
      providerId: 'figma',
    });

    renderAllIframes();
    findActivationButton().click();
    await nextTick();

    expect(findEmbeddedIframes(figmaEmbedUrl)[0].getAttribute('sandbox')).toBe(FIGMA_SANDBOX);
  });

  it('warns that the content is external', () => {
    mountEmbed();

    renderAllIframes();

    expect(findWarning().textContent).toContain(
      'You are viewing external content from www.youtube.com. GitLab does not control this content.',
    );
  });

  it("links to the provider's view URL in a new tab, not the canonical source #security", () => {
    mountEmbed({ canonicalSrc: 'https://example.com\\@www.youtube.com/embed/FIWD2qvNQHM' });

    renderAllIframes();

    expect(findOpenInNewTab().getAttribute('href')).toBe(YOUTUBE_URL);
  });

  it('renders the embed inside the container', () => {
    mountEmbed();

    renderAllIframes();

    expect(findContainer().contains(findEmbeddedIframes(YOUTUBE_EMBED_URL)[0])).toBe(true);
  });

  it('removes the fallback link', () => {
    mountEmbed();
    const link = findFallbackLink();

    renderAllIframes();

    expect(link.isConnected).toBe(false);
  });

  describe('when the rendered embed is copied', () => {
    const copySelection = () => {
      const fragment = document.createDocumentFragment();
      fragment.appendChild(document.querySelector('p').cloneNode(true));
      return CopyAsGFM.transformGFMSelection(fragment);
    };

    beforeEach(() => {
      mountEmbed();
      renderAllIframes();
    });

    it('copies no plain text', () => {
      expect(copySelection().textContent.trim()).toBe('');
    });

    it('copies the embed as GFM', async () => {
      expect(await CopyAsGFM.nodeToGFM(copySelection())).toBe(
        `![YouTube embed](${YOUTUBE_EMBED_URL})`,
      );
    });
  });

  it('names the frame after the provider and host', () => {
    mountEmbed();

    renderAllIframes();

    expect(findEmbeddedIframes(YOUTUBE_EMBED_URL)[0].getAttribute('title')).toBe(
      'External content from YouTube (www.youtube.com)',
    );
  });

  describe('when the provider requires activation', () => {
    beforeEach(() => {
      mountEmbed();
      window.gon.iframe_rendering_providers.youtube.require_activation = true;
      renderAllIframes();
    });

    it('does not load the iframe', () => {
      expect(findEmbeddedIframes()).toHaveLength(0);
    });

    it('does not warn yet', () => {
      expect(findWarning()).toBeNull();
    });

    it('shows an activation button', () => {
      expect(findActivationButton().textContent.trim()).toBe('Load external content');
    });

    it('sizes the placeholder like the default iframe', () => {
      expect(findPlaceholder().style.width).toBe('560px');
    });

    describe('when the user activates the content', () => {
      beforeEach(async () => {
        findActivationButton().click();
        await waitForPromises();
      });

      it('loads the iframe', () => {
        expect(findEmbeddedIframes(YOUTUBE_EMBED_URL)).toHaveLength(1);
      });

      it('moves focus to the iframe', () => {
        expect(document.activeElement).toBe(findEmbeddedIframes(YOUTUBE_EMBED_URL)[0]);
      });

      it('removes the activation button', () => {
        expect(findActivationButton()).toBeNull();
      });

      it('warns that the content is external', () => {
        expect(findWarning()).not.toBeNull();
      });
    });
  });

  describe('when the provider is no longer enabled', () => {
    beforeEach(() => {
      mountEmbed();
      window.gon.iframe_rendering_providers = { figma: iframeProviders().figma };
    });

    it('does not render an embedded iframe and keeps the fallback link', () => {
      renderAllIframes();

      expect(findEmbeddedIframes()).toHaveLength(0);
      expect(findFallbackLink().getAttribute('href')).toBe(YOUTUBE_URL);
    });
  });

  describe("when the src does not match the provider's src template", () => {
    it.each`
      description                            | src                                                | providerId
      ${"another provider's src"}            | ${YOUTUBE_EMBED_URL}                               | ${'figma'}
      ${'a different path on its host'}      | ${'https://www.youtube.com/watch?v=FIWD2qvNQHM'}   | ${'youtube'}
      ${'extra path segments'}               | ${`${YOUTUBE_EMBED_URL}/extra`}                    | ${'youtube'}
      ${'an extra query'}                    | ${`${YOUTUBE_EMBED_URL}?autoplay=1`}               | ${'youtube'}
      ${'a reserved character'}              | ${'https://www.youtube.com/embed/abc&autoplay=1'}  | ${'youtube'}
      ${'a missing literal query'}           | ${'https://embed.figma.com/design/abc'}            | ${'figma'}
      ${'userinfo'}                          | ${'https://example.com@www.youtube.com/embed/abc'} | ${'youtube'}
      ${'a prefix before the src #security'} | ${'https://x/?https://www.youtube.com/embed/abc'}  | ${'youtube'}
    `('does not render $description and keeps the fallback link', ({ src, providerId }) => {
      mountEmbed({ src, providerId });

      renderAllIframes();

      expect(findEmbeddedIframes()).toHaveLength(0);
      expect(findFallbackLink().getAttribute('href')).toBe(YOUTUBE_URL);
    });
  });

  it('does not render an embedded iframe when the instance-wide setting is disabled', () => {
    mountEmbed();

    window.gon.iframe_rendering_providers = null;

    renderAllIframes();

    expect(findEmbeddedIframes()).toHaveLength(0);
  });

  describe('dimensions', () => {
    const findIframe = () => findEmbeddedIframes(YOUTUBE_EMBED_URL)[0];

    describe('for any embed', () => {
      beforeEach(() => {
        mountEmbed();
        renderAllIframes();
      });

      it('keeps the embed within its container, with a floor that yields to it', () => {
        const { style } = findIframe().parentElement;
        expect(style.maxWidth).toBe('100%');
        expect(style.minWidth).toBe('min(17rem, 100%)');
      });

      it('fills the embed with the iframe', () => {
        expect(findIframe().classList.contains('gl-min-w-full')).toBe(true);
      });
    });

    describe('when both width and height are provided', () => {
      beforeEach(() => {
        mountEmbed({ width: '560', height: '315' });
        renderAllIframes();
      });

      it('applies explicit width and height attributes', () => {
        const iframe = findIframe();
        expect(iframe).toBeDefined();
        expect(iframe.getAttribute('width')).toBe('560');
        expect(iframe.getAttribute('height')).toBe('315');
      });

      it('caps width to container and height to the requested height', () => {
        const iframe = findIframe();
        expect(iframe.style.maxWidth).toBe('100%');
        expect(iframe.style.maxHeight).toBe('min(80vh, 315px)');
        expect(iframe.style.height).toBe('auto');
      });
    });

    describe('when only width is provided', () => {
      beforeEach(() => {
        mountEmbed({ width: '560' });
        renderAllIframes();
      });

      it('caps width to container without aspect-ratio', () => {
        const iframe = findIframe();
        expect(iframe.getAttribute('width')).toBe('560');
        expect(iframe.getAttribute('height')).toBeNull();
        expect(iframe.style.maxWidth).toBe('100%');
        expect(iframe.style.maxHeight).toBe('80vh');
        expect(iframe.style.height).toBe('');
      });
    });

    describe('when no dimensions are provided', () => {
      beforeEach(() => {
        mountEmbed();
        renderAllIframes();
      });

      it('defaults to 560 by 315', () => {
        const iframe = findIframe();
        expect(iframe.getAttribute('width')).toBe('560');
        expect(iframe.getAttribute('height')).toBe('315');
        expect(iframe.style.maxHeight).toBe('min(80vh, 315px)');
        expect(iframe.style.height).toBe('auto');
      });
    });
  });

  describe('iframeEmbedFor', () => {
    it.each`
      src                                                           | providerId   | viewUrl
      ${YOUTUBE_EMBED_URL}                                          | ${'youtube'} | ${YOUTUBE_URL}
      ${'https://www.youtube.com/embed/abc%26autoplay%3D1'}         | ${'youtube'} | ${'https://www.youtube.com/watch?v=abc%26autoplay%3D1'}
      ${'https://embed.figma.com/proto/a-b.c_d~?embed-host=gitlab'} | ${'figma'}   | ${'https://www.figma.com/proto/a-b.c_d~'}
    `('derives $viewUrl from $src', ({ src, providerId, viewUrl }) => {
      expect(iframeEmbedFor(src, providerId)).toEqual({
        provider: iframeProviders()[providerId],
        viewUrl,
      });
    });

    describe('when the src template repeats a placeholder', () => {
      beforeEach(() => {
        window.gon.iframe_rendering_providers.youtube.src_template =
          'https://www.youtube.com/embed/{v}/{v}';
      });

      it('derives the view URL when the captures agree', () => {
        expect(iframeEmbedFor(`${YOUTUBE_EMBED_URL}/FIWD2qvNQHM`, 'youtube').viewUrl).toBe(
          YOUTUBE_URL,
        );
      });

      it('returns null when the captures disagree', () => {
        expect(iframeEmbedFor(`${YOUTUBE_EMBED_URL}/other`, 'youtube')).toBeNull();
      });
    });

    it('returns null for an unknown provider', () => {
      expect(iframeEmbedFor(YOUTUBE_EMBED_URL, 'toString')).toBeNull();
    });
  });

  describe('isIframeProviderHost', () => {
    it.each`
      description                                   | url                                      | expected
      ${'a URL on a provider host'}                 | ${'https://www.youtube.com/watch?v=xyz'} | ${true}
      ${"a URL on another of the provider's hosts"} | ${'https://youtu.be/xyz'}                | ${true}
      ${'a URL on a host no provider matches'}      | ${'https://example.com/watch?v=xyz'}     | ${false}
      ${'a relative URL'}                           | ${'/uploads/video.mp4'}                  | ${false}
      ${'an unparseable URL'}                       | ${'https://['}                           | ${false}
    `('returns $expected for $description', ({ url, expected }) => {
      expect(isIframeProviderHost(url)).toBe(expected);
    });
  });
});

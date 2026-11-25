import fixture from 'test_fixtures/iframe_embeds/cases.json';
import { iframeEmbedFor } from '~/behaviors/markdown/render_iframe';

describe('iframe embeds rendered by the backend', () => {
  const findEmbed = (html) =>
    new DOMParser().parseFromString(html, 'text/html').querySelector('.js-render-iframe');

  beforeEach(() => {
    window.gon = {
      iframe_rendering_providers: fixture.providers,
    };
  });

  describe('when the backend embeds the URL', () => {
    describe.each(fixture.cases.filter(({ embeds }) => embeds))(
      'in $form form: $input',
      ({ html }) => {
        let embed;

        beforeEach(() => {
          embed = findEmbed(html);
        });

        it("has a canonical source the browser parses as one of the provider's hosts #security", () => {
          const { iframeCanonicalSrc, iframeProviderId } = embed.dataset;

          expect(fixture.providers[iframeProviderId].match_hosts).toContain(
            new URL(iframeCanonicalSrc).host,
          );
        });

        it('falls back to the view URL that the frontend derives from its src', () => {
          const { iframeSrc, iframeProviderId } = embed.dataset;

          expect(embed.querySelector('a').getAttribute('href')).toBe(
            iframeEmbedFor(iframeSrc, iframeProviderId).viewUrl,
          );
        });
      },
    );
  });
});

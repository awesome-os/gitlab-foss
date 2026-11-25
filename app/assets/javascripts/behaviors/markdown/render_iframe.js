import { escapeRegExp, isEmpty } from 'lodash-es';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { pageSingleton } from '~/lib/utils/page_singleton';
import EmbeddedIframe from '../components/embedded_iframe.vue';

export const iframeRenderingEnabled = () => !isEmpty(window.gon?.iframe_rendering_providers);

export const enabledIframeProviderNames = () =>
  Object.values(window.gon.iframe_rendering_providers).map(({ name }) => name);

const parseUrl = (src) => {
  try {
    return new URL(src, window.location.origin);
  } catch {
    return null;
  }
};

const PLACEHOLDER = /\{(\w+)\}/g;
const ENCODED_CAPTURE = '([A-Za-z0-9\\-._~%]+)';

const matchTemplate = (template, url) => {
  const names = [];
  const pattern = template
    .split(PLACEHOLDER)
    .map((part, index) => {
      if (index % 2 === 0) return escapeRegExp(part);

      names.push(part);
      return ENCODED_CAPTURE;
    })
    .join('');

  const match = new RegExp(`^${pattern}$`).exec(url);
  if (!match) return null;

  const captures = {};
  const consistent = names.every((name, index) => {
    const value = match[index + 1];
    if (Object.prototype.hasOwnProperty.call(captures, name)) return captures[name] === value;

    captures[name] = value;
    return true;
  });

  return consistent ? captures : null;
};

const expandTemplate = (template, captures) =>
  template.replace(PLACEHOLDER, (_, name) => captures[name]);

export const isIframeProviderHost = (url) => {
  const hostname = parseUrl(url)?.hostname;

  return Object.values(window.gon.iframe_rendering_providers).some(({ match_hosts: matchHosts }) =>
    matchHosts.includes(hostname),
  );
};

export const iframeEmbedFor = (src, providerId) => {
  if (!iframeRenderingEnabled()) return null;

  const providers = window.gon.iframe_rendering_providers;
  if (!Object.prototype.hasOwnProperty.call(providers, providerId)) return null;

  const provider = providers[providerId];
  const captures = matchTemplate(provider.src_template, src);
  if (!captures) return null;

  return { provider, viewUrl: expandTemplate(provider.view_template, captures) };
};

export const isIframeSrcAllowed = (src, providerId) => Boolean(iframeEmbedFor(src, providerId));

const elsProcessingMap = pageSingleton('render_iframe_els', () => new WeakMap());

function renderIframeEl(el) {
  const { iframeSrc: src, iframeProviderId, width, height } = el.dataset;

  const embed = iframeEmbedFor(src, iframeProviderId);
  if (!embed) return;

  const mountEl = document.createElement('div');
  el.replaceChildren(mountEl);

  initVueApp({
    el: mountEl,
    name: 'EmbeddedIframeRoot',
    component: EmbeddedIframe,
    props: { provider: embed.provider, src, viewUrl: embed.viewUrl, width, height },
  });
}

export default function renderIframes(els) {
  if (!iframeRenderingEnabled()) return;

  if (!els.length) return;

  els.forEach((el) => {
    if (elsProcessingMap.has(el)) {
      return;
    }

    const requestId = window.requestIdleCallback(() => {
      renderIframeEl(el);
    });

    elsProcessingMap.set(el, requestId);
  });
}

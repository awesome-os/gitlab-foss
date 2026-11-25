import { getDraft, clearDraft } from '~/lib/utils/autosave';

export function isTemplate() {
  // eslint-disable-next-line @gitlab/no-hardcoded-urls -- Boolean check, not generating a URL
  return window.location.href.includes('/wikis/templates');
}

function deslugify(slug) {
  return slug.replace(/-+/g, ' ');
}

export function sidebarEntriesToTree(entries) {
  if (!entries.length) return [];

  const regex = new RegExp(`${entries[0].slug.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')}$`);
  const rootPath = entries[0].path.replace(regex, '');
  const entriesMap = entries.reduce((acc, entry) => {
    acc[entry.slug] = entry;
    return acc;
  }, {});

  return entries
    .sort(({ slug: slugA }, { slug: slugB }) => {
      return slugA.localeCompare(slugB, undefined, {
        numeric: true,
        sensitivity: 'base',
      });
    })
    .reduce((acc, entry) => {
      const parts = entry.slug.split('/');
      let parent = acc;

      for (let i = 0; i < parts.length; i += 1) {
        const part = parts[i];
        const subSlug = parts.slice(0, i + 1).join('/');
        const existing = parent.find((child) => child.slug === subSlug);

        if (existing) {
          parent = existing.children;
        } else {
          const subEntry = entriesMap[subSlug];
          const node = {
            slug: subSlug,
            path: subEntry?.path || `${rootPath}${subSlug}`,
            title: subEntry?.title || deslugify(part),
            children: [],
          };

          parent.push(node);
          parent = node.children;
        }
      }

      return acc;
    }, []);
}

const DRAFT_FIELDS = ['title', 'format', 'content', 'commit'];

// Front matter is passed through raw, so the title can be any YAML value. Like
// WikiPage#front_matter_title, only strings and numbers count as a title.
export const getUpstreamTitle = (pageInfo, frontMatter) => {
  const title = frontMatter?.title;
  const frontMatterTitle =
    typeof title === 'string' || typeof title === 'number' ? String(title).trim() : '';

  return frontMatterTitle || pageInfo.title?.trim() || '';
};

// The server saves LF, but pages written before that or pushed over Git can hold CRLF.
// Trimmed, so edits to leading or trailing whitespace alone count as saved and get cleared.
const normalizeDraftField = (text) => text.replace(/\r\n?/g, '\n').trim();

const draftFieldMatches = (path, field, upstream) => {
  const draft = getDraft(`${path}/${field}`);
  return draft === null || normalizeDraftField(draft) === normalizeDraftField(upstream);
};

// Drafts are written on every submit, so a successful save leaves one behind that matches the page.
export const draftMatchesPage = (path, pageInfo) =>
  draftFieldMatches(path, 'title', getUpstreamTitle(pageInfo, pageInfo.frontMatter)) &&
  draftFieldMatches(path, 'content', pageInfo.content || '') &&
  draftFieldMatches(path, 'format', pageInfo.format || 'markdown');

export const clearDraftsAt = (path) => {
  DRAFT_FIELDS.forEach((field) => clearDraft(`${path}/${field}`));
};

import { draftMatchesPage, getUpstreamTitle, sidebarEntriesToTree } from '~/wikis/utils';

describe('sidebarEntriesToTree', () => {
  it('returns an empty array if entries are empty', () => {
    expect(sidebarEntriesToTree([])).toEqual([]);
  });

  it('returns a tree structure from sidebar entries', () => {
    const entries = [
      { slug: 'foo/bak', path: '/foo/bak', title: 'Bak' },
      { slug: 'foo', path: '/foo', title: 'Foo' },
      { slug: 'foo/bar', path: '/foo/bar', title: 'Bar' },
      { slug: 'foo/baz', path: '/foo/baz', title: 'Baz' },
      { slug: 'bar', path: '/bar', title: 'Bar' },
      { slug: 'bar/foo/baz', path: '/bar/foo/baz', title: 'Baz' },
      { slug: 'foo-bar-baz/baz', path: '/foo-bar-baz/baz', title: 'Baz' },
      { slug: 'foo/bat', path: '/foo/bat', title: 'Bat' },
      { slug: 'a/b/c/d/e/f/g', path: '/a/b/c/d/e/f/g', title: 'G' },
    ];

    expect(sidebarEntriesToTree(entries)).toMatchObject([
      {
        slug: 'a',
        path: '/a',
        title: 'a',
        children: [
          {
            slug: 'a/b',
            path: '/a/b',
            title: 'b',
            children: [
              {
                slug: 'a/b/c',
                path: '/a/b/c',
                title: 'c',
                children: [
                  {
                    slug: 'a/b/c/d',
                    path: '/a/b/c/d',
                    title: 'd',
                    children: [
                      {
                        slug: 'a/b/c/d/e',
                        path: '/a/b/c/d/e',
                        title: 'e',
                        children: [
                          {
                            slug: 'a/b/c/d/e/f',
                            path: '/a/b/c/d/e/f',
                            title: 'f',
                            children: [
                              { slug: 'a/b/c/d/e/f/g', path: '/a/b/c/d/e/f/g', title: 'G' },
                            ],
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        slug: 'bar',
        path: '/bar',
        title: 'Bar',
        children: [
          {
            slug: 'bar/foo',
            path: '/bar/foo',
            title: 'foo',
            children: [{ slug: 'bar/foo/baz', path: '/bar/foo/baz', title: 'Baz' }],
          },
        ],
      },
      {
        slug: 'foo',
        path: '/foo',
        title: 'Foo',
        children: [
          { slug: 'foo/bak', path: '/foo/bak', title: 'Bak' },
          { slug: 'foo/bar', path: '/foo/bar', title: 'Bar' },
          { slug: 'foo/bat', path: '/foo/bat', title: 'Bat' },
          { slug: 'foo/baz', path: '/foo/baz', title: 'Baz' },
        ],
      },
      {
        slug: 'foo-bar-baz',
        path: '/foo-bar-baz',
        title: 'foo bar baz',
        children: [{ slug: 'foo-bar-baz/baz', path: '/foo-bar-baz/baz', title: 'Baz' }],
      },
    ]);
  });

  it('works properly even if the slugs contain special characters and emojis', () => {
    const entries = [
      { path: '/00-START-HERE-:-)', slug: '00-START-HERE-:-)', title: '00 START HERE : )' },
      {
        path: '/Page-that-should-break-the-sidebar-)',
        slug: 'Page-that-should-break-the-sidebar-)',
        title: 'Page that should break the sidebar )',
      },
      {
        path: '/What-about-this-/-new-subpage',
        slug: 'What-about-this-/-new-subpage',
        title: 'these subpages seems working just fine',
      },
      {
        path: '/What-about-utf-%F0%9F%A4%AC',
        slug: 'What-about-utf-🤬',
        title: 'What about utf 🤬',
      },
      { path: '/home', slug: 'home', title: 'Home' },
      { path: '/-not-trimmed-', slug: '-not-trimmed-', title: ' Not trimmed ' },
    ];

    expect(sidebarEntriesToTree(entries)).toMatchObject([
      { path: '/-not-trimmed-', slug: '-not-trimmed-', title: ' Not trimmed ' },
      { slug: '00-START-HERE-:-)', path: '/00-START-HERE-:-)', title: '00 START HERE : )' },
      { slug: 'home', path: '/home', title: 'Home' },
      {
        slug: 'Page-that-should-break-the-sidebar-)',
        path: '/Page-that-should-break-the-sidebar-)',
        title: 'Page that should break the sidebar )',
      },
      {
        slug: 'What-about-this-',
        path: '/What-about-this-',
        title: 'What about this ',
        children: [
          {
            slug: 'What-about-this-/-new-subpage',
            path: '/What-about-this-/-new-subpage',
            title: 'these subpages seems working just fine',
          },
        ],
      },
      {
        slug: 'What-about-utf-🤬',
        path: '/What-about-utf-%F0%9F%A4%AC',
        title: 'What about utf 🤬',
      },
    ]);
  });
});

describe('draftMatchesPage', () => {
  const path = '/project/path/-/wikis/home';
  const pageInfo = {
    title: 'My page',
    content: 'First line\r\n\r\nSecond line\r\n',
    format: 'markdown',
  };

  const seedDraft = ({ title = 'My page', content, format = 'markdown' }) => {
    localStorage.setItem(`autosave/${path}/title`, title);
    localStorage.setItem(`autosave/${path}/content`, content);
    localStorage.setItem(`autosave/${path}/format`, format);
  };

  afterEach(() => {
    localStorage.clear();
  });

  it('matches when there are no drafts', () => {
    expect(draftMatchesPage(path, pageInfo)).toBe(true);
  });

  it('matches an LF draft against a CRLF page with the same content', () => {
    seedDraft({ content: 'First line\n\nSecond line\n' });

    expect(draftMatchesPage(path, pageInfo)).toBe(true);
  });

  it('matches a draft that differs only in leading or trailing whitespace', () => {
    seedDraft({ title: ' My page ', content: '\nFirst line\n\nSecond line' });

    expect(draftMatchesPage(path, pageInfo)).toBe(true);
  });

  it('does not match a draft with different content', () => {
    seedDraft({ content: 'First line\n\nChanged second line\n' });

    expect(draftMatchesPage(path, pageInfo)).toBe(false);
  });

  it('does not match a draft with a different title', () => {
    seedDraft({ title: 'Other title', content: 'First line\n\nSecond line\n' });

    expect(draftMatchesPage(path, pageInfo)).toBe(false);
  });

  it('compares the title with the front matter title when there is one', () => {
    seedDraft({ title: 'Their title', content: 'First line\n\nSecond line\n' });

    expect(draftMatchesPage(path, { ...pageInfo, frontMatter: { title: 'Their title' } })).toBe(
      true,
    );
  });
});

describe('getUpstreamTitle', () => {
  const pageInfo = { title: ' page-slug ' };

  it.each`
    title               | expected
    ${' Their title '}  | ${'Their title'}
    ${42}               | ${'42'}
    ${true}             | ${'page-slug'}
    ${['one', 'two']}   | ${'page-slug'}
    ${{ key: 'value' }} | ${'page-slug'}
    ${null}             | ${'page-slug'}
    ${'  '}             | ${'page-slug'}
  `('returns $expected when the front matter title is $title', ({ title, expected }) => {
    expect(getUpstreamTitle(pageInfo, { title })).toBe(expected);
  });

  it('falls back to the page title without front matter', () => {
    expect(getUpstreamTitle(pageInfo)).toBe('page-slug');
  });
});

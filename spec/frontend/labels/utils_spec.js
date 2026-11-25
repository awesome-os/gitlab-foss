import { filterLabelsByTitle } from '~/labels/utils';

const toLabels = (titles) => titles.map((title) => ({ title }));
const titlesFor = (titles, query) =>
  filterLabelsByTitle(toLabels(titles), query).map((l) => l.title);

describe('filterLabelsByTitle', () => {
  it.each`
    query           | titles                                                        | expected
    ${'ux'}         | ${['UX debt', 'ux::research', 'UX']}                          | ${['UX', 'ux::research', 'UX debt']}
    ${'enterprise'} | ${['enterprise readiness', 'Enterprise']}                     | ${['Enterprise', 'enterprise readiness']}
    ${'toast'}      | ${['S_TOAST_1', 'S_TOAST_2', 'Toast']}                        | ${['Toast', 'S_TOAST_1', 'S_TOAST_2']}
    ${'Customer'}   | ${['Customer Success::Impact Check', 'customer', 'Customer']} | ${['Customer', 'customer', 'Customer Success::Impact Check']}
    ${'ux '}        | ${['ux::research', 'UX']}                                     | ${['UX', 'ux::research']}
  `(
    'ranks exact title matches for "$query" first, ignoring case',
    ({ query, titles, expected }) => {
      expect(titlesFor(titles, query)).toEqual(expected);
    },
  );

  it('keeps the fuzzy ranking when nothing matches exactly', () => {
    expect(titlesFor(['ux::research', 'UX debt', 'Frontend'], 'ux')).toEqual([
      'ux::research',
      'UX debt',
    ]);
  });

  it('drops labels that do not match', () => {
    expect(titlesFor(['Backend', 'Frontend'], 'docs')).toEqual([]);
  });
});

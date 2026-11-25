import fuzzaldrinPlus from 'fuzzaldrin-plus';

// fuzzaldrin-plus favours a case-sensitive prefix (`ux` ranks `ux::research` above `UX`),
// so titles equal to the query, ignoring case, are moved to the front.
export const filterLabelsByTitle = (labels, query) => {
  const matches = fuzzaldrinPlus.filter(labels, query, { key: 'title' });
  const needle = query.trim().toLocaleLowerCase();
  const isExact = (label) => String(label.title).toLocaleLowerCase() === needle;

  return [
    ...matches.filter((label) => isExact(label)),
    ...matches.filter((label) => !isExact(label)),
  ];
};

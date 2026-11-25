import { commitAuthor, commitCommitter } from '~/commit/utils/attribution';

describe('commit attribution utils', () => {
  const commit = {
    authorName: 'Duo Agent',
    authorEmail: 'duo@example.com',
    authoredDate: '2025-06-23T18:03:33+00:00',
    author: { name: 'GitLab Duo', webPath: '/duo' },
    committerName: 'Jane Doe',
    committerEmail: 'jane@example.com',
    committedDate: '2025-06-24T09:00:00+00:00',
  };

  it('maps the git author, linking to the GitLab user', () => {
    expect(commitAuthor(commit)).toEqual({
      name: 'Duo Agent',
      email: 'duo@example.com',
      date: '2025-06-23T18:03:33+00:00',
      webPath: '/duo',
    });
  });

  it.each`
    case                             | author
    ${'no GitLab user matches'}      | ${null}
    ${'the GitLab user is an agent'} | ${{ name: 'GitLab Duo', webPath: '/duo', bot: true }}
  `('maps the git author without a link when $case', ({ author }) => {
    expect(commitAuthor({ ...commit, author }).webPath).toBeUndefined();
  });

  it('maps the git committer', () => {
    expect(commitCommitter(commit)).toEqual({
      name: 'Jane Doe',
      email: 'jane@example.com',
      date: '2025-06-24T09:00:00+00:00',
    });
  });
});

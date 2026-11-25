// Git names on both sides, so CommitAttribution compares like with like:
// the GitLab user's display name can differ from the git author name.
// Agent authors stay plain text, so only people link to a profile.
export const commitAuthor = (commit) => ({
  name: commit.authorName,
  email: commit.authorEmail,
  date: commit.authoredDate,
  webPath: commit.author?.bot ? undefined : commit.author?.webPath,
});

export const commitCommitter = (commit) => ({
  name: commit.committerName,
  email: commit.committerEmail,
  date: commit.committedDate,
});

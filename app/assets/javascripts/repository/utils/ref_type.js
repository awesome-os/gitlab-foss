const REF_TYPES = ['heads', 'tags'];

export const getRefType = (refType) => {
  if (!refType) return null;

  const type = REF_TYPES.find((t) => t === refType?.toLowerCase());

  return type?.toUpperCase() || null;
};

const FULL_COMMIT_SHA_REGEX = /^([0-9a-f]{40}|[0-9a-f]{64})$/i;

export const isCommitSha = (ref) => FULL_COMMIT_SHA_REGEX.test(ref);

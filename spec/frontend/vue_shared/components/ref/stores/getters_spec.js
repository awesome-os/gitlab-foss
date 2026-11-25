import * as getters from '~/vue_shared/components/ref/stores/getters';

describe('Ref selector Vuex store getters', () => {
  describe('isQueryPossiblyASha', () => {
    // Lengths 41-64 are accepted too, as possible SHA-256 prefixes.
    it.each`
      query                                                                  | isPossiblyASha
      ${'abcd'}                                                              | ${true}
      ${'ABCD'}                                                              | ${true}
      ${'0123456789abcdef0123456789abcdef01234567'}                          | ${true}
      ${'0123456789abcdef0123456789abcdef012345678'}                         | ${true}
      ${'0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'}  | ${true}
      ${'0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef'}  | ${true}
      ${'0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0'} | ${false}
      ${'abc'}                                                               | ${false}
      ${'ghij'}                                                              | ${false}
      ${' abcd'}                                                             | ${false}
      ${''}                                                                  | ${false}
      ${null}                                                                | ${false}
      ${undefined}                                                           | ${false}
    `(
      'returns true when the query potentially refers to a commit SHA',
      ({ query, isPossiblyASha }) => {
        expect(getters.isQueryPossiblyASha({ query })).toBe(isPossiblyASha);
      },
    );
  });

  describe('isLoading', () => {
    it.each`
      requestCount | isLoading
      ${2}         | ${true}
      ${1}         | ${true}
      ${0}         | ${false}
      ${-1}        | ${false}
    `('returns true when at least one request is in progress', ({ requestCount, isLoading }) => {
      expect(getters.isLoading({ requestCount })).toBe(isLoading);
    });
  });
});

import { getRefType, isCommitSha } from '~/repository/utils/ref_type';

describe('getRefType', () => {
  it.each`
    refType          | expected
    ${'heads'}       | ${'HEADS'}
    ${'HEADS'}       | ${'HEADS'}
    ${'tags'}        | ${'TAGS'}
    ${'TAGS'}        | ${'TAGS'}
    ${'fakereftype'} | ${null}
    ${''}            | ${null}
    ${null}          | ${null}
  `('returns $expected for "$refType"', ({ refType, expected }) => {
    expect(getRefType(refType)).toBe(expected);
  });
});

describe('isCommitSha', () => {
  it.each`
    ref                                                   | expected
    ${'b83d6e391c22777fca1ed3012fce84f633d7fed0'}         | ${true}
    ${'B83D6E391C22777FCA1ED3012FCE84F633D7FED0'}         | ${true}
    ${'a'.repeat(64)}                                     | ${true}
    ${'b83d6e39'}                                         | ${false}
    ${'main'}                                             | ${false}
    ${'feature/b83d6e391c22777fca1ed3012fce84f633d7fed0'} | ${false}
    ${''}                                                 | ${false}
    ${null}                                               | ${false}
    ${undefined}                                          | ${false}
  `('returns $expected for "$ref"', ({ ref, expected }) => {
    expect(isCommitSha(ref)).toBe(expected);
  });
});

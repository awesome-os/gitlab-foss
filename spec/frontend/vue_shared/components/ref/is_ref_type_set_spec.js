import setWindowLocation from 'helpers/set_window_location_helper';
import { isRefTypeSet } from '~/vue_shared/components/ref/is_ref_type_set';

describe('isRefTypeSet', () => {
  it.each(['heads', 'tags'])('returns true when ref_type is %s', (refType) => {
    setWindowLocation(`?ref_type=${refType}`);

    expect(isRefTypeSet()).toBe(true);
  });

  it.each(['?', '?ref_type=', '?ref_type=other'])(
    'returns false when the query is "%s"',
    (search) => {
      setWindowLocation(search);

      expect(isRefTypeSet()).toBe(false);
    },
  );
});

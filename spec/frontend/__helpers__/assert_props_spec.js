import { assertProps } from 'helpers/assert_props';

const Component = {
  props: {
    isSignedIn: {
      type: Boolean,
      required: true,
    },
  },
};

describe('assertProps', () => {
  it('reports missing props on successive calls', () => {
    expect(() => assertProps(Component, {})).toThrow('Missing required prop: "isSignedIn"');
    expect(() => assertProps(Component, {})).toThrow('Missing required prop: "isSignedIn"');
  });

  it('reports invalid props on successive calls', () => {
    expect(() => assertProps(Component, { isSignedIn: 1 })).toThrow('Invalid prop');
    expect(() => assertProps(Component, { isSignedIn: 1 })).toThrow('Invalid prop');
  });

  it('validates props without rendering extra attributes', () => {
    expect(() => assertProps(Component, { id: 'test' })).toThrow(
      'Missing required prop: "isSignedIn"',
    );
  });

  it.each([true, false])('accepts isSignedIn=%s', (isSignedIn) => {
    expect(() => assertProps(Component, { isSignedIn })).not.toThrow();
  });
});

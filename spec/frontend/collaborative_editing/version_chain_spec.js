import VersionChain from '~/collaborative_editing/version_chain';

describe('collaborative_editing/version_chain', () => {
  let chain;
  let onChange;

  const version = (previousVersion, next, saveId) => ({ previousVersion, version: next, saveId });

  beforeEach(() => {
    onChange = jest.fn();
    chain = new VersionChain('v1', onChange);
  });

  it('adopts a version only once the save that produced it has been applied', () => {
    chain.recordVersion(version('v1', 'v2', 'save'));
    chain.recordSave(undefined);
    chain.recordSave('another save');

    expect(chain.version).toBe('v1');

    chain.recordSave('save');

    expect(chain.version).toBe('v2');
    expect(onChange.mock.calls).toEqual([['v2']]);
  });

  it('holds reversed version events without moving backwards', () => {
    chain.recordVersion(version('v2', 'v3', 'second'));
    chain.recordSave('second');
    chain.recordSave('first');
    chain.recordVersion(version('v1', 'v2', 'first'));

    expect(chain.version).toBe('v3');
    expect(onChange.mock.calls).toEqual([['v2'], ['v3']]);

    chain.recordVersion(version('v3', 'v2', 'first'));

    expect(chain.version).toBe('v3');
  });

  it('starts again from the given version and forgets earlier saves and events', () => {
    chain.recordSave('save');
    chain.recordVersion(version('v5', 'v6', 'later'));

    chain.reset('v5');
    chain.recordSave('later');
    chain.recordVersion(version('v5', 'v6', 'save'));

    expect(chain.version).toBe('v5');
    expect(onChange.mock.calls).toEqual([['v5']]);
  });

  it('forgets the oldest of more than 100 pending events', () => {
    chain.recordVersion(version('v1', 'v2', 'save'));
    for (let i = 0; i < 100; i += 1)
      chain.recordVersion(version(`other-${i}`, `next-${i}`, 'save'));

    chain.recordSave('save');

    expect(chain.version).toBe('v1');
  });
});

import { TEST_HOST } from 'helpers/test_constants';

jest.mock('@module-federation/runtime', () => ({
  createInstance: jest.fn(),
}));

const MANIFEST_URL = `${TEST_HOST}/assets/mfes/duo-chat/mf-manifest.json`;

describe('mfe_loader', () => {
  describe('loadMFEModule', () => {
    let federation;
    let runtime;
    let loadMFEModule;

    // The loader keeps its federation instance and registered remotes at module
    // level, so each test loads a fresh copy together with its runtime mock.
    const setup = () => {
      jest.isolateModules(() => {
        runtime = jest.requireMock('@module-federation/runtime');
        ({ loadMFEModule } = jest.requireActual('~/mfe_loader'));
      });
      runtime.createInstance.mockReturnValue(federation);
    };

    beforeEach(() => {
      federation = {
        registerRemotes: jest.fn(),
        loadRemote: jest.fn().mockResolvedValue({ mount: jest.fn() }),
      };
    });

    it('registers the remote and loads the exposed module without the leading ./', async () => {
      setup();

      await expect(
        loadMFEModule({
          remoteUrl: MANIFEST_URL,
          scopeName: 'mfe_duo_chat',
          modulePath: './DuoChatApp',
        }),
      ).resolves.toEqual({
        mount: expect.any(Function),
      });

      expect(federation.registerRemotes).toHaveBeenCalledWith(
        [{ name: 'mfe_duo_chat', entry: MANIFEST_URL }],
        { force: false },
      );
      expect(federation.loadRemote).toHaveBeenCalledWith('mfe_duo_chat/DuoChatApp');
    });

    it('does not register the same remote URL twice', async () => {
      setup();

      await loadMFEModule({
        remoteUrl: MANIFEST_URL,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
      });
      await loadMFEModule({
        remoteUrl: MANIFEST_URL,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
      });

      expect(federation.registerRemotes).toHaveBeenCalledTimes(1);
      expect(federation.loadRemote).toHaveBeenCalledTimes(2);
    });

    it('re-registers with force when the remote URL changes', async () => {
      setup();
      const newUrl = `${TEST_HOST}/assets/mfes/duo-chat-2/mf-manifest.json`;

      await loadMFEModule({
        remoteUrl: MANIFEST_URL,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
      });
      await loadMFEModule({
        remoteUrl: newUrl,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
      });

      expect(federation.registerRemotes).toHaveBeenLastCalledWith(
        [{ name: 'mfe_duo_chat', entry: newUrl }],
        { force: true },
      );
    });

    it('rejects a cross-origin remote without registering it', async () => {
      setup();

      await expect(
        loadMFEModule({
          remoteUrl: 'https://evil.example/mf-manifest.json',
          scopeName: 'mfe_duo_chat',
          modulePath: './DuoChatApp',
        }),
      ).rejects.toThrow('MFE remote must be same-origin, got https://evil.example');
      expect(federation.registerRemotes).not.toHaveBeenCalled();
    });

    it('allows a cross-origin remote whose origin is explicitly allowed', async () => {
      setup();
      const devServerUrl = 'http://localhost:4001/mf-manifest.json';

      await loadMFEModule({
        remoteUrl: devServerUrl,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
        allowedOrigins: ['http://localhost:4001'],
      });

      expect(federation.registerRemotes).toHaveBeenCalledWith(
        [{ name: 'mfe_duo_chat', entry: devServerUrl }],
        { force: false },
      );
    });

    it('creates the federation instance once', async () => {
      setup();

      await loadMFEModule({
        remoteUrl: MANIFEST_URL,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
      });
      await loadMFEModule({
        remoteUrl: MANIFEST_URL,
        scopeName: 'mfe_duo_chat',
        modulePath: './DuoChatApp',
      });

      expect(runtime.createInstance).toHaveBeenCalledTimes(1);
      expect(runtime.createInstance).toHaveBeenCalledWith({ name: 'gitlab' });
    });
  });
});

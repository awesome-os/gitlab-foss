import { createInstance } from '@module-federation/runtime';

// Track which remote names have already been registered so we don't re-register
// on every call. Keyed by scopeName since Module Federation identifies remotes
// by name, not by URL.
const registeredRemotes = new Map();

let federationInstance = null;

// No shared deps yet: the published remotes bundle their own Vue. When a remote
// declares shared deps, it needs plain Vue 3, not the monolith's @vue/compat in MODE 2.
function getFederationInstance() {
  federationInstance ??= createInstance({ name: 'gitlab' });
  return federationInstance;
}

/**
 * Load a module from a Module Federation remote container.
 *
 * Uses the MF 2.0 runtime API: registers the remote dynamically via
 * federation.registerRemotes() then resolves the module via loadRemote().
 *
 * The remote runs as first-party script, and CSP's 'strict-dynamic' puts no origin
 * limit on the scripts the runtime injects, so the remote must be same-origin
 * unless its origin is passed in `allowedOrigins` (e.g. the development server).
 *
 * @param {Object} options
 * @param {string} options.remoteUrl  - URL of the remote's mf-manifest.json
 * @param {string} options.scopeName  - Federation scope name (matches `name` in the MFE's federation config)
 * @param {string} options.modulePath - Exposed module path, e.g. './DuoChatApp'
 * @param {string[]} [options.allowedOrigins] - Cross-origin remotes to allow
 * @returns {Promise<object>} - The module's exports
 */
export async function loadMFEModule({ remoteUrl, scopeName, modulePath, allowedOrigins = [] }) {
  const { origin } = new URL(remoteUrl, window.location.origin);
  if (origin !== window.location.origin && !allowedOrigins.includes(origin)) {
    throw new Error(`MFE remote must be same-origin, got ${origin}`);
  }

  const federation = getFederationInstance();

  const knownEntry = registeredRemotes.get(scopeName);

  if (knownEntry !== remoteUrl) {
    // Register for the first time, or re-register with force if the URL changed
    // (e.g. after a deploy that rotates the remoteEntry hash).
    federation.registerRemotes([{ name: scopeName, entry: remoteUrl }], {
      force: knownEntry !== undefined,
    });
    registeredRemotes.set(scopeName, remoteUrl);
  }

  // loadRemote expects 'remoteName/exposedModule' — strip the leading './' that
  // the vite-plugin-federation / webpack MF convention uses in expose keys.
  const exposedModule = modulePath.replace(/^\.\//, '');

  return federation.loadRemote(`${scopeName}/${exposedModule}`);
}

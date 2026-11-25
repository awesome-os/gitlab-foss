import * as Y from 'yjs';
import {
  Awareness,
  encodeAwarenessUpdate,
  applyAwarenessUpdate,
  removeAwarenessStates,
} from 'y-protocols/awareness';
import cable from '~/actioncable_consumer';
import ActionCableProvider from '~/collaborative_editing/action_cable_provider';
import { bytesToBase64 } from '~/collaborative_editing/encoding';
import { logError } from '~/lib/logger';

jest.mock('~/lib/logger');

describe('collaborative_editing/action_cable_provider', () => {
  const channelParams = { container_full_path: 'group/project', slug: 'home' };
  const identity = { id: 7, name: 'Aardvark', avatarUrl: '/avatar.png' };

  let provider;
  let subscription;
  let callbacks;

  const createProvider = () => {
    provider = new ActionCableProvider({
      channel: 'CollaborativeEditing::WikiPageChannel',
      channelParams,
    });
  };

  const connectAndInit = ({ updates = [], seed = false } = {}) => {
    provider.connect();
    callbacks.connected();
    callbacks.received({ type: 'init', updates, seed, sessionId: 'session-one', version: 'v1' });
  };

  const sentMessages = (type) =>
    subscription.send.mock.calls.map(([message]) => message).filter((m) => m.type === type);

  const acknowledge = (message) =>
    callbacks.received({ type: 'ack', messageId: message.messageId });

  const decodePayload = (payload) => Uint8Array.from(atob(payload), (c) => c.charCodeAt(0));

  const documentFromAll = (...payloads) => {
    const receiver = new Y.Doc();
    payloads.forEach((payload) => Y.applyUpdate(receiver, decodePayload(payload)));

    return receiver.getText('content').toString();
  };

  const documentFrom = (payload) => documentFromAll(payload);

  const updateFrom = (text) => {
    const remote = new Y.Doc();
    remote.getText('content').insert(0, text);

    return bytesToBase64(Y.encodeStateAsUpdate(remote));
  };

  beforeEach(() => {
    subscription = { send: jest.fn(), perform: jest.fn(), unsubscribe: jest.fn() };

    jest.spyOn(cable.subscriptions, 'create').mockImplementation((_params, handlers) => {
      callbacks = handlers;
      return subscription;
    });

    createProvider();
  });

  afterEach(() => {
    provider.destroy();
  });

  describe('connect', () => {
    it('subscribes with the given channel and params', () => {
      provider.connect();

      expect(cable.subscriptions.create).toHaveBeenCalledWith(
        { channel: 'CollaborativeEditing::WikiPageChannel', ...channelParams },
        expect.any(Object),
      );
    });

    it('does not publish any identity of its own into the awareness state', () => {
      provider.connect();

      expect(provider.awareness.getLocalState()?.user).toBeUndefined();
    });
  });

  describe('collaborative saves', () => {
    beforeEach(() => {
      connectAndInit();
    });

    it('resolves only the matching accepted acknowledgement', async () => {
      const saving = provider.startSave();
      const message = sentMessages('sync').at(-1);
      const resolved = jest.fn();
      const observed = saving.then(resolved);
      callbacks.received({ type: 'ack', messageId: message.messageId + 1, saveAccepted: true });
      await Promise.resolve();
      expect(resolved).not.toHaveBeenCalled();
      callbacks.received({ type: 'ack', messageId: message.messageId, saveAccepted: true });
      await expect(saving).resolves.toEqual({ sessionId: 'session-one', saveId: message.saveId });
      await observed;
    });

    it('rejects a second barrier and resumes incremental edits after the accepted snapshot', async () => {
      const saving = provider.startSave();
      await expect(provider.startSave()).rejects.toThrow('unsynchronised');
      provider.doc.getText('content').insert(0, 'later edit');
      const message = sentMessages('sync')[0];
      callbacks.received({ type: 'request_snapshot', token: 'compaction' });
      expect(sentMessages('snapshot')).toHaveLength(0);
      callbacks.received({ type: 'ack', messageId: message.messageId, saveAccepted: true });
      await saving;

      expect(sentMessages('sync')).toHaveLength(2);
    });

    it.each(['busy', 'document_full', 'payload_too_large', 'disconnect', 'timeout', 'invalidated'])(
      'rejects %s without retrying the save request',
      async (reason) => {
        const saving = provider.startSave();
        const rejection = saving.catch((error) => error.message);
        const message = sentMessages('sync').at(-1);
        if (reason === 'disconnect') callbacks.disconnected();
        else if (reason === 'timeout') jest.advanceTimersByTime(10000);
        else if (reason === 'invalidated') callbacks.received({ type: 'session_invalidated' });
        else
          callbacks.received({
            type: reason === 'busy' ? 'ack' : reason,
            messageId: message.messageId,
            saveAccepted: false,
          });
        expect(await rejection).toEqual(expect.any(String));
        callbacks.received({ type: 'ack', messageId: message.messageId, saveAccepted: true });
        jest.advanceTimersByTime(120000);
        const retries = sentMessages('sync').slice(1);
        expect(retries.every((retry) => retry.saveId === undefined)).toBe(true);
        expect(sentMessages('sync')).toHaveLength(
          ['document_full', 'payload_too_large', 'timeout'].includes(reason) ? 5 : 1,
        );
      },
    );

    it('flushes queued edits after a busy acknowledgement without resending the full state', async () => {
      const saving = provider.startSave();
      const rejected = saving.catch((error) => error.message);
      provider.doc.getText('content').insert(0, 'after snapshot');
      const message = sentMessages('sync')[0];
      callbacks.received({ type: 'ack', messageId: message.messageId, saveAccepted: false });
      expect(await rejected).toBe('busy');
      expect(sentMessages('sync')).toHaveLength(2);
      acknowledge(sentMessages('sync')[1]);
      jest.advanceTimersByTime(120000);
      expect(sentMessages('sync')).toHaveLength(2);
    });

    it.each([undefined, '', 1])('rejects INIT with unusable version %s', (version) => {
      callbacks.received({ type: 'init', sessionId: 'session-one', version, updates: [] });
      expect(provider.stallReason).toBe('session_invalidated');
      expect(provider.version).toBe('v1');
    });

    it.each([true, false])(
      'pairs state and version events in either order (%s)',
      (versionFirst) => {
        const sync = { type: 'sync', payload: updateFrom('saved'), clientId: -1, saveId: 'save' };
        const version = { type: 'version', previousVersion: 'v1', version: 'v2', saveId: 'save' };
        callbacks.received(versionFirst ? version : sync);
        expect(provider.version).toBe('v1');
        callbacks.received(versionFirst ? sync : version);
        expect(provider.version).toBe('v2');
      },
    );

    it('does not adopt a saved version from malformed state', () => {
      callbacks.received({ type: 'version', previousVersion: 'v1', version: 'v2', saveId: 'bad' });
      callbacks.received({ type: 'sync', payload: 'not base64', clientId: -1, saveId: 'bad' });

      expect(provider.version).toBe('v1');
      expect(logError).toHaveBeenCalled();
    });

    it('adopts the reconnect version after applying the complete log', () => {
      const observed = jest.fn(() => provider.doc.getText('content').toString());
      provider.onVersionChange = observed;
      callbacks.disconnected();
      callbacks.connected();
      callbacks.received({
        type: 'init',
        sessionId: 'session-one',
        version: 'v4',
        updates: [updateFrom('saved log')],
      });

      expect(observed).toHaveBeenCalledWith('v4');
      expect(observed.mock.results[0].value).toBe('saved log');
    });
  });

  describe('receiving the initial state', () => {
    it('enters recovery if readiness never produces an initial replay', async () => {
      provider.connect();
      callbacks.connected();
      const onStallChange = jest.fn();
      provider.onStallChange = onStallChange;

      jest.advanceTimersByTime(10000);

      expect(provider.stallReason).toBe('lookup_failed');
      expect(onStallChange).toHaveBeenCalledWith('lookup_failed');
      await expect(provider.whenSynced).resolves.toEqual({ seed: true });
      await provider.seed(() => provider.doc.getText('content').insert(0, 'recovery content'));
      callbacks.received({ type: 'init', sessionId: 'late', updates: [updateFrom('late server')] });
      expect(provider.doc.getText('content').toString()).toBe('recovery content');
      expect(provider.stallReason).toBe('lookup_failed');
      expect(subscription.perform).toHaveBeenCalledTimes(1);
      expect(subscription.send).not.toHaveBeenCalled();
    });

    it('keeps the session and resubscribes with a longer wait when a reconnect gets no replay', () => {
      connectAndInit();
      callbacks.disconnected();
      callbacks.connected();
      callbacks.received({ type: 'sync', payload: updateFrom('stale stream'), clientId: -1 });

      jest.advanceTimersByTime(10000);

      expect(provider.stallReason).toBe('unacknowledged');
      expect(subscription.unsubscribe).toHaveBeenCalledTimes(1);
      expect(cable.subscriptions.create).toHaveBeenCalledTimes(2);

      callbacks.connected();
      jest.advanceTimersByTime(19999);
      expect(cable.subscriptions.create).toHaveBeenCalledTimes(2);
      callbacks.received({ type: 'init', sessionId: 'session-one', version: 'v1', updates: [] });

      expect(provider.stallReason).toBeNull();
      expect(provider.doc.getText('content').toString()).toBe('');
      jest.advanceTimersByTime(60000);
      expect(cable.subscriptions.create).toHaveBeenCalledTimes(2);
    });

    it('requests replay only after subscription confirmation', () => {
      provider.connect();
      expect(subscription.perform).not.toHaveBeenCalled();

      callbacks.connected();

      expect(subscription.perform).toHaveBeenCalledWith('initialize_session', {
        version: undefined,
        sessionId: null,
      });
    });

    it('applies a live update received between catch-up read and init delivery', () => {
      provider.connect();
      callbacks.connected();
      callbacks.received({ type: 'sync', payload: updateFrom('in the gap'), clientId: -1 });

      expect(provider.doc.getText('content').toString()).toBe('');

      callbacks.received({ type: 'init', sessionId: 'session-one', version: 'v1', updates: [] });

      expect(provider.doc.getText('content').toString()).toBe('in the gap');
    });

    it('clears buffered updates on disconnect before replay', () => {
      provider.connect();
      callbacks.connected();
      callbacks.received({ type: 'sync', payload: updateFrom('old stream'), clientId: -1 });
      callbacks.disconnected();
      callbacks.connected();
      callbacks.received({ type: 'init', sessionId: 'session-one', version: 'v1', updates: [] });

      expect(provider.doc.getText('content').toString()).toBe('');
    });

    it('fails closed when pre-init messages exceed the buffer limit', () => {
      provider.connect();
      callbacks.connected();
      for (let i = 0; i <= 2000; i += 1) {
        callbacks.received({ type: 'sync', payload: '', clientId: -1 });
      }

      expect(provider.stallReason).toBe('session_invalidated');
      expect(subscription.send).not.toHaveBeenCalled();
    });

    it('fails closed when pre-init payloads exceed the byte limit', () => {
      provider.connect();
      callbacks.connected();
      callbacks.received({ type: 'sync', payload: 'a'.repeat(16 * 1024 * 1024 + 1), clientId: -1 });

      expect(provider.stallReason).toBe('session_invalidated');
      expect(subscription.send).not.toHaveBeenCalled();
    });

    it('does not send local changes until the initial state arrives', () => {
      provider.connect();
      callbacks.connected();
      provider.doc.getText('content').insert(0, 'before init');

      expect(sentMessages('sync')).toHaveLength(0);

      callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

      expect(documentFrom(sentMessages('sync')[0].payload)).toBe('before init');
    });

    it('applies existing updates to the document', () => {
      connectAndInit({ updates: [updateFrom('from a peer')] });

      expect(provider.doc.getText('content').toString()).toBe('from a peer');
    });

    it('resolves whenSynced with the seed decision', async () => {
      connectAndInit({ seed: true });

      await expect(provider.whenSynced).resolves.toEqual({ seed: true });
    });

    it('does not echo the applied updates back to the server', () => {
      connectAndInit({ updates: [updateFrom('from a peer')] });

      expect(sentMessages('sync')).toHaveLength(0);
    });

    it('announces its presence once synced', () => {
      connectAndInit();

      expect(sentMessages('awareness')).not.toHaveLength(0);
    });

    it('does not announce awareness before the initial state arrives', () => {
      provider.connect();
      callbacks.connected();

      expect(sentMessages('awareness')).toHaveLength(0);
    });

    it('re-announces its current awareness on reconnect without waiting for a heartbeat', () => {
      connectAndInit();
      provider.awareness.setLocalStateField('cursor', { anchor: 1 });
      const peerAwareness = new Awareness(new Y.Doc());
      const [initialAnnouncement] = sentMessages('awareness').slice(-1);
      applyAwarenessUpdate(peerAwareness, decodePayload(initialAnnouncement.payload), null);
      removeAwarenessStates(peerAwareness, [provider.doc.clientID], null);
      subscription.send.mockClear();
      callbacks.disconnected();

      callbacks.connected();

      expect(sentMessages('awareness')).toHaveLength(0);
      callbacks.received({ type: 'init', sessionId: 'session-one', version: 'v1', updates: [] });

      const [announcement] = sentMessages('awareness');
      expect(sentMessages('awareness')).toHaveLength(1);

      applyAwarenessUpdate(peerAwareness, decodePayload(announcement.payload), null);

      expect(peerAwareness.getStates().get(provider.doc.clientID)).toMatchObject({
        cursor: { anchor: 1 },
      });
      peerAwareness.destroy();
    });

    it('applies the sound updates either side of a malformed one', () => {
      connectAndInit({ updates: [updateFrom('kept'), 'not base64 at all'] });

      expect(provider.doc.getText('content').toString()).toBe('kept');
      expect(logError).toHaveBeenCalled();
    });
  });

  describe('local document changes', () => {
    beforeEach(() => {
      connectAndInit();
    });

    it('sends an update the server can apply', () => {
      provider.doc.getText('content').insert(0, 'typed locally');

      const [message] = sentMessages('sync');

      expect(documentFrom(message.payload)).toBe('typed locally');
      expect(message.clientId).toBe(provider.doc.clientID);
    });

    describe('while disconnected', () => {
      beforeEach(() => {
        callbacks.disconnected();

        provider.doc.getText('content').insert(0, 'typed while offline');
      });

      it('does not send anything', () => {
        expect(sentMessages('sync')).toHaveLength(0);
      });

      it('sends full state on reconnect, because the dropped delta is unrecoverable', () => {
        callbacks.connected();
        expect(sentMessages('sync')).toHaveLength(0);
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

        const [resent] = sentMessages('sync');

        expect(resent.sessionId).toBe('session-one');
        expect(documentFrom(resent.payload)).toBe('typed while offline');
      });

      it('sends offline edits when init arrives before the connected callback', () => {
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });
        expect(sentMessages('sync')).toHaveLength(0);

        callbacks.connected();

        expect(documentFrom(sentMessages('sync')[0].payload)).toBe('typed while offline');
      });

      it('returns to sending incremental updates once reconnected', () => {
        callbacks.connected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });
        acknowledge(sentMessages('sync')[0]);
        provider.doc.getText('content').insert(0, 'and ');

        const [, incremental] = sentMessages('sync');

        expect(documentFrom(incremental.payload)).toBe('');
      });

      it('re-arms when the connection drops again', () => {
        callbacks.connected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });
        callbacks.disconnected();
        provider.doc.getText('content').insert(0, 'and ');
        callbacks.connected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

        const [, resent] = sentMessages('sync');

        expect(documentFrom(resent.payload)).toBe('and typed while offline');
      });
    });

    describe('while awaiting server acknowledgement', () => {
      beforeEach(() => {
        provider.doc.getText('content').insert(0, 'first');
      });

      it('merges queued edits without sending the whole document after acknowledgement', () => {
        provider.doc.getText('content').insert(5, ' second');
        const [first] = sentMessages('sync');
        expect(sentMessages('sync')).toHaveLength(1);

        acknowledge(first);
        const [, merged] = sentMessages('sync');
        expect(documentFrom(merged.payload)).toBe('');
        expect(documentFromAll(first.payload, merged.payload)).toBe('first second');

        provider.doc.getText('content').insert(12, ' third');
        expect(sentMessages('sync')).toHaveLength(2);

        acknowledge(merged);
        expect(documentFrom(sentMessages('sync')[2].payload)).toBe('');
        expect(
          documentFromAll(first.payload, merged.payload, sentMessages('sync')[2].payload),
        ).toBe('first second third');
      });

      it('combines several queued edits into a single incremental update', () => {
        provider.doc.getText('content').insert(5, ' second');
        provider.doc.getText('content').insert(12, ' third');
        const [first] = sentMessages('sync');

        acknowledge(first);

        const [, merged] = sentMessages('sync');
        expect(sentMessages('sync')).toHaveLength(2);
        expect(documentFrom(merged.payload)).toBe('');
        expect(documentFromAll(first.payload, merged.payload)).toBe('first second third');
      });

      it('returns to incremental updates after the queued edits are acknowledged', () => {
        provider.doc.getText('content').insert(5, ' second');
        acknowledge(sentMessages('sync')[0]);
        acknowledge(sentMessages('sync')[1]);
        provider.doc.getText('content').insert(12, ' third');

        expect(documentFrom(sentMessages('sync')[2].payload)).toBe('');
      });

      it('returns to incremental updates after the first update is acknowledged', () => {
        acknowledge(sentMessages('sync')[0]);
        provider.doc.getText('content').insert(5, ' second');

        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('');
      });

      it('does not accept an acknowledgement without the pending message ID', () => {
        callbacks.received({ type: 'ack' });
        provider.doc.getText('content').insert(5, ' second');

        expect(sentMessages('sync')).toHaveLength(1);
        acknowledge(sentMessages('sync')[0]);
        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('');
        expect(
          documentFromAll(sentMessages('sync')[0].payload, sentMessages('sync')[1].payload),
        ).toBe('first second');
      });

      it('resends full state on reconnect without an acknowledgement', () => {
        callbacks.disconnected();
        callbacks.connected();
        expect(sentMessages('sync')).toHaveLength(1);
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('first');
      });

      it('waits for init before resending edits made during reconnection', () => {
        callbacks.disconnected();
        callbacks.connected();
        provider.doc.getText('content').insert(5, ' second');

        expect(sentMessages('sync')).toHaveLength(1);

        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('first second');
      });

      it('resends unacknowledged and queued edits when init precedes connected', () => {
        provider.doc.getText('content').insert(5, ' second');
        callbacks.disconnected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });
        expect(sentMessages('sync')).toHaveLength(1);

        callbacks.connected();

        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('first second');
      });

      it('retries a dropped final update without another edit', () => {
        jest.advanceTimersByTime(5000);

        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('first');
      });

      it('does not send full state on every keystroke while the server is silent', () => {
        provider.doc.getText('content').insert(5, ' second');
        provider.doc.getText('content').insert(12, ' third');

        expect(sentMessages('sync')).toHaveLength(1);

        jest.advanceTimersByTime(5000);
        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('first second third');
      });

      it('does not replay the same document after an acknowledgement with no later edits', () => {
        provider.doc.getText('content').insert(5, ' second');
        acknowledge(sentMessages('sync')[0]);
        acknowledge(sentMessages('sync')[1]);
        jest.advanceTimersByTime(60000);

        expect(sentMessages('sync')).toHaveLength(2);
      });

      it('keeps retrying without accepting an old acknowledgement', () => {
        const [first] = sentMessages('sync');
        jest.advanceTimersByTime(5000);
        acknowledge(first);
        jest.advanceTimersByTime(10000);

        expect(sentMessages('sync')).toHaveLength(3);
      });

      it('ignores a late acknowledgement from the previous connection', () => {
        const [first] = sentMessages('sync');
        callbacks.disconnected();
        callbacks.connected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });
        acknowledge(first);
        jest.advanceTimersByTime(5000);

        expect(sentMessages('sync')).toHaveLength(3);
      });

      it('backs off retries while the server is silent', () => {
        jest.advanceTimersByTime(5000);
        jest.advanceTimersByTime(9999);
        expect(sentMessages('sync')).toHaveLength(2);

        jest.advanceTimersByTime(1);
        expect(sentMessages('sync')).toHaveLength(3);
      });

      it('stops retrying after acknowledgement', () => {
        acknowledge(sentMessages('sync')[0]);
        jest.advanceTimersByTime(60000);

        expect(sentMessages('sync')).toHaveLength(1);
      });

      it('stops retrying while disconnected and resends after init', () => {
        callbacks.disconnected();
        jest.advanceTimersByTime(60000);
        expect(sentMessages('sync')).toHaveLength(1);

        callbacks.connected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

        expect(documentFrom(sentMessages('sync')[1].payload)).toBe('first');
      });
    });
  });

  describe('session generations', () => {
    beforeEach(() => {
      connectAndInit();
      provider.doc.getText('content').insert(0, 'keep my work');
      callbacks.disconnected();
      subscription.send.mockClear();
    });

    it('neither applies nor uploads content after a generation change', () => {
      callbacks.connected();
      subscription.send.mockClear();
      callbacks.received({
        type: 'sync',
        payload: updateFrom('buffered replacement'),
        clientId: -1,
      });
      callbacks.received({
        type: 'init',
        sessionId: 'replacement',
        updates: [updateFrom('replacement content')],
        seed: true,
      });
      callbacks.received({ type: 'ack', messageId: 1 });
      callbacks.received({ type: 'sync', payload: updateFrom('late content'), clientId: -1 });
      callbacks.received({ type: 'request_snapshot', token: 'late-claim' });
      callbacks.disconnected();
      callbacks.connected();
      callbacks.received({ type: 'init', sessionId: 'session-one', version: 'v1', updates: [] });
      jest.advanceTimersByTime(120000);

      expect(provider.doc.getText('content').toString()).toBe('keep my work');
      expect(provider.stallReason).toBe('session_invalidated');
      expect(subscription.send).not.toHaveBeenCalled();
    });
  });

  describe.each([
    { type: 'session_invalidated', reason: 'page_changed' },
    { type: 'init', seed: true },
  ])('initial recovery for $type', (message) => {
    beforeEach(() => {
      provider.connect();
      callbacks.connected();
      callbacks.received({ ...message, updates: [updateFrom('unsafe')] });
    });

    it('allows local recovery content without sending a seed', async () => {
      expect(provider.doc.getText('content').toString()).toBe('');
      await expect(provider.whenSynced).resolves.toEqual({ seed: true });
      await provider.seed(() => provider.doc.getText('content').insert(0, 'local recovery'));

      expect(provider.doc.getText('content').toString()).toBe('local recovery');
      expect(provider.stallReason).toBe('session_invalidated');
      expect(subscription.send).not.toHaveBeenCalled();
    });
  });

  it('preserves lookup failure as a terminal recovery reason', async () => {
    provider.connect();
    callbacks.connected();
    callbacks.received({ type: 'session_invalidated', reason: 'lookup_failed' });
    await provider.seed(() => provider.doc.getText('content').insert(0, 'keep'));
    callbacks.received({ type: 'init', sessionId: 'late', updates: [] });

    expect(provider.stallReason).toBe('lookup_failed');
    expect(provider.doc.getText('content').toString()).toBe('keep');
    expect(subscription.send).not.toHaveBeenCalled();
  });

  describe('remote messages', () => {
    beforeEach(() => {
      connectAndInit();
    });

    it('applies a sync update from another client', () => {
      callbacks.received({
        type: 'sync',
        payload: updateFrom('typed elsewhere'),
        clientId: provider.doc.clientID + 1,
      });

      expect(provider.doc.getText('content').toString()).toBe('typed elsewhere');
    });

    it('ignores a message echoed back from itself', () => {
      callbacks.received({
        type: 'sync',
        payload: updateFrom('echo'),
        clientId: provider.doc.clientID,
      });

      expect(provider.doc.getText('content').toString()).toBe('');
    });

    it('ignores an unrecognised message type', () => {
      expect(() => callbacks.received({ type: 'nonsense' })).not.toThrow();
    });

    describe('with a malformed payload', () => {
      const receiveMalformed = (type) =>
        callbacks.received({
          type,
          payload: 'not base64 at all',
          clientId: provider.doc.clientID + 1,
        });

      it.each(['sync', 'awareness'])('discards a %s payload it cannot apply', (type) => {
        expect(() => receiveMalformed(type)).not.toThrow();
        expect(logError).toHaveBeenCalled();
      });

      it('keeps relaying local changes afterwards', () => {
        receiveMalformed('sync');

        provider.doc.getText('content').insert(0, 'still working');

        expect(sentMessages('sync')).toHaveLength(1);
      });
    });
  });

  describe('compaction', () => {
    beforeEach(() => {
      connectAndInit();
    });

    it('sends a snapshot of the whole document, carrying the token back', () => {
      provider.doc.getText('content').insert(0, 'the full document');

      callbacks.received({ type: 'request_snapshot', token: 'a-compaction-token' });

      const [message] = sentMessages('snapshot');

      expect(documentFrom(message.payload)).toBe('the full document');
      expect(message.token).toBe('a-compaction-token');
    });

    it('sends no snapshot without a token, because the server would reject it', () => {
      provider.doc.getText('content').insert(0, 'the full document');

      callbacks.received({ type: 'request_snapshot' });

      expect(sentMessages('snapshot')).toHaveLength(0);
    });

    it('waits for snapshot acknowledgement when it supersedes an unacknowledged sync', () => {
      provider.doc.getText('content').insert(0, 'unsaved');
      const [sync] = sentMessages('sync');

      callbacks.received({ type: 'request_snapshot', token: 'a-compaction-token' });
      acknowledge(sync);
      provider.doc.getText('content').insert(7, ' changes');

      expect(sentMessages('sync')).toHaveLength(1);
      acknowledge(sentMessages('snapshot')[0]);
      expect(documentFrom(sentMessages('sync')[1].payload)).toBe('');
      expect(
        documentFromAll(sentMessages('snapshot')[0].payload, sentMessages('sync')[1].payload),
      ).toBe('unsaved changes');

      acknowledge(sentMessages('sync')[1]);
      provider.doc.getText('content').insert(15, ' more');

      expect(documentFrom(sentMessages('sync')[2].payload)).toBe('');
    });
  });

  describe('when the server reports the document is full', () => {
    beforeEach(() => {
      connectAndInit();

      provider.doc.getText('content').insert(0, 'dropped by the server');
      callbacks.received({ type: 'document_full', messageId: sentMessages('sync')[0].messageId });
    });

    it('replaces the dropped update on retry, including later edits', () => {
      provider.doc.getText('content').insert(0, 'and ');
      jest.advanceTimersByTime(5000);

      const [, resent] = sentMessages('sync');

      expect(documentFrom(resent.payload)).toBe('and dropped by the server');
    });

    it('retries a rejected final update even without another edit', () => {
      jest.advanceTimersByTime(5000);

      expect(documentFrom(sentMessages('sync')[1].payload)).toBe('dropped by the server');
    });

    it('waits for the armed retry when editing a full document', () => {
      provider.doc.getText('content').insert(0, 'and ');

      expect(sentMessages('sync')).toHaveLength(1);
      jest.advanceTimersByTime(4999);
      expect(sentMessages('sync')).toHaveLength(1);
      jest.advanceTimersByTime(1);

      expect(documentFrom(sentMessages('sync')[1].payload)).toBe('and dropped by the server');
    });

    it('backs off repeated document-full rejections and resets after acknowledgement', () => {
      jest.advanceTimersByTime(4999);
      expect(sentMessages('sync')).toHaveLength(1);
      jest.advanceTimersByTime(1);
      expect(sentMessages('sync')).toHaveLength(2);

      callbacks.received({ type: 'document_full', messageId: sentMessages('sync')[1].messageId });
      jest.advanceTimersByTime(9999);
      expect(sentMessages('sync')).toHaveLength(2);
      jest.advanceTimersByTime(1);
      expect(sentMessages('sync')).toHaveLength(3);

      acknowledge(sentMessages('sync')[2]);
      provider.doc.getText('content').insert(0, 'and ');
      jest.advanceTimersByTime(5000);

      expect(sentMessages('sync')).toHaveLength(5);
    });

    it('caps repeated document-full retries at sixty seconds', () => {
      for (const delay of [5000, 10000, 20000, 40000, 60000, 60000]) {
        jest.advanceTimersByTime(delay);
        callbacks.received({
          type: 'document_full',
          messageId: sentMessages('sync').at(-1).messageId,
        });
      }

      jest.advanceTimersByTime(59999);
      expect(sentMessages('sync')).toHaveLength(7);
      jest.advanceTimersByTime(1);
      expect(sentMessages('sync')).toHaveLength(8);
    });

    it('returns to sending incremental updates once full state has landed', () => {
      provider.doc.getText('content').insert(0, 'and ');
      jest.advanceTimersByTime(5000);
      acknowledge(sentMessages('sync')[1]);
      provider.doc.getText('content').insert(0, 'so ');

      const [, fullState, incremental] = sentMessages('sync');

      expect(documentFrom(incremental.payload)).toBe('');
      expect(documentFromAll(fullState.payload, incremental.payload)).toBe(
        'so and dropped by the server',
      );
    });

    it('ignores a late rejection for an earlier update after a newer one is accepted', () => {
      const [first] = sentMessages('sync');
      jest.advanceTimersByTime(5000);
      const [, retry] = sentMessages('sync');

      callbacks.received({ type: 'document_full', messageId: first.messageId });
      acknowledge(retry);
      jest.advanceTimersByTime(60000);

      expect(sentMessages('sync')).toHaveLength(2);
    });

    it('does not cancel a pending retry when an old rejection arrives late', () => {
      const [first] = sentMessages('sync');
      jest.advanceTimersByTime(5000);

      callbacks.received({ type: 'document_full', messageId: first.messageId });
      jest.advanceTimersByTime(10000);

      expect(sentMessages('sync')).toHaveLength(3);
    });

    it('does not resend full state when a snapshot already carried it', () => {
      callbacks.received({ type: 'request_snapshot', token: 'a-compaction-token' });
      acknowledge(sentMessages('snapshot')[0]);

      provider.doc.getText('content').insert(0, 'and ');

      const [snapshot] = sentMessages('snapshot');
      const [, incremental] = sentMessages('sync');

      expect(documentFrom(incremental.payload)).toBe('');
      expect(documentFromAll(snapshot.payload, incremental.payload)).toBe(
        'and dropped by the server',
      );
    });

    it('still resends full state when the snapshot could not be sent', () => {
      callbacks.disconnected();
      callbacks.received({ type: 'request_snapshot', token: 'a-compaction-token' });
      callbacks.connected();
      callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

      const [, resent] = sentMessages('sync');

      expect(documentFrom(resent.payload)).toBe('dropped by the server');
    });
  });

  describe('when an update is rejected with queued edits', () => {
    beforeEach(() => {
      connectAndInit();
      provider.doc.getText('content').insert(0, 'dropped by the server');
      provider.doc.getText('content').insert(0, 'and ');
    });

    it('recovers both the rejected update and queued edits as full state', () => {
      expect(sentMessages('sync')).toHaveLength(1);

      callbacks.received({ type: 'document_full', messageId: sentMessages('sync')[0].messageId });
      jest.advanceTimersByTime(5000);

      expect(documentFrom(sentMessages('sync')[1].payload)).toBe('and dropped by the server');
    });
  });

  describe('when the server reports a payload is too large', () => {
    let onStallChange;

    beforeEach(() => {
      onStallChange = jest.fn();
      provider.destroy();
      provider = new ActionCableProvider({
        channel: 'CollaborativeEditing::WikiPageChannel',
        channelParams,
        onStallChange,
      });
      connectAndInit();
    });

    describe('with an update awaiting acknowledgement', () => {
      beforeEach(() => {
        provider.doc.getText('content').insert(0, 'too large');
        callbacks.received({ type: 'payload_too_large' });
      });

      it('reports the stall', () => {
        expect(provider.stallReason).toBe('payload_too_large');
        expect(onStallChange).toHaveBeenCalledTimes(1);
        expect(onStallChange).toHaveBeenCalledWith('payload_too_large');
      });

      it('stops resending state the server would reject again', () => {
        provider.doc.getText('content').insert(0, 'and ');
        jest.advanceTimersByTime(120000);

        expect(sentMessages('sync')).toHaveLength(1);
        expect(provider.doc.getText('content').toString()).toBe('and too large');
      });

      it('does not resend after a reconnect', () => {
        callbacks.disconnected();
        callbacks.connected();
        callbacks.received({ type: 'init', updates: [], sessionId: 'session-one', version: 'v1' });

        expect(sentMessages('sync')).toHaveLength(1);
      });

      it('does not answer a compaction request', () => {
        callbacks.received({ type: 'request_snapshot', token: 'a-compaction-token' });

        expect(sentMessages('snapshot')).toHaveLength(0);
      });

      it('keeps applying updates from other clients', () => {
        const remote = new Y.Doc();
        remote.getText('other').insert(0, 'typed elsewhere');

        callbacks.received({
          type: 'sync',
          payload: bytesToBase64(Y.encodeStateAsUpdate(remote)),
          clientId: provider.doc.clientID + 1,
        });

        expect(provider.doc.getText('other').toString()).toBe('typed elsewhere');
      });

      it('recovers when the pending update is acknowledged after all', () => {
        acknowledge(sentMessages('sync')[0]);

        expect(provider.stallReason).toBeNull();
        expect(onStallChange).toHaveBeenLastCalledWith(null);
      });
    });

    it('ignores a rejection for a snapshot nobody is waiting on', () => {
      callbacks.received({ type: 'request_snapshot', token: 'a-compaction-token' });
      callbacks.received({ type: 'payload_too_large' });
      provider.doc.getText('content').insert(0, 'still syncing');

      expect(provider.stallReason).toBeNull();
      expect(onStallChange).not.toHaveBeenCalled();
      expect(documentFrom(sentMessages('sync')[0].payload)).toBe('still syncing');
    });
  });

  describe('when updates stay unacknowledged', () => {
    let onStallChange;

    const rejectLatest = () =>
      callbacks.received({
        type: 'document_full',
        messageId: sentMessages('sync').at(-1).messageId,
      });

    beforeEach(() => {
      onStallChange = jest.fn();
      provider.destroy();
      provider = new ActionCableProvider({
        channel: 'CollaborativeEditing::WikiPageChannel',
        channelParams,
        onStallChange,
      });
      connectAndInit();
      provider.doc.getText('content').insert(0, 'unsynchronized');
    });

    it('does not report a stall while a full document may still be compacted', () => {
      rejectLatest();
      jest.advanceTimersByTime(5000);
      rejectLatest();
      jest.advanceTimersByTime(10000);

      expect(provider.stallReason).toBeNull();
      expect(onStallChange).not.toHaveBeenCalled();
    });

    it('reports a stall once the document stays full', () => {
      for (const delay of [5000, 10000, 20000]) {
        rejectLatest();
        jest.advanceTimersByTime(delay);
      }

      expect(provider.stallReason).toBe('unacknowledged');
      expect(onStallChange).toHaveBeenCalledTimes(1);
      expect(onStallChange).toHaveBeenCalledWith('unacknowledged');
    });

    it('reports a stall when the server stays silent', () => {
      jest.advanceTimersByTime(35000);

      expect(provider.stallReason).toBe('unacknowledged');
    });

    it('keeps retrying and recovers once the server acknowledges', () => {
      jest.advanceTimersByTime(35000);
      const sentWhenStalled = sentMessages('sync').length;
      jest.advanceTimersByTime(40000);

      expect(sentMessages('sync')).toHaveLength(sentWhenStalled + 1);

      acknowledge(sentMessages('sync').at(-1));

      expect(provider.stallReason).toBeNull();
      expect(onStallChange).toHaveBeenLastCalledWith(null);
    });

    it('starts counting again after an acknowledgement', () => {
      jest.advanceTimersByTime(15000);
      acknowledge(sentMessages('sync').at(-1));
      provider.doc.getText('content').insert(0, 'more ');
      jest.advanceTimersByTime(15000);

      expect(provider.stallReason).toBeNull();
    });
  });

  describe('identityFor', () => {
    const remoteClientId = 42;

    const receiveAwareness = ({ user } = {}) => {
      const remoteDoc = new Y.Doc();
      remoteDoc.clientID = remoteClientId;
      const remoteAwareness = new Awareness(remoteDoc);
      remoteAwareness.setLocalStateField('cursor', null);

      callbacks.received({
        type: 'awareness',
        payload: bytesToBase64(encodeAwarenessUpdate(remoteAwareness, [remoteClientId])),
        clientId: remoteClientId,
        user,
      });

      remoteAwareness.destroy();
    };

    beforeEach(() => {
      connectAndInit();
    });

    it('returns null for a client that has not been seen', () => {
      expect(provider.identityFor(remoteClientId)).toBeNull();
    });

    it('records the identity the server stamped on an awareness relay', () => {
      receiveAwareness({ user: identity });

      expect(provider.identityFor(remoteClientId)).toEqual(identity);
    });

    it('returns null when the server stamped no identity', () => {
      receiveAwareness();

      expect(provider.identityFor(remoteClientId)).toBeNull();
    });

    it('forgets the identity once the client leaves', () => {
      receiveAwareness({ user: identity });

      removeAwarenessStates(provider.awareness, [remoteClientId], null);

      expect(provider.identityFor(remoteClientId)).toBeNull();
    });
  });

  describe('when the subscription is rejected', () => {
    beforeEach(() => {
      provider.connect();
      callbacks.rejected();
    });

    it('logs the rejection', () => {
      expect(logError).toHaveBeenCalled();
    });

    it('resolves whenSynced so the editor still loads its content', async () => {
      await expect(provider.whenSynced).resolves.toEqual({ seed: true });
    });
  });

  describe('seed', () => {
    beforeEach(() => {
      connectAndInit({ seed: true });
    });

    it('produces identical updates whichever client seeds', async () => {
      const other = new ActionCableProvider({ channel: 'c', channelParams });

      await provider.seed(() => provider.doc.getText('content').insert(0, 'seeded'));
      await other.seed(() => other.doc.getText('content').insert(0, 'seeded'));

      expect(Y.encodeStateAsUpdate(other.doc)).toEqual(Y.encodeStateAsUpdate(provider.doc));

      other.destroy();
    });

    it('converges rather than duplicating when two clients both seed', async () => {
      const other = new ActionCableProvider({ channel: 'c', channelParams });

      await provider.seed(() => provider.doc.getText('content').insert(0, 'seeded'));
      await other.seed(() => other.doc.getText('content').insert(0, 'seeded'));

      Y.applyUpdate(provider.doc, Y.encodeStateAsUpdate(other.doc));

      expect(provider.doc.getText('content').toString()).toBe('seeded');

      other.destroy();
    });

    it('reports its own seed, but not local edits, and keeps it once the content is deleted', async () => {
      provider.doc.getText('content').insert(0, 'typed');

      expect(provider.seeded).toBe(false);

      await provider.seed(() => provider.doc.getText('content').insert(0, 'seeded'));
      provider.doc.getText('content').delete(0, 11);

      expect(provider.doc.getText('content').toString()).toBe('');
      expect(provider.seeded).toBe(true);
    });

    it('reports a seed that had no content to write', async () => {
      await provider.seed(() => {});

      expect(provider.seeded).toBe(true);
    });

    it('reports a seed received from another client', async () => {
      const other = new ActionCableProvider({ channel: 'c', channelParams });

      await other.seed(() => other.doc.getText('content').insert(0, 'seeded'));
      callbacks.received({
        type: 'sync',
        payload: bytesToBase64(Y.encodeStateAsUpdate(other.doc)),
        clientId: -1,
      });

      expect(provider.seeded).toBe(true);

      other.destroy();
    });

    it('restores the original clientID afterwards', async () => {
      const { clientID } = provider.doc;

      await provider.seed(() => {});

      expect(provider.doc.clientID).toBe(clientID);
    });

    it('restores the original clientID when seeding throws', async () => {
      const { clientID } = provider.doc;

      await expect(
        provider.seed(() => {
          throw new Error('deserialization failed');
        }),
      ).rejects.toThrow('deserialization failed');

      expect(provider.doc.clientID).toBe(clientID);
    });
  });

  describe('destroy', () => {
    it('clears a pending retry when the editor closes', () => {
      connectAndInit();
      provider.doc.getText('content').insert(0, 'unsaved');

      provider.destroy();
      jest.advanceTimersByTime(60000);

      expect(sentMessages('sync')).toHaveLength(1);
    });

    it('announces departure before unsubscribing', () => {
      connectAndInit();
      provider.awareness.setLocalStateField('cursor', { anchor: 1 });
      const peerAwareness = new Awareness(new Y.Doc());
      const [initialAnnouncement] = sentMessages('awareness').slice(-1);
      applyAwarenessUpdate(peerAwareness, decodePayload(initialAnnouncement.payload), null);
      expect(peerAwareness.getStates().has(provider.doc.clientID)).toBe(true);
      subscription.send.mockClear();

      provider.destroy();

      expect(sentMessages('awareness')).toHaveLength(1);
      expect(subscription.send.mock.invocationCallOrder[0]).toBeLessThan(
        subscription.unsubscribe.mock.invocationCallOrder[0],
      );

      const [departure] = sentMessages('awareness');
      applyAwarenessUpdate(peerAwareness, decodePayload(departure.payload), null);

      expect(peerAwareness.getStates().has(provider.doc.clientID)).toBe(false);
      peerAwareness.destroy();
    });

    it('unsubscribes so the WebSocket does not stay open', () => {
      connectAndInit();

      provider.destroy();

      expect(subscription.unsubscribe).toHaveBeenCalled();
    });

    it('can be called twice', () => {
      connectAndInit();

      provider.destroy();

      expect(() => provider.destroy()).not.toThrow();
    });
  });
});

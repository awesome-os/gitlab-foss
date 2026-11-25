import * as Y from 'yjs';
import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate } from 'y-protocols/awareness';
import cable from '~/actioncable_consumer';
import { logError } from '~/lib/logger';
import { bytesToBase64, base64ToBytes } from './encoding';
import VersionChain from './version_chain';

const MESSAGE_TYPE_AWARENESS = 'awareness';
const MESSAGE_TYPE_ACK = 'ack';
const MESSAGE_TYPE_DOCUMENT_FULL = 'document_full';
const MESSAGE_TYPE_INIT = 'init';
const MESSAGE_TYPE_PAYLOAD_TOO_LARGE = 'payload_too_large';
const MESSAGE_TYPE_REQUEST_SNAPSHOT = 'request_snapshot';
const MESSAGE_TYPE_SESSION_INVALIDATED = 'session_invalidated';
const MESSAGE_TYPE_SNAPSHOT = 'snapshot';
const MESSAGE_TYPE_SYNC = 'sync';
const MESSAGE_TYPE_VERSION = 'version';

export const STALL_REASON_PAYLOAD_TOO_LARGE = 'payload_too_large';
export const STALL_REASON_UNACKNOWLEDGED = 'unacknowledged';
export const STALL_REASON_SESSION_INVALIDATED = 'session_invalidated';
export const STALL_REASON_LOOKUP_FAILED = 'lookup_failed';
export const SAVE_REJECTION_BUSY = 'busy';

const SUBSCRIPTION_REJECTED_ERROR = 'Collaborative editing subscription was rejected';
const MALFORMED_PAYLOAD_ERROR = 'Discarded a malformed collaborative editing payload';
const RETRY_DELAY_MS = 5000;
const MAX_RETRY_DELAY_MS = 60000;
const INITIAL_STATE_TIMEOUT_MS = 10000;
const SAVE_TIMEOUT_MS = 10000;
const STALLED_AFTER_RETRIES = 3;
const MAX_INITIAL_MESSAGES = 2000;
const MAX_INITIAL_BYTES = 16 * 1024 * 1024;

function discardingMalformed(messageType, apply) {
  try {
    apply();
  } catch (error) {
    logError(MALFORMED_PAYLOAD_ERROR, messageType, error);
  }
}

export default class ActionCableProvider {
  static SEED_CLIENT_ID = 0;

  #docUpdateHandler;
  #awarenessUpdateHandler;
  #resolveSynced;
  #resendFullState = false;
  #nextMessageId = 0;
  #pendingMessageId = null;
  #queuedUpdates = [];
  #retryTimer = null;
  #retryDelay = RETRY_DELAY_MS;
  #unacknowledgedRetries = 0;
  #initialStateReceived = false;
  #sessionId = null;
  #initialMessages = [];
  #initialBytes = 0;
  #initialTimer = null;
  #initialTimeout = INITIAL_STATE_TIMEOUT_MS;
  #save = null;
  #versionChain;
  #saveSequence = 0;

  constructor({
    channel,
    channelParams,
    version,
    onVersionChange = () => {},
    onStallChange = () => {},
  }) {
    this.doc = new Y.Doc();
    this.awareness = new Awareness(this.doc);
    this.channel = channel;
    this.channelParams = channelParams;
    this.onStallChange = onStallChange;
    this.identities = new Map();
    this.subscription = null;
    this.connected = false;
    this.synced = false;
    this.stallReason = null;
    this.onVersionChange = onVersionChange;
    this.#versionChain = new VersionChain(version, (adopted) => this.onVersionChange(adopted));

    this.whenSynced = new Promise((resolve) => {
      this.#resolveSynced = resolve;
    });

    this.#docUpdateHandler = this.#onDocUpdate.bind(this);
    this.#awarenessUpdateHandler = this.#onAwarenessUpdate.bind(this);
  }

  get version() {
    return this.#versionChain.version;
  }

  get seeded() {
    const stateVector = Y.decodeStateVector(Y.encodeStateVector(this.doc));

    return stateVector.has(ActionCableProvider.SEED_CLIENT_ID);
  }

  connect() {
    this.doc.on('update', this.#docUpdateHandler);
    this.awareness.on('update', this.#awarenessUpdateHandler);
    this.#subscribe();
  }

  #subscribe() {
    this.subscription = cable.subscriptions.create(
      { channel: this.channel, ...this.channelParams },
      {
        connected: () => {
          this.connected = true;
          if (this.#invalidated) return;
          this.subscription.perform('initialize_session', {
            version: this.version,
            sessionId: this.#sessionId,
          });
          if (!this.#initialStateReceived) {
            this.#initialTimer = setTimeout(() => this.#onInitialTimeout(), this.#initialTimeout);
          }
          if (this.synced && this.#initialStateReceived) {
            this.awareness.setLocalState(this.awareness.getLocalState());
          }
          if (this.#resendFullState) this.#flushFullState();
        },
        disconnected: () => {
          this.#rejectSave('disconnected');
          this.connected = false;
          this.#clearRetry();
          this.#retryDelay = RETRY_DELAY_MS;
          this.#unacknowledgedRetries = 0;
          if (this.#pendingMessageId !== null) this.#resendFullState = true;
          this.#pendingMessageId = null;
          this.#queuedUpdates = [];
          this.#initialStateReceived = false;
          this.#clearInitialTimer();
          this.#clearInitialMessages();
        },
        rejected: () => {
          logError(SUBSCRIPTION_REJECTED_ERROR);
          this.#invalidateSession();
        },
        received: (message) => this.#onMessage(message),
      },
    );
  }

  async seed(populate) {
    const { clientID } = this.doc;
    this.doc.clientID = ActionCableProvider.SEED_CLIENT_ID;

    try {
      await populate();
      this.doc.getMap('seed').set('complete', true);
    } finally {
      this.doc.clientID = clientID;
    }
  }

  destroy() {
    this.#rejectSave('disconnected');
    this.#clearRetry();
    this.#clearInitialMessages();
    this.#clearInitialTimer();
    this.awareness.destroy();

    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }

    this.doc.off('update', this.#docUpdateHandler);
    this.doc.destroy();
    this.identities.clear();
    this.connected = false;
  }

  identityFor(clientId) {
    return this.identities.get(clientId) ?? null;
  }

  startSave() {
    if (this.#save || !this.connected || !this.#initialStateReceived || this.stallReason) {
      return Promise.reject(new Error('unsynchronised'));
    }
    this.#saveSequence += 1;
    const saveId = `${this.doc.clientID}-${this.#saveSequence}`;
    this.#nextMessageId += 1;
    const messageId = this.#nextMessageId;
    this.#clearRetry();
    this.#pendingMessageId = null;
    this.#queuedUpdates = [];
    this.#resendFullState = false;
    this.#versionChain.recordSave(saveId);
    return new Promise((resolve, reject) => {
      this.#save = {
        messageId,
        saveId,
        resolve,
        reject,
        timer: setTimeout(() => this.#rejectSave('timeout'), SAVE_TIMEOUT_MS),
      };
      if (!this.#send(MESSAGE_TYPE_SYNC, Y.encodeStateAsUpdate(this.doc), { messageId, saveId })) {
        this.#rejectSave('disconnected');
      }
    });
  }

  #rejectSave(reason) {
    if (!this.#save) return;
    const pending = this.#save;
    this.#save = null;
    clearTimeout(pending.timer);
    pending.reject(new Error(reason));
    if (reason === SAVE_REJECTION_BUSY) {
      this.#flushQueuedUpdates();
    } else {
      this.#queuedUpdates = [];
      this.#resendFullState = true;
      if (
        this.connected &&
        this.#initialStateReceived &&
        !['disconnected', 'invalidated'].includes(reason)
      )
        this.#scheduleRetry();
    }
  }

  #flushQueuedUpdates() {
    if (!this.#queuedUpdates.length) return;
    const update = Y.mergeUpdates(this.#queuedUpdates);
    this.#queuedUpdates = [];
    this.#onDocUpdate(update);
  }

  #onMessage(message) {
    if (this.#invalidated) return;

    switch (message.type) {
      case MESSAGE_TYPE_VERSION:
        if (!this.#initialStateReceived) {
          this.#bufferInitialMessage(message);
          break;
        }
        this.#versionChain.recordVersion(message);
        break;
      case MESSAGE_TYPE_SESSION_INVALIDATED:
        this.#invalidateSession(message.reason);
        break;
      case MESSAGE_TYPE_INIT:
        this.#applyInitialState(message);
        break;
      case MESSAGE_TYPE_SYNC:
        if (!this.#initialStateReceived) {
          this.#bufferInitialMessage(message);
          break;
        }
        this.#applyRemoteUpdate(message);
        break;
      case MESSAGE_TYPE_AWARENESS:
        if (!this.#initialStateReceived) {
          this.#bufferInitialMessage(message);
          break;
        }
        this.#applyRemoteAwareness(message);
        break;
      case MESSAGE_TYPE_REQUEST_SNAPSHOT:
        this.#sendSnapshot(message.token);
        break;
      case MESSAGE_TYPE_DOCUMENT_FULL:
        if (this.#save && message.messageId === this.#save.messageId)
          this.#rejectSave('document_full');
        if (message.messageId !== this.#pendingMessageId) break;
        this.#resendFullState = true;
        this.#pendingMessageId = null;
        this.#queuedUpdates = [];
        if (this.connected && this.#initialStateReceived) this.#scheduleRetry();
        break;
      case MESSAGE_TYPE_PAYLOAD_TOO_LARGE:
        this.#rejectSave('payload_too_large');
        if (this.#pendingMessageId === null) break;
        this.#clearRetry();
        this.#queuedUpdates = [];
        this.#resendFullState = true;
        this.#setStallReason(STALL_REASON_PAYLOAD_TOO_LARGE);
        break;
      case MESSAGE_TYPE_ACK:
        if (this.#save && message.messageId === this.#save.messageId) {
          if (message.saveAccepted !== true) {
            this.#rejectSave(SAVE_REJECTION_BUSY);
          } else {
            const pending = this.#save;
            this.#save = null;
            clearTimeout(pending.timer);
            pending.resolve({ sessionId: this.#sessionId, saveId: pending.saveId });
            this.#flushQueuedUpdates();
          }
          break;
        }
        if (this.#pendingMessageId !== null && message.messageId === this.#pendingMessageId) {
          this.#pendingMessageId = null;
          this.#clearRetry();
          this.#retryDelay = RETRY_DELAY_MS;
          this.#unacknowledgedRetries = 0;
          this.#setStallReason(null);
          if (this.#queuedUpdates.length) {
            const update = Y.mergeUpdates(this.#queuedUpdates);
            this.#queuedUpdates = [];
            this.#onDocUpdate(update);
          }
        }
        break;
      default:
        break;
    }
  }

  #applyInitialState({ updates = [], seed = false, sessionId, version }) {
    if (
      typeof sessionId !== 'string' ||
      !sessionId ||
      typeof version !== 'string' ||
      !version ||
      (this.#sessionId !== null && this.#sessionId !== sessionId)
    ) {
      this.#invalidateSession();
      return;
    }

    this.#sessionId = sessionId;
    this.#clearInitialTimer();
    this.#initialTimeout = INITIAL_STATE_TIMEOUT_MS;
    this.#initialStateReceived = true;
    this.doc.transact(() => {
      updates.forEach((update) => this.#applyDocUpdate(update, MESSAGE_TYPE_INIT));
    }, this);

    const buffered = this.#initialMessages;
    this.#clearInitialMessages();
    this.#versionChain.reset(version);
    buffered.forEach((message) => this.#onMessage(message));
    if (this.synced && this.connected) this.awareness.setLocalState(this.awareness.getLocalState());
    this.#markSynced({ seed });
    if (this.#resendFullState) this.#flushFullState();
    else if (this.stallReason === STALL_REASON_UNACKNOWLEDGED) this.#setStallReason(null);
  }

  #applyRemoteUpdate({ payload, clientId, saveId }) {
    if (clientId === this.doc.clientID) return;

    if (this.#applyDocUpdate(payload, MESSAGE_TYPE_SYNC)) this.#versionChain.recordSave(saveId);
  }

  #applyDocUpdate(payload, messageType) {
    let applied = false;
    discardingMalformed(messageType, () => {
      Y.applyUpdate(this.doc, base64ToBytes(payload), this);
      applied = true;
    });
    return applied;
  }

  #applyRemoteAwareness({ payload, clientId, user }) {
    if (clientId === this.doc.clientID) return;

    if (user) {
      this.identities.set(clientId, user);
    }

    discardingMalformed(MESSAGE_TYPE_AWARENESS, () =>
      applyAwarenessUpdate(this.awareness, base64ToBytes(payload), this),
    );
  }

  #markSynced({ seed }) {
    if (this.synced) return;

    this.synced = true;
    this.#resolveSynced({ seed });

    this.#sendAwareness([this.doc.clientID]);
  }

  #setStallReason(reason) {
    if (this.#invalidated) return;
    if (this.stallReason === reason) return;

    this.stallReason = reason;
    this.onStallChange(reason);
  }

  get #invalidated() {
    return [STALL_REASON_SESSION_INVALIDATED, STALL_REASON_LOOKUP_FAILED].includes(
      this.stallReason,
    );
  }

  #invalidateSession(reason) {
    this.#rejectSave('invalidated');
    this.#clearRetry();
    this.#clearInitialTimer();
    this.#clearInitialMessages();
    this.#queuedUpdates = [];
    this.#pendingMessageId = null;
    this.#resendFullState = false;
    this.#setStallReason(
      reason === STALL_REASON_LOOKUP_FAILED
        ? STALL_REASON_LOOKUP_FAILED
        : STALL_REASON_SESSION_INVALIDATED,
    );
    this.#markSynced({ seed: true });
  }

  #bufferInitialMessage(message) {
    this.#initialBytes += typeof message.payload === 'string' ? message.payload.length : 0;
    if (
      this.#initialMessages.length >= MAX_INITIAL_MESSAGES ||
      this.#initialBytes > MAX_INITIAL_BYTES
    ) {
      this.#invalidateSession();
      return;
    }
    this.#initialMessages.push(message);
  }

  #clearInitialMessages() {
    this.#initialMessages = [];
    this.#initialBytes = 0;
  }

  #clearInitialTimer() {
    if (this.#initialTimer !== null) clearTimeout(this.#initialTimer);
    this.#initialTimer = null;
  }

  #onInitialTimeout() {
    if (this.#sessionId === null) {
      this.#invalidateSession(STALL_REASON_LOOKUP_FAILED);
      return;
    }

    this.#initialTimeout = Math.min(this.#initialTimeout * 2, MAX_RETRY_DELAY_MS);
    this.#clearInitialMessages();
    if (!this.stallReason) this.#setStallReason(STALL_REASON_UNACKNOWLEDGED);
    this.subscription.unsubscribe();
    this.#subscribe();
  }

  get #payloadTooLarge() {
    return this.stallReason === STALL_REASON_PAYLOAD_TOO_LARGE;
  }

  #onDocUpdate(update, origin) {
    if (origin === this || this.#invalidated) return;
    if (this.#save) {
      this.#queuedUpdates.push(update);
      return;
    }

    if (!this.#initialStateReceived || this.#payloadTooLarge) {
      this.#resendFullState = true;
      return;
    }

    if (this.#pendingMessageId !== null) {
      this.#queuedUpdates.push(update);
      return;
    }

    if (this.#resendFullState) {
      if (this.#retryTimer === null) this.#flushFullState();
      return;
    }

    this.#nextMessageId += 1;
    const messageId = this.#nextMessageId;
    if (this.#send(MESSAGE_TYPE_SYNC, update, { messageId })) {
      this.#pendingMessageId = messageId;
      this.#scheduleRetry();
    } else {
      this.#resendFullState = true;
    }
  }

  #flushFullState() {
    if (!this.#resendFullState || !this.connected || !this.#initialStateReceived) return;
    if (this.#payloadTooLarge) return;

    this.#nextMessageId += 1;
    const messageId = this.#nextMessageId;
    if (this.#send(MESSAGE_TYPE_SYNC, Y.encodeStateAsUpdate(this.doc), { messageId })) {
      this.#pendingMessageId = messageId;
      this.#resendFullState = false;
      this.#scheduleRetry();
    }
  }

  #scheduleRetry() {
    this.#clearRetry();
    this.#retryTimer = setTimeout(() => {
      if (!this.connected) return;
      this.#pendingMessageId = null;
      this.#queuedUpdates = [];
      this.#resendFullState = true;
      this.#retryDelay = Math.min(this.#retryDelay * 2, MAX_RETRY_DELAY_MS);
      this.#unacknowledgedRetries += 1;
      if (this.#unacknowledgedRetries >= STALLED_AFTER_RETRIES) {
        this.#setStallReason(STALL_REASON_UNACKNOWLEDGED);
      }
      this.#flushFullState();
    }, this.#retryDelay);
  }

  #clearRetry() {
    if (this.#retryTimer !== null) clearTimeout(this.#retryTimer);
    this.#retryTimer = null;
  }

  #onAwarenessUpdate({ added, updated, removed }, origin) {
    removed.forEach((clientId) => this.identities.delete(clientId));

    if (origin === this) return;

    this.#sendAwareness([...added, ...updated, ...removed]);
  }

  #sendAwareness(clientIds) {
    this.#send(MESSAGE_TYPE_AWARENESS, encodeAwarenessUpdate(this.awareness, clientIds));
  }

  #sendSnapshot(token) {
    if (!token || this.#save || !this.#initialStateReceived || this.#payloadTooLarge) return;

    this.#nextMessageId += 1;
    const messageId = this.#nextMessageId;
    if (this.#send(MESSAGE_TYPE_SNAPSHOT, Y.encodeStateAsUpdate(this.doc), { token, messageId })) {
      if (this.#pendingMessageId !== null || this.#resendFullState) {
        this.#pendingMessageId = messageId;
        this.#queuedUpdates = [];
        this.#resendFullState = false;
        this.#scheduleRetry();
      }
    }
  }

  #send(type, bytes, extra = {}) {
    if (!this.connected || !this.subscription || !this.#initialStateReceived || this.#invalidated)
      return false;

    this.subscription.send({
      type,
      payload: bytesToBase64(bytes),
      clientId: this.doc.clientID,
      sessionId: this.#sessionId,
      ...extra,
    });

    return true;
  }
}

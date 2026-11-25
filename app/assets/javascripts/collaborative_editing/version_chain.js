const MAX_ENTRIES = 100;

function forgetOldest(collection) {
  if (collection.size > MAX_ENTRIES) collection.delete(collection.keys().next().value);
}

export default class VersionChain {
  #appliedSaves = new Set();
  #events = new Map();
  #history = new Set();

  constructor(version, onChange) {
    this.version = version;
    this.onChange = onChange;
  }

  reset(version) {
    this.#appliedSaves.clear();
    this.#events.clear();
    this.#history.clear();
    this.#history.add(version);
    this.version = version;
    this.onChange(version);
  }

  recordSave(saveId) {
    if (!saveId) return;
    this.#appliedSaves.add(saveId);
    forgetOldest(this.#appliedSaves);
    this.#advance();
  }

  recordVersion(event) {
    if (this.#history.has(event.version)) return;
    this.#events.set(event.previousVersion, event);
    forgetOldest(this.#events);
    this.#advance();
  }

  #advance() {
    const seen = new Set();
    let event = this.#events.get(this.version);
    while (event && this.#appliedSaves.has(event.saveId) && !seen.has(event.version)) {
      seen.add(this.version);
      this.#events.delete(this.version);
      this.version = event.version;
      this.#history.add(this.version);
      forgetOldest(this.#history);
      this.onChange(this.version);
      event = this.#events.get(this.version);
    }
  }
}

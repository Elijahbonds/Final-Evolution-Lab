/**
 * Offline-first local storage cache and sync queue.
 */
export class OfflineCacheSystem {
  /**
   * Creates an offline cache namespace.
   *
   * @param {string} [namespace='fel']
   */
  constructor(namespace = 'fel') {
    this.namespace = namespace || 'fel';
    this.memoryStore = new Map();
    this.queueKey = this.keyFor('pending-sync-queue');
  }

  /**
   * Saves a value into storage.
   *
   * @param {string} key
   * @param {*} value
   * @returns {*} The saved value.
   */
  save(key, value) {
    const serialised = JSON.stringify(value);
    this.write(this.keyFor(key), serialised);
    return value;
  }

  /**
   * Loads a value from storage.
   *
   * @param {string} key
   * @param {*} [fallback=null]
   * @returns {*}
   */
  load(key, fallback = null) {
    const raw = this.read(this.keyFor(key));

    if (raw === null || raw === undefined) {
      return fallback;
    }

    try {
      return JSON.parse(raw);
    } catch (error) {
      return fallback;
    }
  }

  /**
   * Queues a payload for later sync.
   *
   * @param {*} payload
   * @returns {number} Current queue length.
   */
  queueSync(payload) {
    const queue = this.loadQueue();
    queue.push({
      payload,
      queuedAt: Date.now(),
    });
    this.write(this.queueKey, JSON.stringify(queue));
    return queue.length;
  }

  /**
   * Flushes queued sync payloads.
   *
   * @returns {Array<{ payload: *, queuedAt: number }>}
   */
  flushQueue() {
    const queue = this.loadQueue();
    this.write(this.queueKey, JSON.stringify([]));
    return queue;
  }

  /**
   * Reports whether the client is offline.
   *
   * @returns {boolean}
   */
  isOffline() {
    if (typeof navigator === 'undefined') {
      return false;
    }

    return !navigator.onLine;
  }

  /**
   * @private
   * @param {string} key
   * @returns {string}
   */
  keyFor(key) {
    return `${this.namespace}:${key}`;
  }

  /**
   * @private
   * @returns {Array<{ payload: *, queuedAt: number }>}
   */
  loadQueue() {
    const queue = this.load('pending-sync-queue', []);
    return Array.isArray(queue) ? queue : [];
  }

  /**
   * @private
   * @param {string} key
   * @returns {string|null}
   */
  read(key) {
    if (typeof localStorage !== 'undefined') {
      return localStorage.getItem(key);
    }

    return this.memoryStore.has(key) ? this.memoryStore.get(key) : null;
  }

  /**
   * @private
   * @param {string} key
   * @param {string} value
   * @returns {void}
   */
  write(key, value) {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(key, value);
      return;
    }

    this.memoryStore.set(key, value);
  }
}

export default OfflineCacheSystem;

/**
 * SensoryBus — frame-synced sensory event bus (mode-agnostic).
 *
 * One contact event → camera shake (∝ impulse) + zero-latency file SFX +
 * gamepad rumble + optional hit-stop, all fired on the SAME frame. This is
 * what makes impacts read as weight instead of a stat change.
 *
 * SFX uses WebAudio with preloaded/decoded buffers (zero-latency start).
 * Missing files, blocked autoplay, and absent gamepads all degrade silently
 * — the bus never throws into gameplay.
 */
export class SensoryBus {
  /**
   * @param {{ camera?: { applyCameraShake?: (intensity: number) => void },
   *           loop?: { hitStop?: (ms: number) => void },
   *           sfx?: Record<string, string> }} opts
   *   sfx — map of sound name → URL (preloaded on construction).
   */
  constructor({ camera, loop, sfx = {} } = {}) {
    this.camera = camera ?? null;
    this.loop = loop ?? null;
    this._buffers = Object.create(null);
    this._ctx = null;
    this.stats = { emitted: 0, sfxPlayed: 0, shakes: 0, hitStops: 0, rumbles: 0 };
    this._preload(sfx);
  }

  /** @private */
  async _preload(sfx) {
    if (typeof window === 'undefined') return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    try { this._ctx = new AC(); } catch { return; }
    await Promise.all(Object.entries(sfx).map(async ([name, url]) => {
      try {
        const res = await fetch(url);
        const raw = await res.arrayBuffer();
        this._buffers[name] = await this._ctx.decodeAudioData(raw);
      } catch { /* missing file → silent degrade */ }
    }));
  }

  /**
   * Fire a sensory event NOW (call from the fixed step / contact handler).
   * @param {{ sfx?: string, volume?: number, shake?: number,
   *           hitStopMs?: number, rumbleMs?: number, rumbleStrength?: number }} fx
   */
  emit(fx = {}) {
    this.stats.emitted++;
    if (fx.sfx) this._playSfx(fx.sfx, fx.volume ?? 1);
    if (fx.shake && this.camera?.applyCameraShake) {
      this.camera.applyCameraShake(fx.shake);
      this.stats.shakes++;
    }
    if (fx.hitStopMs && this.loop?.hitStop) {
      this.loop.hitStop(fx.hitStopMs);
      this.stats.hitStops++;
    }
    if (fx.rumbleMs) this._rumble(fx.rumbleMs, fx.rumbleStrength ?? 0.8);
  }

  /** @private — zero-latency: buffer is pre-decoded, start() is immediate. */
  _playSfx(name, volume) {
    const buf = this._buffers[name];
    if (!buf || !this._ctx) return;
    if (this._ctx.state === 'suspended') this._ctx.resume().catch(() => {});
    try {
      const src = this._ctx.createBufferSource();
      src.buffer = buf;
      const gain = this._ctx.createGain();
      gain.gain.value = volume;
      src.connect(gain).connect(this._ctx.destination);
      src.start();
      this.stats.sfxPlayed++;
    } catch { /* never throw into gameplay */ }
  }

  /** @private */
  _rumble(durationMs, strength) {
    if (typeof navigator === 'undefined' || !navigator.getGamepads) return;
    try {
      for (const gp of navigator.getGamepads()) {
        const act = gp?.vibrationActuator;
        if (act?.playEffect) {
          act.playEffect('dual-rumble', {
            duration: durationMs,
            strongMagnitude: strength,
            weakMagnitude: strength * 0.6,
          }).catch(() => {});
          this.stats.rumbles++;
        }
      }
    } catch { /* silent */ }
  }

  dispose() {
    this._ctx?.close?.().catch?.(() => {});
    this._ctx = null;
    this._buffers = Object.create(null);
  }
}

export default SensoryBus;

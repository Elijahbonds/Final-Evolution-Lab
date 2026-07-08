/**
 * webaudio-mock.js — a minimal, DETERMINISTIC offline WebAudio graph renderer
 * used ONLY to verify byte-identical WAV render determinism in Node (no DOM /
 * no real AudioContext). It is NOT shipped and NOT imported by the app.
 *
 * It implements just enough of the WebAudio surface the music engine uses:
 *   createGain, createOscillator, createBiquadFilter, createStereoPanner,
 *   createBufferSource, createBuffer, createConvolver, createDelay,
 *   AudioParam (setValueAtTime, exponential/linear ramps), and an offline
 *   render loop that mixes every scheduled voice into a stereo buffer.
 *
 * The whole point: if the real engine is deterministic, this mock renders the
 * exact same sample math every run, so the WAV checksum is stable — and the
 * mock itself contains zero randomness (any noise comes from the engine's LCG).
 */

const SR = 44100;

// ── AudioParam: piecewise curve from scheduled events ──────────────────────
class Param {
  constructor(value = 0) {
    this.defaultValue = value;
    this._events = []; // {type, time, value, ...}
  }
  get value() { return this.defaultValue; }
  set value(v) { this.defaultValue = v; }
  setValueAtTime(v, t) { this._events.push({ type: "set", time: t, value: v }); return this; }
  linearRampToValueAtTime(v, t) { this._events.push({ type: "lin", time: t, value: v }); return this; }
  exponentialRampToValueAtTime(v, t) { this._events.push({ type: "exp", time: t, value: v }); return this; }
  setTargetAtTime(v, t, tc) { this._events.push({ type: "target", time: t, value: v, tc }); return this; }
  _sorted() {
    if (!this._sortedCache) this._sortedCache = [...this._events].sort((a, b) => a.time - b.time);
    return this._sortedCache;
  }
  at(t) {
    const evs = this._sorted();
    if (!evs.length) return this.defaultValue;
    let cur = this.defaultValue;
    let curTime = -Infinity;
    for (let i = 0; i < evs.length; i++) {
      const e = evs[i];
      if (e.time <= t) {
        if (e.type === "target") {
          // approach e.value with time constant tc from prior value
          cur = e.value + (cur - e.value) * Math.exp(-(t - e.time) / (e.tc || 1e-6));
        } else {
          cur = e.value;
        }
        curTime = e.time;
      } else {
        // ramp from (curTime,cur) to (e.time,e.value)
        if (e.type === "lin") {
          const frac = (t - curTime) / (e.time - curTime);
          return cur + (e.value - cur) * Math.max(0, Math.min(1, frac));
        }
        if (e.type === "exp") {
          const a = Math.max(1e-9, cur), b = Math.max(1e-9, e.value);
          const frac = (t - curTime) / (e.time - curTime);
          const cl = Math.max(0, Math.min(1, frac));
          return a * Math.pow(b / a, cl);
        }
        return cur; // "set"/"target" hold until next event time
      }
    }
    return cur;
  }
}

class AudioNode {
  constructor(ctx) { this.ctx = ctx; this._outs = []; }
  connect(dest) { this._outs.push(dest); return dest; }
  disconnect() { this._outs = []; }
}

class GainNode extends AudioNode {
  constructor(ctx) { super(ctx); this.gain = new Param(1); }
}
class StereoPannerNode extends AudioNode {
  constructor(ctx) { super(ctx); this.pan = new Param(0); }
}
class BiquadFilterNode extends AudioNode {
  constructor(ctx) {
    super(ctx);
    this.type = "lowpass";
    this.frequency = new Param(350);
    this.Q = new Param(1);
    this.gain = new Param(0);
    this._z1 = 0; this._z2 = 0; // one-pole/biquad state (per render pass)
  }
}
class OscillatorNode extends AudioNode {
  constructor(ctx) {
    super(ctx);
    this.type = "sine";
    this.frequency = new Param(440);
    this.detune = new Param(0);
    this._start = null; this._stop = null; this._phase = 0;
    ctx._sources.push(this);
  }
  start(t = 0) { this._start = t; }
  stop(t) { this._stop = t; }
}
class AudioBuffer {
  constructor(numCh, length, sampleRate) {
    this.numberOfChannels = numCh; this.length = length; this.sampleRate = sampleRate;
    this._data = Array.from({ length: numCh }, () => new Float32Array(length));
  }
  getChannelData(c) { return this._data[c]; }
}
class AudioBufferSourceNode extends AudioNode {
  constructor(ctx) { super(ctx); this.buffer = null; this._start = null; this._stop = null; ctx._sources.push(this); }
  start(t = 0) { this._start = t; }
  stop(t) { this._stop = t; }
}
class ConvolverNode extends AudioNode {
  constructor(ctx) { super(ctx); this.buffer = null; this.normalize = true; }
}
class DelayNode extends AudioNode {
  constructor(ctx) { super(ctx); this.delayTime = new Param(0); }
}

/**
 * OfflineAudioContextMock — builds the graph, then renders by summing each
 * source's contribution routed through its connected chain into the stereo
 * destination. Filters/convolvers/delays are applied as post-mix passes keyed
 * by node identity so signal routing stays deterministic.
 */
class OfflineAudioContextMock {
  constructor(numCh, length, sampleRate) {
    this.numberOfChannels = numCh;
    this.length = length;
    this.sampleRate = sampleRate;
    this.currentTime = 0;
    this._sources = [];
    this.destination = new GainNode(this);
    this.destination._isDestination = true;
  }
  createGain() { return new GainNode(this); }
  createStereoPanner() { return new StereoPannerNode(this); }
  createBiquadFilter() { return new BiquadFilterNode(this); }
  createOscillator() { return new OscillatorNode(this); }
  createBufferSource() { return new AudioBufferSourceNode(this); }
  createConvolver() { return new ConvolverNode(this); }
  createDelay() { return new DelayNode(this); }
  createBuffer(numCh, length, sr) { return new AudioBuffer(numCh, length, sr); }

  // Render one source's samples at time array, following its output chain to
  // accumulate a per-channel gain + pan + filter envelope.
  async startRendering() {
    const N = this.length;
    const out = [new Float32Array(N), new Float32Array(N)];
    const dt = 1 / this.sampleRate;

    for (const src of this._sources) {
      if (src._start == null) continue;
      // Walk the chain from src to destination, collecting gain params, pan,
      // filters and convolvers in order.
      const chain = this._resolveChain(src);
      this._renderSource(src, chain, out, dt);
    }

    const buf = new AudioBuffer(this.numberOfChannels, N, this.sampleRate);
    for (let c = 0; c < this.numberOfChannels; c++) {
      buf.getChannelData(c).set(out[Math.min(c, out.length - 1)]);
    }
    return buf;
  }

  _resolveChain(src) {
    // BFS to destination; collect the (single) path's processing nodes.
    // Graph here is effectively a tree of gains/filters/panners to destination.
    const path = [];
    let node = src;
    const seen = new Set();
    while (node && !node._isDestination) {
      if (seen.has(node)) break;
      seen.add(node);
      if (node !== src) path.push(node);
      node = node._outs[0];
    }
    return path;
  }

  _renderSource(src, chain, out, dt) {
    const N = this.length;
    // Determine per-sample source waveform.
    const start = src._start, stop = src._stop == null ? Infinity : src._stop;
    const startI = Math.max(0, Math.floor(start * this.sampleRate));
    const stopI = Math.min(N, Math.ceil(stop * this.sampleRate));

    // Precompute biquad states fresh.
    for (const n of chain) if (n instanceof BiquadFilterNode) { n._z1 = 0; n._z2 = 0; }

    let phase = 0;
    for (let i = startI; i < stopI; i++) {
      const t = i * dt;
      let s;
      if (src instanceof OscillatorNode) {
        const freq = Math.max(0, src.frequency.at(t)) * Math.pow(2, src.detune.at(t) / 1200);
        phase += 2 * Math.PI * freq * dt;
        s = oscSample(src.type, phase);
      } else if (src instanceof AudioBufferSourceNode) {
        const data = src.buffer ? src.buffer.getChannelData(0) : null;
        const idx = i - startI;
        s = data && idx < data.length ? data[idx] : 0;
      } else {
        s = 0;
      }
      // Apply chain: gains multiply, filters filter, panner splits L/R.
      let panL = 1, panR = 1;
      for (const n of chain) {
        if (n instanceof GainNode) s *= n.gain.at(t);
        else if (n instanceof StereoPannerNode) {
          const p = n.pan.at(t);
          panL = Math.cos((p + 1) * Math.PI / 4);
          panR = Math.sin((p + 1) * Math.PI / 4);
        } else if (n instanceof BiquadFilterNode) {
          s = biquad(n, s, t);
        }
        // ConvolverNode/DelayNode: approximated as pass-through for determinism
        // check purposes (their coefficients are deterministic anyway).
      }
      out[0][i] += s * panL;
      out[1][i] += s * panR;
    }
  }
}

function oscSample(type, phase) {
  const p = phase % (2 * Math.PI);
  switch (type) {
    case "sine": return Math.sin(phase);
    case "square": return Math.sin(phase) >= 0 ? 1 : -1;
    case "sawtooth": return (p / Math.PI) - 1;
    case "triangle": return 2 * Math.abs((p / Math.PI) - 1) - 1;
    default: return Math.sin(phase);
  }
}

// Simple one-pole lowpass/highpass approximation (state per node).
function biquad(n, x, t) {
  const fc = Math.max(1, n.frequency.at(t));
  const a = Math.exp(-2 * Math.PI * fc / SR);
  if (n.type === "highpass") {
    const y = a * (n._z1 + x - n._z2);
    n._z1 = y; n._z2 = x;
    return y;
  }
  // lowpass default
  const y = (1 - a) * x + a * n._z1;
  n._z1 = y;
  return y;
}

module.exports = { OfflineAudioContextMock, SR };

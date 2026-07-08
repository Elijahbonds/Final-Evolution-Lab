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
      // A source may fan out to BOTH the dry master and a wet reverb send, so
      // enumerate every simple path to destination and render each — this way
      // the convolver (wet) branch is exercised, giving a real determinism
      // check on the reverb tail, not just the dry signal.
      const paths = this._resolveChains(src);
      for (const chain of paths) this._renderSource(src, chain, out, dt);
    }

    const buf = new AudioBuffer(this.numberOfChannels, N, this.sampleRate);
    for (let c = 0; c < this.numberOfChannels; c++) {
      buf.getChannelData(c).set(out[Math.min(c, out.length - 1)]);
    }
    return buf;
  }

  _resolveChains(src) {
    // Enumerate every simple path from src to destination; each path is the
    // ordered list of processing nodes between src and destination (exclusive).
    const paths = [];
    const walk = (node, acc) => {
      if (!node || node._isDestination) { paths.push(acc); return; }
      const outs = node._outs || [];
      if (!outs.length) return; // dangling branch contributes nothing
      for (const nxt of outs) {
        if (acc.includes(node)) continue; // cycle guard (feedback delay)
        walk(nxt, node === src ? acc : acc.concat(node));
      }
    };
    walk(src, []);
    return paths;
  }

  _renderSource(src, chain, out, dt) {
    const N = this.length;
    const start = src._start, stop = src._stop == null ? Infinity : src._stop;
    const startI = Math.max(0, Math.floor(start * this.sampleRate));
    const stopI = Math.min(N, Math.ceil(stop * this.sampleRate));

    const convIdx = chain.findIndex((n) => n instanceof ConvolverNode);
    if (convIdx >= 0) {
      // Split the chain at the convolver: pre-nodes shape the dry signal, the
      // convolver applies a (deterministic, truncated) FIR from its IR, and the
      // post-nodes apply wet gain/pan. Exercised so the reverb tail is part of
      // the determinism checksum.
      this._renderConvolved(src, chain, convIdx, out, startI, stopI, dt);
      return;
    }

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
      } else { s = 0; }
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
      }
      out[0][i] += s * panL;
      out[1][i] += s * panR;
    }
  }

  // Render a source whose path includes a ConvolverNode. Builds the dry signal
  // through the pre-convolver nodes, convolves with a TRUNCATED IR (first
  // `maxTaps` samples — enough to prove the wet branch is deterministic without
  // an O(N*M) full convolution), then applies the post-convolver gain/pan.
  _renderConvolved(src, chain, convIdx, out, startI, stopI, dt) {
    const pre = chain.slice(0, convIdx);
    const conv = chain[convIdx];
    const post = chain.slice(convIdx + 1);
    for (const n of pre) if (n instanceof BiquadFilterNode) { n._z1 = 0; n._z2 = 0; }

    // Dry signal after pre-nodes.
    const len = stopI - startI;
    if (len <= 0) return;
    const dry = new Float32Array(len);
    let phase = 0;
    for (let i = startI; i < stopI; i++) {
      const t = i * dt;
      let s;
      if (src instanceof OscillatorNode) {
        const freq = Math.max(0, src.frequency.at(t)) * Math.pow(2, src.detune.at(t) / 1200);
        phase += 2 * Math.PI * freq * dt; s = oscSample(src.type, phase);
      } else if (src instanceof AudioBufferSourceNode) {
        const data = src.buffer ? src.buffer.getChannelData(0) : null;
        const idx = i - startI; s = data && idx < data.length ? data[idx] : 0;
      } else { s = 0; }
      for (const n of pre) if (n instanceof GainNode) s *= n.gain.at(t);
      dry[i - startI] = s;
    }

    // Truncated IR taps (deterministic, from the convolver's fixed-seed buffer).
    const ir = conv.buffer ? conv.buffer.getChannelData(0) : new Float32Array([1]);
    // 256 taps is ample to prove the wet branch is deterministic while keeping
    // the harness fast (full-length convolution is O(N*IRlen) and unnecessary
    // for a determinism check — the IR is fixed, so any fixed truncation works).
    const maxTaps = Math.min(ir.length, 256);

    // Post gain/pan are (near-)constant here; sample at the source start.
    const t0 = startI * dt;
    let postGain = 1, panL = 1, panR = 1;
    for (const n of post) {
      if (n instanceof GainNode) postGain *= n.gain.at(t0);
      else if (n instanceof StereoPannerNode) {
        const p = n.pan.at(t0);
        panL = Math.cos((p + 1) * Math.PI / 4);
        panR = Math.sin((p + 1) * Math.PI / 4);
      }
    }

    for (let i = 0; i < len; i++) {
      const x = dry[i];
      if (x === 0) continue;
      for (let k = 0; k < maxTaps; k++) {
        const j = startI + i + k;
        if (j >= out[0].length) break;
        const wet = x * ir[k] * postGain;
        out[0][j] += wet * panL;
        out[1][j] += wet * panR;
      }
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

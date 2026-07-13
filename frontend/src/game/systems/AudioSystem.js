/**
 * AudioSystem — Web Audio API synthesizer for FEL game modes.
 *
 * Generates all sounds procedurally (no external audio files needed).
 * Provides sport-specific audio feedback: score, combo, miss, crowd, impact,
 * countdown, whistle, swoosh, bounce, etc.
 *
 * iOS parity: mirrors FELSoundscapeEngine.swift + FELHaptics.swift (audio side).
 *
 * Usage:
 *   const audio = new AudioSystem();
 *   audio.playEvent('score');
 *   audio.playEvent('combo_hit', { chain: 5 });
 *   audio.playEvent('crowd_swell');
 */

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

function noteToHz(semitones, base = 220) {
  return base * Math.pow(2, semitones / 12);
}

// ---------------------------------------------------------------------------
// AudioSystem class
// ---------------------------------------------------------------------------

export class AudioSystem {
  constructor() {
    this._ctx = null;
    this._masterGain = null;
    this._muted = false;
    this._volume = 0.6;
    this._crowdLoop = null;
    this._crowdGain = null;
    this._initialized = false;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /**
   * Lazily create AudioContext on first user gesture (browser autoplay policy).
   * @returns {AudioContext|null}
   */
  _getCtx() {
    if (this._ctx) return this._ctx;
    if (typeof window === 'undefined') return null;
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return null;
      this._ctx = new Ctx();
      this._masterGain = this._ctx.createGain();
      this._masterGain.gain.value = this._volume;
      this._masterGain.connect(this._ctx.destination);
      this._initialized = true;
      return this._ctx;
    } catch {
      return null;
    }
  }

  /**
   * Resume context after user gesture if it was suspended.
   */
  async resume() {
    const ctx = this._getCtx();
    if (ctx && ctx.state === 'suspended') {
      await ctx.resume();
    }
  }

  setVolume(v) {
    this._volume = clamp(v, 0, 1);
    if (this._masterGain) this._masterGain.gain.value = this._muted ? 0 : this._volume;
  }

  mute()   { this._muted = true;  if (this._masterGain) this._masterGain.gain.value = 0; }
  unmute() { this._muted = false; if (this._masterGain) this._masterGain.gain.value = this._volume; }

  dispose() {
    this._stopCrowdLoop();
    this._ctx?.close();
    this._ctx = null;
    this._masterGain = null;
    this._initialized = false;
  }

  // ── Core synthesis helpers ─────────────────────────────────────────────────

  /**
   * Play a simple tone burst.
   * @param {number} freq      Hz
   * @param {number} duration  seconds
   * @param {number} gain      0–1
   * @param {'sine'|'square'|'sawtooth'|'triangle'} type
   * @param {number} attack    seconds
   * @param {number} decay     seconds
   * @param {number} [startAt] AudioContext time (default: now)
   */
  _tone(freq, duration, gain, type = 'sine', attack = 0.005, decay = 0.05, startAt) {
    const ctx = this._getCtx();
    if (!ctx) return;
    const t = startAt ?? ctx.currentTime;
    const osc = ctx.createOscillator();
    const env = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(gain, t + attack);
    env.gain.exponentialRampToValueAtTime(0.0001, t + duration - decay);
    osc.connect(env);
    env.connect(this._masterGain);
    osc.start(t);
    osc.stop(t + duration);
  }

  /**
   * Play filtered white noise burst (crowd roar, impact).
   */
  _noise(duration, gain, lowHz, highHz, attack = 0.01, startAt) {
    const ctx = this._getCtx();
    if (!ctx) return;
    const t = startAt ?? ctx.currentTime;
    const bufSize = Math.ceil(ctx.sampleRate * duration);
    const buffer = ctx.createBuffer(1, bufSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;

    const src = ctx.createBufferSource();
    src.buffer = buffer;

    const lo = ctx.createBiquadFilter();
    lo.type = 'highpass';
    lo.frequency.value = lowHz;

    const hi = ctx.createBiquadFilter();
    hi.type = 'lowpass';
    hi.frequency.value = highHz;

    const env = ctx.createGain();
    env.gain.setValueAtTime(0, t);
    env.gain.linearRampToValueAtTime(gain, t + attack);
    env.gain.exponentialRampToValueAtTime(0.0001, t + duration - 0.05);

    src.connect(lo);
    lo.connect(hi);
    hi.connect(env);
    env.connect(this._masterGain);
    src.start(t);
    src.stop(t + duration);
  }

  // ── Event map ─────────────────────────────────────────────────────────────

  /**
   * Play an audio event by name.
   *
   * @param {string} eventName — see list below
   * @param {object} [options]
   */
  playEvent(eventName, options = {}) {
    this.resume();
    switch (eventName) {
      case 'score':       return this._playScore(options);
      case 'score_big':   return this._playScoreBig(options);
      case 'combo_hit':   return this._playComboHit(options);
      case 'combo_break': return this._playComboBreak();
      case 'miss':        return this._playMiss();
      case 'dunk':        return this._playDunk(options);
      case 'dunk_miss':   return this._playDunkMiss();
      case 'jump':        return this._playJump();
      case 'strike_light':  return this._playStrikeLight();
      case 'strike_heavy':  return this._playStrikeHeavy();
      case 'strike_special':return this._playStrikeSpecial();
      case 'block':       return this._playBlock();
      case 'dodge':       return this._playDodge();
      case 'hit_receive': return this._playHitReceive();
      case 'ko':          return this._playKO();
      case 'whistle':     return this._playWhistle();
      case 'goal':        return this._playGoal();
      case 'crowd_swell': return this._playCrowdSwell();
      case 'crowd_loop_start': return this._startCrowdLoop(options);
      case 'crowd_loop_stop':  return this._stopCrowdLoop();
      case 'bounce':      return this._playBounce();
      case 'swoosh':      return this._playSwoosh();
      case 'swing_bat':   return this._playSwingBat();
      case 'hit_ball':    return this._playHitBall();
      case 'serve':       return this._playServe();
      case 'ace':         return this._playAce();
      case 'golf_swing':  return this._playGolfSwing();
      case 'golf_putt':   return this._playGolfPutt();
      case 'countdown_tick': return this._playCountdownTick();
      case 'countdown_go':   return this._playCountdownGo();
      case 'match_start': return this._playMatchStart();
      case 'match_end':   return this._playMatchEnd();
      case 'prq_up':      return this._playPRQUp();
      case 'prq_down':    return this._playPRQDown();
      case 'perfect':     return this._playPerfect();
      case 'trick_land':  return this._playTrickLand();
      default:            break;
    }
  }

  // ── Event implementations ──────────────────────────────────────────────────

  _playScore() {
    this._tone(880, 0.18, 0.5, 'sine',   0.004, 0.05);
    this._tone(1318, 0.22, 0.4, 'sine',  0.004, 0.08, this._getCtx()?.currentTime + 0.06);
  }

  _playScoreBig() {
    const ctx = this._getCtx();
    if (!ctx) return;
    const t = ctx.currentTime;
    [440, 554, 659, 880, 1108].forEach((f, i) => {
      this._tone(f, 0.3 + i * 0.05, 0.45, 'sine', 0.004, 0.06, t + i * 0.055);
    });
    this._noise(0.3, 0.12, 800, 4000, 0.01, t);
  }

  _playComboHit({ chain = 1 } = {}) {
    const semi = Math.min(chain - 1, 8) * 1.5;
    const freq = noteToHz(semi, 440);
    this._tone(freq, 0.12, 0.4, 'triangle', 0.003, 0.04);
    if (chain >= 5) this._noise(0.06, 0.08, 2000, 8000, 0.005);
  }

  _playComboBreak() {
    this._tone(220, 0.25, 0.3, 'sawtooth', 0.005, 0.1);
    this._tone(196, 0.2,  0.2, 'square',   0.005, 0.08, this._getCtx()?.currentTime + 0.05);
  }

  _playMiss() {
    this._tone(180, 0.3, 0.3, 'sawtooth', 0.01, 0.12);
  }

  _playDunk({ modifier = 'standard' } = {}) {
    const ctx = this._getCtx();
    if (!ctx) return;
    const t = ctx.currentTime;
    // Slam impact
    this._noise(0.15, 0.6, 40, 200, 0.005, t);
    // Rim ring
    this._tone(1760, 0.4, 0.35, 'sine', 0.002, 0.25, t + 0.02);
    // Net swish
    this._noise(0.2, 0.25, 3000, 10000, 0.01, t + 0.05);
    // Score fanfare
    const base = modifier === 'signature' ? 660 : modifier === 'power' ? 587 : 523;
    this._tone(base,       0.3, 0.4, 'sine', 0.01, 0.08, t + 0.15);
    this._tone(base * 1.5, 0.25, 0.3, 'sine', 0.01, 0.08, t + 0.22);
    // Big crowd swell
    this._noise(0.5, 0.25, 400, 3000, 0.02, t + 0.2);
  }

  _playDunkMiss() {
    const ctx = this._getCtx();
    if (!ctx) return;
    this._noise(0.12, 0.3, 100, 600, 0.01, ctx.currentTime);
    this._tone(320, 0.3, 0.25, 'sawtooth', 0.005, 0.1, ctx.currentTime + 0.05);
  }

  _playJump() {
    this._tone(440, 0.1, 0.25, 'triangle', 0.003, 0.04);
    this._tone(600, 0.08, 0.2, 'sine',     0.003, 0.04, this._getCtx()?.currentTime + 0.04);
  }

  _playStrikeLight() {
    this._noise(0.06, 0.4, 500, 5000, 0.003);
    this._tone(660, 0.08, 0.3, 'square', 0.002, 0.04);
  }

  _playStrikeHeavy() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.12, 0.55, 100, 800, 0.004, t);
    this._noise(0.08, 0.3, 2000, 8000, 0.003, t + 0.01);
    this._tone(330, 0.18, 0.35, 'sawtooth', 0.003, 0.06, t);
  }

  _playStrikeSpecial() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.2, 0.5, 80, 600, 0.005, t);
    [220, 330, 440, 660].forEach((f, i) => this._tone(f, 0.25, 0.3, 'sawtooth', 0.003, 0.08, t + i * 0.04));
  }

  _playBlock() {
    this._tone(330, 0.1, 0.35, 'square', 0.003, 0.04);
    this._noise(0.08, 0.2, 300, 2000, 0.005);
  }

  _playDodge() {
    this._noise(0.06, 0.2, 3000, 12000, 0.003);
  }

  _playHitReceive() {
    this._noise(0.1, 0.4, 100, 1000, 0.005);
    this._tone(280, 0.15, 0.25, 'triangle', 0.005, 0.06);
  }

  _playKO() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.4, 0.6, 40, 400, 0.01, t);
    [440, 330, 220, 165].forEach((f, i) => this._tone(f, 0.35, 0.4, 'sine', 0.005, 0.1, t + i * 0.12));
  }

  _playWhistle() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._tone(2400, 0.12, 0.45, 'sine', 0.003, 0.05, t);
    this._tone(2200, 0.1,  0.35, 'sine', 0.003, 0.05, t + 0.14);
  }

  _playGoal() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    // Swoosh
    this._noise(0.15, 0.3, 3000, 12000, 0.005, t);
    // Net impact
    this._noise(0.2, 0.4, 100, 800, 0.01, t + 0.05);
    // Fanfare
    [523, 659, 784, 1047].forEach((f, i) => this._tone(f, 0.35, 0.4, 'sine', 0.004, 0.08, t + 0.1 + i * 0.07));
    // Crowd
    this._noise(0.8, 0.35, 300, 3000, 0.03, t + 0.15);
  }

  _playCrowdSwell() {
    const ctx = this._getCtx(); if (!ctx) return;
    this._noise(1.2, 0.3, 300, 3000, 0.1, ctx.currentTime);
  }

  _startCrowdLoop({ intensity = 0.15 } = {}) {
    this._stopCrowdLoop();
    const ctx = this._getCtx(); if (!ctx) return;
    const bufSize = ctx.sampleRate * 2;
    const buffer = ctx.createBuffer(1, bufSize, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;

    const src = ctx.createBufferSource();
    src.buffer = buffer;
    src.loop = true;

    const lo = ctx.createBiquadFilter();
    lo.type = 'highpass';
    lo.frequency.value = 200;

    const hi = ctx.createBiquadFilter();
    hi.type = 'lowpass';
    hi.frequency.value = 2000;

    this._crowdGain = ctx.createGain();
    this._crowdGain.gain.value = intensity;

    src.connect(lo);
    lo.connect(hi);
    hi.connect(this._crowdGain);
    this._crowdGain.connect(this._masterGain);
    src.start();
    this._crowdLoop = src;
  }

  _stopCrowdLoop() {
    try { this._crowdLoop?.stop(); } catch { /* already stopped */ }
    this._crowdLoop = null;
    this._crowdGain = null;
  }

  _playBounce() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.05, 0.35, 100, 600, 0.003, t);
    this._tone(200, 0.08, 0.2, 'sine', 0.003, 0.04, t);
  }

  _playSwoosh() {
    this._noise(0.12, 0.2, 4000, 14000, 0.005);
  }

  _playSwingBat() {
    this._noise(0.15, 0.3, 200, 4000, 0.005);
  }

  _playHitBall() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.08, 0.5, 300, 3000, 0.003, t);
    this._tone(440, 0.12, 0.3, 'sine', 0.003, 0.05, t + 0.01);
  }

  _playServe() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.1, 0.25, 200, 3000, 0.005, t);
    this._tone(660, 0.1, 0.2, 'triangle', 0.003, 0.05, t + 0.02);
  }

  _playAce() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.12, 0.4, 300, 5000, 0.005, t);
    [880, 1108, 1320].forEach((f, i) => this._tone(f, 0.2, 0.3, 'sine', 0.003, 0.06, t + i * 0.06));
  }

  _playGolfSwing() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.25, 0.2, 2000, 10000, 0.01, t);    // whoosh
    this._noise(0.06, 0.4, 200, 2000, 0.003, t + 0.2); // impact
  }

  _playGolfPutt() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._tone(660, 0.08, 0.3, 'sine', 0.002, 0.04, t);
    this._noise(0.06, 0.15, 500, 3000, 0.003, t);
  }

  _playCountdownTick() {
    this._tone(880, 0.08, 0.3, 'sine', 0.002, 0.03);
  }

  _playCountdownGo() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    [523, 784, 1047].forEach((f, i) => this._tone(f, 0.2, 0.45, 'sine', 0.003, 0.05, t + i * 0.07));
  }

  _playMatchStart() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._playWhistle();
    this._noise(0.6, 0.25, 300, 3000, 0.05, t + 0.1);
  }

  _playMatchEnd() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._playWhistle();
    this._tone(880, 0.5, 0.4, 'sine', 0.01, 0.2, t + 0.2);
    this._tone(1108, 0.4, 0.3, 'sine', 0.01, 0.15, t + 0.4);
  }

  _playPRQUp() {
    this._tone(1200, 0.1, 0.25, 'sine', 0.003, 0.04);
  }

  _playPRQDown() {
    this._tone(400, 0.15, 0.25, 'triangle', 0.005, 0.06);
  }

  _playPerfect() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    [880, 1108, 1320, 1760].forEach((f, i) => {
      this._tone(f, 0.2, 0.35, 'sine', 0.002, 0.06, t + i * 0.04);
    });
    this._noise(0.15, 0.1, 5000, 16000, 0.01, t);
  }

  _playTrickLand() {
    const ctx = this._getCtx(); if (!ctx) return;
    const t = ctx.currentTime;
    this._noise(0.12, 0.5, 60, 500, 0.003, t);
    this._tone(440, 0.15, 0.3, 'triangle', 0.004, 0.05, t + 0.02);
  }
}

export default AudioSystem;

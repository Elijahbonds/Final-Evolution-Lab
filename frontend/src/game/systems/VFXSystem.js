/**
 * VFXSystem — screen-level visual effects for FEL web game modes.
 *
 * Provides:
 *   - Camera shake (CSS transform on the game container)
 *   - Screen flash (fullscreen colour overlay)
 *   - Particle burst (Canvas 2D overlay — confetti, sparks, stars)
 *   - Slow-motion time scale (returned to caller — renderer must use)
 *   - Low-HP vignette (red border pulse)
 *   - Score pop label (floating text over canvas)
 *
 * iOS parity: mirrors GamePlayView.swift screenShake, showFlash,
 * showCriticalFlash, showImpactFlash, showComboChain, GoldenEraComboEngine.
 *
 * Usage:
 *   const vfx = new VFXSystem(containerEl);
 *   vfx.trigger('score',           { points: 2 });
 *   vfx.trigger('combo_hit',       { chain: 5, multiplier: 2 });
 *   vfx.trigger('heavy_impact');
 *   vfx.trigger('low_hp',          { active: true });
 *   vfx.trigger('screen_flash',    { color: '#ff0000', duration: 120 });
 *   vfx.trigger('camera_shake',    { intensity: 0.6, duration: 300 });
 *   vfx.trigger('particle_burst',  { x: 200, y: 100, type: 'confetti', count: 40 });
 */

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_SHAKE_DURATION_MS = 250;
const DEFAULT_FLASH_DURATION_MS = 180;
const PARTICLE_COLORS = {
  confetti: ['#facc15', '#f97316', '#22c55e', '#3b82f6', '#a855f7', '#ef4444'],
  sparks:   ['#fbbf24', '#f97316', '#fde68a', '#ffffff'],
  stars:    ['#facc15', '#fde68a', '#fbbf24', '#fff7ed'],
  blood:    ['#ef4444', '#b91c1c', '#7f1d1d'],
  snow:     ['#ffffff', '#e0f2fe', '#bae6fd'],
};

// ---------------------------------------------------------------------------
// VFXSystem class
// ---------------------------------------------------------------------------

export class VFXSystem {
  /**
   * @param {HTMLElement} container — the game's root container element.
   *   Should have position: relative; overflow: hidden.
   */
  constructor(container) {
    this._container = container;
    this._shakeTimer = null;
    this._flashEl = null;
    this._vignetteEl = null;
    this._particleCanvas = null;
    this._particleCtx = null;
    this._particles = [];
    this._animFrame = null;
    this._scorePops = [];
    this._timeScale = 1;
    this._onTimeScaleChange = null;

    if (container) {
      this._initOverlays();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  _initOverlays() {
    const c = this._container;
    if (!c) return;

    // Flash overlay
    this._flashEl = document.createElement('div');
    Object.assign(this._flashEl.style, {
      position: 'absolute', inset: '0', pointerEvents: 'none',
      opacity: '0', zIndex: '50', transition: 'opacity 60ms ease-out',
      backgroundColor: '#ffffff',
    });
    c.appendChild(this._flashEl);

    // Vignette (low-HP red pulse)
    this._vignetteEl = document.createElement('div');
    Object.assign(this._vignetteEl.style, {
      position: 'absolute', inset: '0', pointerEvents: 'none',
      opacity: '0', zIndex: '48',
      boxShadow: 'inset 0 0 80px 30px rgba(239,68,68,0.6)',
      borderRadius: 'inherit',
    });
    c.appendChild(this._vignetteEl);

    // Particle canvas overlay
    this._particleCanvas = document.createElement('canvas');
    Object.assign(this._particleCanvas.style, {
      position: 'absolute', inset: '0', pointerEvents: 'none',
      zIndex: '45', opacity: '1',
    });
    this._syncCanvasSize();
    this._particleCtx = this._particleCanvas.getContext('2d');
    c.appendChild(this._particleCanvas);

    // Keep canvas size synced
    this._resizeObs = new ResizeObserver(() => this._syncCanvasSize());
    this._resizeObs.observe(c);
  }

  _syncCanvasSize() {
    if (!this._particleCanvas || !this._container) return;
    this._particleCanvas.width  = this._container.clientWidth;
    this._particleCanvas.height = this._container.clientHeight;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Trigger a named visual effect.
   *
   * @param {string} effectName
   * @param {object} [opts]
   */
  trigger(effectName, opts = {}) {
    switch (effectName) {
      case 'score':
        this._cameraShake({ intensity: 0.3, duration: 200 });
        this._screenFlash({ color: '#facc15', opacity: 0.15, duration: 150 });
        this._spawnScorePop(opts.points ?? 2, opts.x, opts.y, '#facc15');
        this._particleBurst({ x: opts.x, y: opts.y, type: 'confetti', count: 20 });
        break;

      case 'score_big':
        this._cameraShake({ intensity: 0.7, duration: 350 });
        this._screenFlash({ color: '#facc15', opacity: 0.35, duration: 200 });
        this._spawnScorePop(opts.points ?? 5, opts.x, opts.y, '#facc15');
        this._particleBurst({ x: opts.x, y: opts.y, type: 'confetti', count: 50 });
        break;

      case 'dunk':
        this._cameraShake({ intensity: 0.8, duration: 350 });
        this._screenFlash({ color: '#f97316', opacity: 0.28, duration: 200 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'sparks', count: 35 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'confetti', count: 25 });
        break;

      case 'dunk_miss':
        this._cameraShake({ intensity: 0.25, duration: 160 });
        this._screenFlash({ color: '#6b7280', opacity: 0.12, duration: 120 });
        break;

      case 'combo_hit': {
        const chain = opts.chain ?? 1;
        const intensity = Math.min(0.1 + chain * 0.06, 0.65);
        this._cameraShake({ intensity: intensity * 0.5, duration: 120 });
        if (chain >= 3) {
          this._screenFlash({ color: '#f97316', opacity: intensity * 0.25, duration: 100 });
        }
        if (chain >= 5) {
          this._particleBurst({ x: opts.x, y: opts.y, type: 'sparks', count: chain * 3 });
        }
        break;
      }

      case 'combo_break':
        this._cameraShake({ intensity: 0.3, duration: 180 });
        this._screenFlash({ color: '#6b7280', opacity: 0.15, duration: 150 });
        break;

      case 'heavy_impact':
        this._cameraShake({ intensity: 0.9, duration: 280 });
        this._screenFlash({ color: '#ffffff', opacity: 0.3, duration: 80 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'sparks', count: 20 });
        break;

      case 'light_impact':
        this._cameraShake({ intensity: 0.2, duration: 100 });
        this._screenFlash({ color: '#ffffff', opacity: 0.1, duration: 60 });
        break;

      case 'hit_receive':
        this._cameraShake({ intensity: 0.55, duration: 220 });
        this._screenFlash({ color: '#ef4444', opacity: 0.28, duration: 180 });
        break;

      case 'ko':
        this._cameraShake({ intensity: 1.0, duration: 500 });
        this._screenFlash({ color: '#ef4444', opacity: 0.55, duration: 300 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'sparks', count: 60 });
        break;

      case 'perfect':
        this._cameraShake({ intensity: 0.4, duration: 200 });
        this._screenFlash({ color: '#22c55e', opacity: 0.2, duration: 160 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'stars', count: 30 });
        this._spawnScorePop('PERFECT!', opts.x, opts.y, '#22c55e');
        break;

      case 'goal':
        this._cameraShake({ intensity: 0.7, duration: 400 });
        this._screenFlash({ color: '#22c55e', opacity: 0.3, duration: 200 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'confetti', count: 60 });
        break;

      case 'low_hp':
        this._setVignette(opts.active !== false);
        break;

      case 'slow_mo':
        this._setTimeScale(opts.active !== false ? 0.35 : 1.0);
        break;

      case 'screen_flash':
        this._screenFlash(opts);
        break;

      case 'camera_shake':
        this._cameraShake(opts);
        break;

      case 'particle_burst':
        this._particleBurst(opts);
        break;

      case 'trick_land':
        this._cameraShake({ intensity: 0.6, duration: 200 });
        this._screenFlash({ color: '#a855f7', opacity: 0.2, duration: 150 });
        this._particleBurst({ x: opts.x, y: opts.y, type: 'stars', count: 25 });
        break;

      default:
        break;
    }
  }

  /** Register a callback for time-scale changes (for Babylon render loop). */
  setTimeScaleCallback(fn) {
    this._onTimeScaleChange = fn;
  }

  get timeScale() { return this._timeScale; }

  dispose() {
    this._resizeObs?.disconnect();
    this._flashEl?.remove();
    this._vignetteEl?.remove();
    this._particleCanvas?.remove();
    if (this._animFrame) cancelAnimationFrame(this._animFrame);
    if (this._shakeTimer) clearTimeout(this._shakeTimer);
    this._particles = [];
    this._scorePops = [];
    this._flashEl = null;
    this._vignetteEl = null;
    this._particleCanvas = null;
    this._particleCtx = null;
  }

  // ── Private effect implementations ─────────────────────────────────────────

  _cameraShake({ intensity = 0.5, duration = DEFAULT_SHAKE_DURATION_MS } = {}) {
    const c = this._container;
    if (!c) return;

    if (this._shakeTimer) clearTimeout(this._shakeTimer);
    const amp = intensity * 8; // max px displacement
    let elapsed = 0;
    const step = 16;
    const interval = setInterval(() => {
      elapsed += step;
      const remaining = 1 - elapsed / duration;
      if (remaining <= 0) {
        clearInterval(interval);
        c.style.transform = '';
        return;
      }
      const curAmp = amp * remaining;
      const x = (Math.random() * 2 - 1) * curAmp;
      const y = (Math.random() * 2 - 1) * curAmp;
      c.style.transform = `translate(${x.toFixed(2)}px, ${y.toFixed(2)}px)`;
    }, step);
    this._shakeTimer = setTimeout(() => clearInterval(interval), duration + step);
  }

  _screenFlash({ color = '#ffffff', opacity = 0.25, duration = DEFAULT_FLASH_DURATION_MS } = {}) {
    const el = this._flashEl;
    if (!el) return;
    el.style.backgroundColor = color;
    el.style.transition = 'none';
    el.style.opacity = String(opacity);
    setTimeout(() => {
      el.style.transition = `opacity ${duration}ms ease-out`;
      el.style.opacity = '0';
    }, 20);
  }

  _setVignette(active) {
    if (!this._vignetteEl) return;
    if (active) {
      this._vignetteEl.style.animation = 'none';
      this._vignetteEl.style.opacity = '1';
      // Pulse using CSS animation via inline keyframes isn't feasible —
      // use alternating setInterval instead
      if (!this._vignetteInterval) {
        let up = true;
        this._vignetteInterval = setInterval(() => {
          if (!this._vignetteEl) { clearInterval(this._vignetteInterval); return; }
          this._vignetteEl.style.transition = 'opacity 400ms ease-in-out';
          this._vignetteEl.style.opacity = up ? '0.7' : '0.3';
          up = !up;
        }, 600);
      }
    } else {
      clearInterval(this._vignetteInterval);
      this._vignetteInterval = null;
      if (this._vignetteEl) {
        this._vignetteEl.style.transition = 'opacity 400ms ease-out';
        this._vignetteEl.style.opacity = '0';
      }
    }
  }

  _setTimeScale(scale) {
    this._timeScale = scale;
    this._onTimeScaleChange?.(scale);
  }

  _particleBurst({ x, y, type = 'confetti', count = 20 } = {}) {
    if (!this._particleCanvas) return;
    const cw = this._particleCanvas.width;
    const ch = this._particleCanvas.height;
    const cx = x ?? cw / 2;
    const cy = y ?? ch * 0.35;
    const colors = PARTICLE_COLORS[type] ?? PARTICLE_COLORS.confetti;

    for (let i = 0; i < count; i++) {
      const angle  = (Math.random() * Math.PI * 2);
      const speed  = 2 + Math.random() * 5;
      const size   = type === 'sparks' ? 2 + Math.random() * 3 : 4 + Math.random() * 8;
      const life   = 0.7 + Math.random() * 0.5;
      const color  = colors[Math.floor(Math.random() * colors.length)];
      const rotVel = (Math.random() - 0.5) * 0.3;
      this._particles.push({
        x: cx, y: cy,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - (type === 'confetti' ? 2 : 0),
        size,
        color,
        life,
        maxLife: life,
        rot: Math.random() * Math.PI * 2,
        rotVel,
        type,
      });
    }
    this._ensureParticleLoop();
  }

  _ensureParticleLoop() {
    if (this._animFrame) return;
    const tick = () => {
      this._updateParticles();
      if (this._particles.length > 0 || this._scorePops.length > 0) {
        this._animFrame = requestAnimationFrame(tick);
      } else {
        this._animFrame = null;
      }
    };
    this._animFrame = requestAnimationFrame(tick);
  }

  _updateParticles() {
    const ctx = this._particleCtx;
    const canvas = this._particleCanvas;
    if (!ctx || !canvas) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw particles
    this._particles = this._particles.filter(p => {
      p.x  += p.vx;
      p.y  += p.vy;
      p.vy += 0.18; // gravity
      p.vx *= 0.98; // drag
      p.life -= 0.025;
      p.rot  += p.rotVel;
      if (p.life <= 0) return false;

      const alpha = p.life / p.maxLife;
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = p.color;
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot);

      if (p.type === 'sparks' || p.type === 'stars') {
        ctx.beginPath();
        ctx.arc(0, 0, p.size / 2, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
      }
      ctx.restore();
      return true;
    });

    // Draw score pops
    this._scorePops = this._scorePops.filter(pop => {
      pop.y -= 1.2;
      pop.life -= 0.022;
      if (pop.life <= 0) return false;
      ctx.save();
      ctx.globalAlpha = Math.min(1, pop.life * 3);
      ctx.fillStyle = pop.color;
      ctx.font = `bold ${pop.size}px system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.fillText(pop.text, pop.x, pop.y);
      ctx.restore();
      return true;
    });
  }

  _spawnScorePop(text, x, y, color = '#facc15') {
    if (!this._particleCanvas) return;
    const cw = this._particleCanvas.width;
    const ch = this._particleCanvas.height;
    this._scorePops.push({
      text: String(text),
      x: x ?? cw / 2,
      y: y ?? ch * 0.4,
      color,
      life: 1,
      size: 28,
    });
    this._ensureParticleLoop();
  }
}

export default VFXSystem;

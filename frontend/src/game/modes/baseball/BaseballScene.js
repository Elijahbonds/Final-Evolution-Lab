import { BASEBALL_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';
let babylonModulePromise;

async function loadBabylonCore() {
  if (!babylonModulePromise) {
    babylonModulePromise = import('@babylonjs/core').catch(() => null);
  }
  return babylonModulePromise;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function easeInOut(t) {
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export class BaseballScene {
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this.glowLayer = null;
    this.shadowGenerator = null;
    this.isFallback = false;
    this._babylon = null;
    this._handleResize = null;
    this._beforeRender = null;
    this._cameraTween = null;
    this._ballTween = null;
    this._swingTween = null;
    this._trailHistory = [];
    this._trailActiveUntil = 0;
    this._fireworks = null;
    this._dirtPuff = null;
    this._timers = new Set();
  }

  // Graduation shell (shared process): StrictMode guard, frame hook, shake
  _disposedScene = false;
  _frameCallback = null;
  _shakeRemainingMs = 0;
  _shakeDurationMs = 220; // TUNE(elijah)
  _shakeIntensity = 0;
  _shakeBaseY = null;

  setFrameCallback(cb) { this._frameCallback = cb; }

  applyCameraShake(intensity) {
    if (!this.camera) return;
    if (this._shakeBaseY === null) this._shakeBaseY = this.camera.target.y;
    this._shakeIntensity = Math.max(this._shakeIntensity, intensity);
    this._shakeRemainingMs = this._shakeDurationMs;
  }

  _applyShakeFrame(dtMs) {
    if (this._shakeRemainingMs <= 0 || !this.camera || this._shakeBaseY === null) return;
    this._shakeRemainingMs -= dtMs;
    if (this._shakeRemainingMs <= 0) {
      this.camera.target.y = this._shakeBaseY;
      this._shakeBaseY = null;
      this._shakeIntensity = 0;
      return;
    }
    const life = this._shakeRemainingMs / this._shakeDurationMs;
    const t = (this._shakeDurationMs - this._shakeRemainingMs) / 1000;
    this.camera.target.y = this._shakeBaseY + Math.sin(t * 55) * this._shakeIntensity * life;
  }

  async init(canvas = this.canvas) {
    if (canvas) this.canvas = canvas;
    const babylon = await loadBabylonCore();

    // Disposed while loading (StrictMode remount): never create an Engine.
    if (this._disposedScene) {
      this.isFallback = true;
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'baseball-fallback';
        this.canvas.style.background = 'linear-gradient(180deg, #7ec8ff 0%, #4f9cf7 35%, #2c7a2c 100%)';
      }
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
      ArcRotateCamera,
      Color3,
      Color4,
      DirectionalLight,
      Engine,
      GlowLayer,
      HemisphericLight,
      Mesh,
      MeshBuilder,
      ParticleSystem,
      Scene,
      ShadowGenerator,
      SpotLight,
      StandardMaterial,
      Vector3,
    } = babylon;

    this._babylon = babylon;
    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.45, 0.76, 0.98, 1);
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = Color3.FromHexString('#87ceeb');
    this.scene.fogDensity = 0.003;

    this.camera = new ArcRotateCamera('baseballCamera', -Math.PI / 2.18, Math.PI / 3.1, 30, new Vector3(0, 2.8, 6), this.scene);
    this.camera.lowerRadiusLimit = 16;
    this.camera.upperRadiusLimit = 48;
    this.camera.lowerBetaLimit = 0.18;
    this.camera.upperBetaLimit = Math.PI / 2.05;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('baseballAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.72;
    ambient.groundColor = Color3.FromHexString('#5d3412');

    const sun = new DirectionalLight('baseballSun', new Vector3(-0.35, -1, 0.18), this.scene);
    sun.position = new Vector3(24, 28, -16);
    sun.intensity = 1.28;
    this.shadowGenerator = new ShadowGenerator(1024, sun);
    this.shadowGenerator.useBlurExponentialShadowMap = true;
    this.shadowGenerator.blurKernel = 20;

    const makeMat = (name, diffuse, emissive = null, alpha = 1) => {
      const mat = new StandardMaterial(name, this.scene);
      mat.diffuseColor = Color3.FromHexString(diffuse);
      mat.specularColor = Color3.FromHexString('#1f2937');
      mat.alpha = alpha;
      if (emissive) mat.emissiveColor = Color3.FromHexString(emissive);
      return mat;
    };

    const grass = MeshBuilder.CreateGround('outfieldGrass', { width: 80, height: 84 }, this.scene);
    grass.material = makeMat('grassMat', '#3ebd45', '#103c14');
    grass.receiveShadows = true;

    const infield = MeshBuilder.CreateCylinder('infieldDirt', { diameterTop: 26, diameterBottom: 30, height: 0.08, tessellation: 4 }, this.scene);
    infield.position = new Vector3(0, 0.04, 7);
    infield.rotation.y = Math.PI / 4;
    infield.material = makeMat('dirtMat', '#8b5a2b');
    infield.receiveShadows = true;

    const mound = MeshBuilder.CreateCylinder('pitchersMound', { diameter: 4.4, height: 0.4, tessellation: 32 }, this.scene);
    mound.position = new Vector3(0, 0.2, 2);
    mound.material = makeMat('moundMat', '#9a6935');
    mound.receiveShadows = true;

    const wallMat = makeMat('wallMat', '#1f8b3f', '#0b2d14');
    const wallBack = MeshBuilder.CreateBox('wallBack', { width: 56, height: 4.4, depth: 0.8 }, this.scene);
    wallBack.position = new Vector3(0, 2.2, -28);
    wallBack.material = wallMat;
    const wallLeft = MeshBuilder.CreateBox('wallLeft', { width: 0.8, height: 4.4, depth: 26 }, this.scene);
    wallLeft.position = new Vector3(-28, 2.2, -15);
    wallLeft.rotation.y = Math.PI / 4;
    wallLeft.material = wallMat;
    const wallRight = MeshBuilder.CreateBox('wallRight', { width: 0.8, height: 4.4, depth: 26 }, this.scene);
    wallRight.position = new Vector3(28, 2.2, -15);
    wallRight.rotation.y = -Math.PI / 4;
    wallRight.material = wallMat;

    const foulPoleMat = makeMat('foulPoleMat', '#facc15', '#7c5a00');
    const leftPole = MeshBuilder.CreateCapsule('leftFoulPole', { height: 12, radius: 0.18 }, this.scene);
    leftPole.position = new Vector3(-24, 6, -24);
    leftPole.material = foulPoleMat;
    const rightPole = MeshBuilder.CreateCapsule('rightFoulPole', { height: 12, radius: 0.18 }, this.scene);
    rightPole.position = new Vector3(24, 6, -24);
    rightPole.material = foulPoleMat;

    const baseMat = makeMat('baseMat', '#ffffff');
    const baseSpecs = {
      home: [0, 0.08, 13.5],
      first: [4.2, 0.08, 8.4],
      second: [0, 0.08, 3.8],
      third: [-4.2, 0.08, 8.4],
    };
    const bases = Object.fromEntries(Object.entries(baseSpecs).map(([name, pos]) => {
      const base = MeshBuilder.CreateBox(`${name}Base`, { width: 1, height: 0.16, depth: 1 }, this.scene);
      base.position = new Vector3(...pos);
      base.rotation.y = Math.PI / 4;
      base.material = baseMat;
      return [name, base];
    }));

    const crowdMat = makeMat('crowdMat', '#2f3e5b', '#101828');
    crowdMat.backFaceCulling = false;
    const crowdSpecs = [
      { name: 'crowdNorth', width: 58, height: 8, x: 0, z: -35, rot: 0 },
      { name: 'crowdSouth', width: 58, height: 6, x: 0, z: 34, rot: Math.PI },
      { name: 'crowdEast', width: 68, height: 7, x: 34, z: 0, rot: Math.PI / 2 },
      { name: 'crowdWest', width: 68, height: 7, x: -34, z: 0, rot: -Math.PI / 2 },
    ];
    const crowdStrips = crowdSpecs.map((spec) => {
      const strip = MeshBuilder.CreatePlane(spec.name, { width: spec.width, height: spec.height }, this.scene);
      strip.position = new Vector3(spec.x, 4.8, spec.z);
      strip.rotation.y = spec.rot;
      strip.billboardMode = Mesh.BILLBOARDMODE_Y;
      strip.material = crowdMat;
      return strip;
    });

    const sky = MeshBuilder.CreateSphere('skyDome', { diameter: 180, segments: 16, slice: 0.5 }, this.scene);
    sky.position.y = -3;
    sky.scaling.y = 0.7;
    const skyMat = makeMat('skyMat', '#7ec8ff', '#66b8ff');
    skyMat.backFaceCulling = false;
    skyMat.disableLighting = true;
    sky.material = skyMat;

    const stadiumLightMat = makeMat('stadiumLightMat', '#cbd5e1', '#dbeafe');
    const lightPosts = [
      new Vector3(-20, 13, -18),
      new Vector3(20, 13, -18),
      new Vector3(-20, 13, 18),
      new Vector3(20, 13, 18),
    ].map((pos, index) => {
      const pole = MeshBuilder.CreateCylinder(`lightPole${index}`, { diameter: 0.45, height: 12 }, this.scene);
      pole.position = pos.clone();
      pole.position.y = 6;
      pole.material = stadiumLightMat;
      const bank = MeshBuilder.CreateBox(`lightBank${index}`, { width: 2.8, height: 0.7, depth: 0.7 }, this.scene);
      bank.position = new Vector3(pos.x, 12.5, pos.z);
      bank.material = stadiumLightMat;
      return { pole, bank };
    });

    const stadiumSpots = [
      { name: 'lightNW', pos: new Vector3(-18, 13, 18), dir: new Vector3(0.35, -1, -0.3) },
      { name: 'lightNE', pos: new Vector3(18, 13, 18), dir: new Vector3(-0.35, -1, -0.3) },
      { name: 'lightSW', pos: new Vector3(-16, 14, -10), dir: new Vector3(0.25, -1, 0.1) },
      { name: 'lightSE', pos: new Vector3(16, 14, -10), dir: new Vector3(-0.25, -1, 0.1) },
    ].map((spec) => {
      const light = new SpotLight(spec.name, spec.pos, spec.dir, Math.PI / 3.2, 2, this.scene);
      light.intensity = 85;
      light.diffuse = Color3.FromHexString('#fff7cc');
      return light;
    });

    const batter = MeshBuilder.CreateCapsule('batter', { height: 1.9, radius: 0.34 }, this.scene);
    batter.position = new Vector3(-0.6, 0.95, 12.6);
    batter.rotation.y = Math.PI / 2.25;
    batter.material = makeMat('batterMat', '#2563eb', '#102d73');

    const pitcher = MeshBuilder.CreateCapsule('pitcher', { height: 1.9, radius: 0.34 }, this.scene);
    pitcher.position = new Vector3(0, 1.15, 2.1);
    pitcher.rotation.y = Math.PI;
    pitcher.material = makeMat('pitcherMat', '#dc2626', '#5f1010');

    const fielders = [
      { name: 'fielderLeft', x: -7.5, z: -5.5 },
      { name: 'fielderCenter', x: 0, z: -10.5 },
      { name: 'fielderRight', x: 7.5, z: -5.5 },
    ].map((spec, index) => {
      const fielder = MeshBuilder.CreateCapsule(spec.name, { height: 1.85, radius: 0.3 }, this.scene);
      fielder.position = new Vector3(spec.x, 0.93, spec.z);
      fielder.material = makeMat(`fielderMat${index}`, '#f97316', '#6b2508');
      return fielder;
    });

    const ball = MeshBuilder.CreateSphere('baseball', { diameter: 0.36, segments: 18 }, this.scene);
    ball.position = new Vector3(0, 1.35, 1.7);
    ball.material = makeMat('ballMat', '#ffffff', '#9ca3af');

    const ballTrail = [0.85, 0.65, 0.45].map((scale, index) => {
      const ghost = MeshBuilder.CreateSphere(`baseballTrail${index}`, { diameter: 0.36 * scale, segments: 12 }, this.scene);
      ghost.material = makeMat(`ballTrailMat${index}`, '#ffffff', '#cbd5e1', 0.22 - index * 0.05);
      ghost.isVisible = false;
      ghost.position = ball.position.clone();
      return ghost;
    });

    [grass, infield, mound, wallBack, wallLeft, wallRight, leftPole, rightPole, batter, pitcher, ball, ...fielders, ...Object.values(bases), ...lightPosts.flatMap((entry) => [entry.pole, entry.bank])].forEach((mesh) => {
      this.shadowGenerator.addShadowCaster(mesh);
    });
    [grass, infield, mound].forEach((mesh) => { mesh.receiveShadows = true; });

    this.glowLayer = new GlowLayer('baseballGlow', this.scene);
    this.glowLayer.intensity = 0.36;

    this._fireworks = new ParticleSystem('homeRunFireworks', 260, this.scene);
    this._fireworks.emitter = new Vector3(0, 9, -24);
    this._fireworks.color1 = new Color4(1, 0.95, 0.3, 1);
    this._fireworks.color2 = new Color4(0.35, 0.8, 1, 1);
    this._fireworks.colorDead = new Color4(0.2, 0.2, 0.2, 0);
    this._fireworks.minSize = 0.08;
    this._fireworks.maxSize = 0.22;
    this._fireworks.minLifeTime = 0.4;
    this._fireworks.maxLifeTime = 1.2;
    this._fireworks.emitRate = 0;
    this._fireworks.minEmitPower = 2.4;
    this._fireworks.maxEmitPower = 5.8;
    this._fireworks.gravity = new Vector3(0, -3.8, 0);
    this._fireworks.direction1 = new Vector3(-2.4, 1.8, -2.4);
    this._fireworks.direction2 = new Vector3(2.4, 3.8, 2.4);
    this._fireworks.start();

    this._dirtPuff = new ParticleSystem('dirtPuff', 150, this.scene);
    this._dirtPuff.emitter = new Vector3(0, 0.05, 12.4);
    this._dirtPuff.color1 = new Color4(0.71, 0.47, 0.2, 0.95);
    this._dirtPuff.color2 = new Color4(0.5, 0.28, 0.12, 0.8);
    this._dirtPuff.colorDead = new Color4(0.3, 0.16, 0.08, 0);
    this._dirtPuff.minSize = 0.05;
    this._dirtPuff.maxSize = 0.16;
    this._dirtPuff.minLifeTime = 0.2;
    this._dirtPuff.maxLifeTime = 0.5;
    this._dirtPuff.emitRate = 0;
    this._dirtPuff.minEmitPower = 0.6;
    this._dirtPuff.maxEmitPower = 2.8;
    this._dirtPuff.gravity = new Vector3(0, 2.2, 0);
    this._dirtPuff.direction1 = new Vector3(-1.2, 1.2, -0.8);
    this._dirtPuff.direction2 = new Vector3(1.2, 2, 0.8);
    this._dirtPuff.start();

    this.assets = {
      grass,
      infield,
      mound,
      bases,
      walls: [wallBack, wallLeft, wallRight],
      foulPoles: [leftPole, rightPole],
      crowdStrips,
      lightPosts,
      stadiumSpots,
      sky,
      batter,
      pitcher,
      fielders,
      ball,
      ballTrail,
      ambient,
      sun,
    };

    this._beforeRender = () => {
      this._tickCameraTween();
      this._tickBallTween();
      this._tickSwingTween();
      this._updateTrail();
    };
    this.scene.onBeforeRenderObservable.add(this._beforeRender);

    scheduleIntegrityValidation(this, BASEBALL_MANIFEST);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      this._applyShakeFrame(dtMs);
      this.scene?.render();
    });
    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    this.setCameraAngle('batter');
    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  setCameraAngle(angle = 'batter') {
    if (!this.camera) return;

    const presets = {
      batter: { alpha: -Math.PI / 2.85, beta: Math.PI / 3.2, radius: 18, target: { x: 0, y: 1.8, z: 9.2 }, duration: 320 },
      pitcher: { alpha: Math.PI / 2, beta: Math.PI / 3.6, radius: 16, target: { x: 0, y: 1.7, z: 8.8 }, duration: 360 },
      home_run: { alpha: -Math.PI / 2, beta: 0.48, radius: 34, target: { x: 0, y: 6.2, z: -8 }, duration: 540 },
    };

    const next = presets[angle] ?? presets.batter;
    this._cameraTween = {
      from: {
        alpha: this.camera.alpha,
        beta: this.camera.beta,
        radius: this.camera.radius,
        target: this.camera.target.clone(),
      },
      to: next,
      startAt: performance.now(),
      duration: next.duration,
    };
  }

  animatePitch(speed = 1, type = 'fastball') {
    const { Vector3 } = this._babylon || {};
    if (!this.assets.ball || !Vector3) return;

    const from = new Vector3(0, 1.35, 1.7);
    const to = new Vector3(0, 1.05, 12.1);
    const safeSpeed = clamp(speed, 0.65, 1.8);
    const curve = type === 'curveball' ? 2.2 : type === 'slider' ? -1.4 : 0.25;

    this.assets.ball.position.copyFrom(from);
    this._trailHistory = [from.clone(), from.clone(), from.clone(), from.clone()];
    this._trailActiveUntil = 0;
    this._ballTween = {
      from,
      to,
      curve,
      arc: type === 'changeup' ? 1.4 : 1.8,
      startAt: performance.now(),
      duration: Math.max(420, 900 / safeSpeed),
      emitDirtAtEnd: false,
      onComplete: null,
    };
  }

  animateSwing(contact = false) {
    if (!this.assets.batter) return;

    this._swingTween = {
      mesh: this.assets.batter,
      startAt: performance.now(),
      duration: 240,
      baseRotY: this.assets.batter.rotation.y,
      contact,
    };

    if (!contact) {
      this._emitDirtPuff(this.assets.batter.position.x, 12.2);
      return;
    }

    const { Vector3 } = this._babylon || {};
    if (!this.assets.ball || !Vector3) return;
    const from = this.assets.ball.position.clone();
    const to = new Vector3((Math.random() - 0.5) * 8, 1.2, -18 - Math.random() * 6);
    this._trailActiveUntil = performance.now() + 1200;
    this._ballTween = {
      from,
      to,
      curve: (Math.random() - 0.5) * 3.2,
      arc: 4.2,
      startAt: performance.now(),
      duration: 980,
      emitDirtAtEnd: true,
      onComplete: null,
    };
  }

  triggerHomeRun() {
    const { Vector3 } = this._babylon || {};
    if (!this.assets.ball || !Vector3) return;

    const from = this.assets.ball.position.clone();
    const to = new Vector3((Math.random() - 0.5) * 10, 6.4, -31);
    this._trailActiveUntil = performance.now() + 1800;
    this.setCameraAngle('home_run');
    this._ballTween = {
      from,
      to,
      curve: (Math.random() - 0.5) * 2.4,
      arc: 13,
      startAt: performance.now(),
      duration: 1600,
      emitDirtAtEnd: false,
      onComplete: () => {
        if (this._fireworks) {
          this._fireworks.emitter = new Vector3(to.x * 0.6, 9.5, to.z + 2);
          this._fireworks.manualEmitCount = 120;
        }
        if (this.glowLayer) this.glowLayer.intensity = 0.8;
        this._schedule(() => {
          if (this.glowLayer) this.glowLayer.intensity = 0.36;
          this.setCameraAngle('batter');
        }, 1100);
      },
    };
  }

  _schedule(fn, delay) {
    const timer = setTimeout(() => {
      this._timers.delete(timer);
      fn();
    }, delay);
    this._timers.add(timer);
    return timer;
  }

  _emitDirtPuff(x = 0, z = 12.3) {
    const { Vector3 } = this._babylon || {};
    if (!this._dirtPuff || !Vector3) return;
    this._dirtPuff.emitter = new Vector3(x, 0.05, z);
    this._dirtPuff.manualEmitCount = 36;
  }

  _tickCameraTween() {
    if (!this._cameraTween || !this.camera) return;
    const progress = Math.min(1, (performance.now() - this._cameraTween.startAt) / this._cameraTween.duration);
    const eased = easeInOut(progress);
    const { from, to } = this._cameraTween;

    this.camera.alpha = lerp(from.alpha, to.alpha, eased);
    this.camera.beta = lerp(from.beta, to.beta, eased);
    this.camera.radius = lerp(from.radius, to.radius, eased);
    this.camera.target.x = lerp(from.target.x, to.target.x, eased);
    this.camera.target.y = lerp(from.target.y, to.target.y, eased);
    this.camera.target.z = lerp(from.target.z, to.target.z, eased);

    if (progress >= 1) this._cameraTween = null;
  }

  _tickBallTween() {
    if (!this._ballTween || !this.assets.ball) return;
    const progress = Math.min(1, (performance.now() - this._ballTween.startAt) / this._ballTween.duration);
    const eased = easeInOut(progress);
    const { from, to, arc, curve } = this._ballTween;
    const parabola = 4 * eased * (1 - eased);

    this.assets.ball.position.x = lerp(from.x, to.x, eased) + Math.sin(eased * Math.PI) * curve;
    this.assets.ball.position.y = lerp(from.y, to.y, eased) + parabola * arc;
    this.assets.ball.position.z = lerp(from.z, to.z, eased);

    if (progress >= 1) {
      const completed = this._ballTween;
      this.assets.ball.position.copyFrom(to);
      this._ballTween = null;
      if (completed.emitDirtAtEnd) this._emitDirtPuff(to.x, to.z);
      completed.onComplete?.();
    }
  }

  _tickSwingTween() {
    if (!this._swingTween?.mesh) return;
    const progress = Math.min(1, (performance.now() - this._swingTween.startAt) / this._swingTween.duration);
    const impulse = Math.sin(progress * Math.PI);
    const mesh = this._swingTween.mesh;

    mesh.rotation.y = this._swingTween.baseRotY - impulse * 0.9;
    mesh.scaling.x = 1 + impulse * 0.05;
    mesh.scaling.z = 1 - impulse * 0.05;

    if (progress >= 1) {
      mesh.rotation.y = this._swingTween.baseRotY;
      mesh.scaling.set(1, 1, 1);
      this._swingTween = null;
    }
  }

  _updateTrail() {
    if (!this.assets.ball || !this.assets.ballTrail?.length) return;

    const active = performance.now() <= this._trailActiveUntil;
    this._trailHistory.unshift(this.assets.ball.position.clone());
    this._trailHistory = this._trailHistory.slice(0, 12);

    this.assets.ballTrail.forEach((ghost, index) => {
      ghost.isVisible = active;
      if (!active) return;
      const sample = this._trailHistory[Math.min(this._trailHistory.length - 1, (index + 1) * 3)] || this.assets.ball.position;
      ghost.position.copyFrom(sample);
    });
  }

  dispose() {
    this._disposedScene = true;
    this._timers.forEach((timer) => clearTimeout(timer));
    this._timers.clear();
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
    if (this.engine) this.engine.stopRenderLoop();
    if (this.scene && this._beforeRender) {
      this.scene.onBeforeRenderObservable.removeCallback(this._beforeRender);
    }
    this._fireworks?.stop();
    this._dirtPuff?.stop();
    this.glowLayer?.dispose();
    this.scene?.dispose();
    this.engine?.dispose();
    if (this.canvas) {
      delete this.canvas.dataset.sceneMode;
      this.canvas.style.background = '';
    }

    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this.glowLayer = null;
    this.shadowGenerator = null;
    this.isFallback = false;
    this._babylon = null;
    this._handleResize = null;
    this._beforeRender = null;
    this._cameraTween = null;
    this._ballTween = null;
    this._swingTween = null;
    this._trailHistory = [];
    this._trailActiveUntil = 0;
    this._fireworks = null;
    this._dirtPuff = null;
  }
}

export default BaseballScene;

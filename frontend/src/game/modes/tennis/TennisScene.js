import { TENNIS_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';
let babylonModulePromise = null;

async function loadBabylonCore() {
  if (babylonModulePromise) return babylonModulePromise;
  babylonModulePromise = (async () => {
    if (typeof window !== 'undefined' && window.BABYLON) return window.BABYLON;
    try {
      return await import('@babylonjs/core');
    } catch {
      return null;
    }
  })();
  return babylonModulePromise;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function easeInOut(t) {
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}

export class TennisScene {
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
    this._handleResize = null;
    this._cameraTween = null;
    this._ballTween = null;
    this._swingTweens = new Map();
    this._beforeRender = null;
    this._clayDust = null;
    this._aceSparks = null;
    this._trailHistory = [];
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

  async init() {
    const babylon = await loadBabylonCore();

    // Disposed while loading (StrictMode remount): never create an Engine.
    if (this._disposedScene) {
      this.isFallback = true;
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'tennis-fallback';
        this.canvas.style.background = 'radial-gradient(circle at 50% 18%, #8ed0ff 0%, #3f8fe0 35%, #0d315f 100%)';
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
      MeshBuilder,
      ParticleSystem,
      Scene,
      ShadowGenerator,
      StandardMaterial,
      Vector3,
    } = babylon;

    this._babylon = babylon;
    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.47, 0.79, 0.98, 1);

    this.camera = new ArcRotateCamera('tennisCamera', -Math.PI / 2.35, Math.PI / 3.15, 24, new Vector3(0, 1.8, 0), this.scene);
    this.camera.lowerRadiusLimit = 12;
    this.camera.upperRadiusLimit = 40;
    this.camera.lowerBetaLimit = 0.2;
    this.camera.upperBetaLimit = Math.PI / 2.1;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('tennisAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.72;
    ambient.groundColor = Color3.FromHexString('#6b3d24');

    const sun = new DirectionalLight('tennisSun', new Vector3(-0.45, -1, 0.25), this.scene);
    sun.position = new Vector3(18, 24, -10);
    sun.intensity = 1.25;

    this.shadowGenerator = new ShadowGenerator(1024, sun);
    this.shadowGenerator.useBlurExponentialShadowMap = true;
    this.shadowGenerator.blurKernel = 24;

    const clay = MeshBuilder.CreateGround('clayCourt', { width: 24, height: 40 }, this.scene);
    const clayMat = new StandardMaterial('clayMat', this.scene);
    clayMat.diffuseColor = Color3.FromHexString('#b55d34');
    clayMat.specularColor = Color3.FromHexString('#2a1208');
    clay.material = clayMat;
    clay.receiveShadows = true;

    const lineMat = new StandardMaterial('lineMat', this.scene);
    lineMat.diffuseColor = Color3.White();
    lineMat.emissiveColor = Color3.FromHexString('#f7f4eb');
    lineMat.specularColor = Color3.Black();

    const lineSpecs = [
      { name: 'baselineNorth', width: 10.97, depth: 0.12, x: 0, z: -11.885 },
      { name: 'baselineSouth', width: 10.97, depth: 0.12, x: 0, z: 11.885 },
      { name: 'sidelineWest', width: 0.12, depth: 23.77, x: -5.485, z: 0 },
      { name: 'sidelineEast', width: 0.12, depth: 23.77, x: 5.485, z: 0 },
      { name: 'singlesWest', width: 0.09, depth: 23.77, x: -4.115, z: 0 },
      { name: 'singlesEast', width: 0.09, depth: 23.77, x: 4.115, z: 0 },
      { name: 'serviceNorth', width: 8.23, depth: 0.09, x: 0, z: -5.485 },
      { name: 'serviceSouth', width: 8.23, depth: 0.09, x: 0, z: 5.485 },
      { name: 'centerService', width: 0.09, depth: 10.97, x: 0, z: 0 },
      { name: 'centerMarkNorth', width: 0.09, depth: 0.4, x: 0, z: -11.685 },
      { name: 'centerMarkSouth', width: 0.09, depth: 0.4, x: 0, z: 11.685 },
    ];

    const courtLines = lineSpecs.map((spec) => {
      const mesh = MeshBuilder.CreateBox(spec.name, { width: spec.width, height: 0.03, depth: spec.depth }, this.scene);
      mesh.position = new Vector3(spec.x, 0.02, spec.z);
      mesh.material = lineMat;
      return mesh;
    });

    const netRibbon = MeshBuilder.CreateBox('netRibbon', { width: 11.3, height: 0.18, depth: 0.04 }, this.scene);
    netRibbon.position = new Vector3(0, 1.08, 0);
    netRibbon.material = lineMat;

    const netMesh = MeshBuilder.CreatePlane('netMesh', { width: 11.1, height: 0.95 }, this.scene);
    netMesh.position = new Vector3(0, 0.56, 0);
    const netMat = new StandardMaterial('netMat', this.scene);
    netMat.diffuseColor = Color3.FromHexString('#f4f1ea');
    netMat.alpha = 0.48;
    netMat.backFaceCulling = false;
    netMesh.material = netMat;

    const poleMat = new StandardMaterial('poleMat', this.scene);
    poleMat.diffuseColor = Color3.FromHexString('#1f2937');
    poleMat.specularColor = Color3.FromHexString('#94a3b8');
    const leftPole = MeshBuilder.CreateCylinder('netPoleLeft', { diameter: 0.12, height: 1.28 }, this.scene);
    leftPole.position = new Vector3(-5.7, 0.64, 0);
    leftPole.material = poleMat;
    const rightPole = MeshBuilder.CreateCylinder('netPoleRight', { diameter: 0.12, height: 1.28 }, this.scene);
    rightPole.position = new Vector3(5.7, 0.64, 0);
    rightPole.material = poleMat;

    const standMat = new StandardMaterial('standMat', this.scene);
    standMat.diffuseColor = Color3.FromHexString('#42506d');
    standMat.emissiveColor = Color3.FromHexString('#162033');
    standMat.backFaceCulling = false;
    const standSpecs = [
      { name: 'standNorth', width: 30, height: 8, x: 0, z: -18, rot: 0 },
      { name: 'standSouth', width: 30, height: 8, x: 0, z: 18, rot: Math.PI },
      { name: 'standEast', width: 42, height: 8, x: 13.5, z: 0, rot: Math.PI / 2 },
      { name: 'standWest', width: 42, height: 8, x: -13.5, z: 0, rot: -Math.PI / 2 },
    ];
    const stands = standSpecs.map((spec) => {
      const stand = MeshBuilder.CreatePlane(spec.name, { width: spec.width, height: spec.height }, this.scene);
      stand.position = new Vector3(spec.x, 4.5, spec.z);
      stand.rotation.y = spec.rot;
      stand.material = standMat;
      stand.billboardMode = babylon.Mesh.BILLBOARDMODE_Y;
      return stand;
    });

    const sky = MeshBuilder.CreateSphere('skyDome', { diameter: 160, segments: 16 }, this.scene);
    sky.scaling.y = 0.7;
    const skyMat = new StandardMaterial('skyMat', this.scene);
    skyMat.backFaceCulling = false;
    skyMat.disableLighting = true;
    skyMat.diffuseColor = Color3.FromHexString('#88d2ff');
    skyMat.emissiveColor = Color3.FromHexString('#72bfff');
    sky.material = skyMat;

    const playerMat = new StandardMaterial('playerMat', this.scene);
    playerMat.diffuseColor = Color3.FromHexString('#2563eb');
    playerMat.emissiveColor = Color3.FromHexString('#102d73');
    const opponentMat = new StandardMaterial('opponentMat', this.scene);
    opponentMat.diffuseColor = Color3.FromHexString('#dc2626');
    opponentMat.emissiveColor = Color3.FromHexString('#5f1010');

    const player = MeshBuilder.CreateCapsule('playerCapsule', { height: 1.7, radius: 0.32 }, this.scene);
    player.position = new Vector3(0, 0.85, 8.7);
    player.material = playerMat;
    const opponent = MeshBuilder.CreateCapsule('opponentCapsule', { height: 1.7, radius: 0.32 }, this.scene);
    opponent.position = new Vector3(0, 0.85, -8.7);
    opponent.rotation.y = Math.PI;
    opponent.material = opponentMat;

    const ball = MeshBuilder.CreateSphere('tennisBall', { diameter: 0.26, segments: 16 }, this.scene);
    ball.position = new Vector3(0, 1.25, 5.4);
    const ballMat = new StandardMaterial('ballMat', this.scene);
    ballMat.diffuseColor = Color3.FromHexString('#f6e94b');
    ballMat.emissiveColor = Color3.FromHexString('#777111');
    ball.material = ballMat;

    const trailMat = new StandardMaterial('trailMat', this.scene);
    trailMat.diffuseColor = Color3.FromHexString('#f9f28c');
    trailMat.emissiveColor = Color3.FromHexString('#7a731c');
    trailMat.alpha = 0.32;
    const ballTrail = [0.75, 0.55, 0.38].map((scale, index) => {
      const ghost = MeshBuilder.CreateSphere(`tennisBallTrail${index}`, { diameter: 0.26 * scale, segments: 10 }, this.scene);
      ghost.material = trailMat.clone(`trailMat${index}`);
      ghost.material.alpha = 0.28 - index * 0.07;
      ghost.position = ball.position.clone();
      return ghost;
    });

    [player, opponent, ball, leftPole, rightPole, netRibbon].forEach((mesh) => {
      this.shadowGenerator.addShadowCaster(mesh);
    });

    this.glowLayer = new GlowLayer('tennisGlow', this.scene);
    this.glowLayer.intensity = 0.45;

    this._clayDust = new ParticleSystem('clayDust', 160, this.scene);
    this._clayDust.emitter = new Vector3(0, 0.05, 0);
    this._clayDust.color1 = new Color4(0.93, 0.66, 0.42, 0.92);
    this._clayDust.color2 = new Color4(0.78, 0.39, 0.22, 0.78);
    this._clayDust.colorDead = new Color4(0.45, 0.2, 0.12, 0);
    this._clayDust.minSize = 0.05;
    this._clayDust.maxSize = 0.16;
    this._clayDust.minLifeTime = 0.2;
    this._clayDust.maxLifeTime = 0.55;
    this._clayDust.emitRate = 0;
    this._clayDust.minEmitPower = 0.8;
    this._clayDust.maxEmitPower = 3.2;
    this._clayDust.gravity = new Vector3(0, 2.4, 0);
    this._clayDust.direction1 = new Vector3(-1.2, 1.3, -1.2);
    this._clayDust.direction2 = new Vector3(1.2, 2.2, 1.2);
    this._clayDust.start();

    this._aceSparks = new ParticleSystem('aceSparks', 180, this.scene);
    this._aceSparks.emitter = new Vector3(0, 1.05, 0);
    this._aceSparks.color1 = new Color4(1, 1, 1, 1);
    this._aceSparks.color2 = new Color4(0.98, 0.9, 0.2, 1);
    this._aceSparks.colorDead = new Color4(0.9, 0.5, 0.05, 0);
    this._aceSparks.minSize = 0.04;
    this._aceSparks.maxSize = 0.1;
    this._aceSparks.minLifeTime = 0.12;
    this._aceSparks.maxLifeTime = 0.35;
    this._aceSparks.emitRate = 0;
    this._aceSparks.minEmitPower = 1.8;
    this._aceSparks.maxEmitPower = 5.4;
    this._aceSparks.gravity = new Vector3(0, -2.8, 0);
    this._aceSparks.direction1 = new Vector3(-1.4, 1.4, -0.8);
    this._aceSparks.direction2 = new Vector3(1.4, 2.6, 0.8);
    this._aceSparks.start();

    this.assets = {
      court: clay,
      courtLines,
      net: { ribbon: netRibbon, mesh: netMesh, leftPole, rightPole },
      stands,
      sky,
      player,
      opponent,
      ball,
      ballTrail,
      ambient,
      sun,
    };

    this._beforeRender = () => {
      this._tickCameraTween();
      this._tickBallTween();
      this._tickSwingTweens();
      this._updateTrail();
    };
    this.scene.onBeforeRenderObservable.add(this._beforeRender);

    scheduleIntegrityValidation(this, TENNIS_MANIFEST);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      this._applyShakeFrame(dtMs);
      this.scene?.render();
    });
    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    this.setCameraAngle('rally');
    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  setCameraAngle(angle) {
    if (!this.camera) return;

    const presets = {
      serve: { alpha: -Math.PI / 2, beta: Math.PI / 2.9, radius: 23, target: { x: 0, y: 1.7, z: 0 } },
      rally: { alpha: -Math.PI / 2.38, beta: Math.PI / 3.2, radius: 18, target: { x: 0, y: 1.6, z: 2.4 } },
      ace: { alpha: -Math.PI / 2, beta: 0.38, radius: 30, target: { x: 0, y: 0.9, z: 0 } },
    };

    const next = presets[angle] ?? presets.rally;
    this._cameraTween = {
      from: {
        alpha: this.camera.alpha,
        beta: this.camera.beta,
        radius: this.camera.radius,
        target: this.camera.target.clone(),
      },
      to: next,
      startAt: performance.now(),
      duration: angle === 'ace' ? 540 : 340,
    };
  }

  animateBallStroke(startPos, endPos, lob = false) {
    const { Vector3 } = this._babylon || {};
    if (!this.assets.ball || !Vector3) return;

    const from = new Vector3(startPos?.x ?? 0, startPos?.y ?? 1.1, startPos?.z ?? 0);
    const to = new Vector3(endPos?.x ?? 0, endPos?.y ?? 1.05, endPos?.z ?? 0);
    const distance = Vector3.Distance(from, to);
    this._ballTween = {
      from,
      to,
      startAt: performance.now(),
      duration: Math.max(520, Math.min(1200, distance * 90)),
      arc: lob ? 3.8 : 1.9,
      bounced: false,
      shadowHeight: lob ? 1.1 : 0.55,
    };
    this.assets.ball.position.copyFrom(from);
    this._trailHistory = [from.clone(), from.clone(), from.clone(), from.clone()];
  }

  animatePlayerSwing(side = 'forehand') {
    const targetMesh = side === 'opponent' ? this.assets.opponent : this.assets.player;
    if (!targetMesh) return;

    const direction = side === 'backhand' || side === 'opponent' ? -1 : 1;
    this._swingTweens.set(targetMesh.name, {
      mesh: targetMesh,
      startAt: performance.now(),
      duration: 260,
      baseRotY: targetMesh.rotation.y,
      direction,
    });
  }

  triggerAce() {
    if (!this.assets.net) return;
    const emitter = this.assets.net.ribbon.position.clone();
    this._aceSparks.emitter = emitter;
    this._aceSparks.manualEmitCount = 70;
    this.glowLayer && (this.glowLayer.intensity = 0.9);
    this.setCameraAngle('ace');
    if (this.assets.net.ribbon.scaling) {
      this.assets.net.ribbon.scaling.y = 1.6;
      setTimeout(() => {
        if (this.assets.net?.ribbon) this.assets.net.ribbon.scaling.y = 1;
        if (this.glowLayer) this.glowLayer.intensity = 0.45;
        this.setCameraAngle('rally');
      }, 650);
    }
  }

  burstClay(pos) {
    const { Vector3 } = this._babylon || {};
    if (!this._clayDust || !Vector3) return;
    this._clayDust.emitter = new Vector3(pos?.x ?? 0, pos?.y ?? 0.06, pos?.z ?? 0);
    this._clayDust.manualEmitCount = 40;
  }

  _tickCameraTween() {
    if (!this._cameraTween || !this.camera) return;
    const now = performance.now();
    const progress = Math.min(1, (now - this._cameraTween.startAt) / this._cameraTween.duration);
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
    const now = performance.now();
    const progress = Math.min(1, (now - this._ballTween.startAt) / this._ballTween.duration);
    const eased = easeInOut(progress);
    const { from, to, arc } = this._ballTween;

    const x = lerp(from.x, to.x, eased);
    const z = lerp(from.z, to.z, eased);
    const parabola = 4 * eased * (1 - eased);
    const y = lerp(from.y, to.y, eased) + parabola * arc;

    this.assets.ball.position.set(x, y, z);

    if (!this._ballTween.bounced && progress > 0.55 && y <= this._ballTween.shadowHeight) {
      this._ballTween.bounced = true;
      this.burstClay({ x, y: 0.05, z });
      this.systems?.audio?.playEvent?.('bounce');
    }

    if (progress >= 1) {
      this.assets.ball.position.copyFrom(to);
      this._ballTween = null;
    }
  }

  _tickSwingTweens() {
    if (!this._swingTweens.size) return;
    const now = performance.now();
    this._swingTweens.forEach((tween, key) => {
      const progress = Math.min(1, (now - tween.startAt) / tween.duration);
      const impulse = Math.sin(progress * Math.PI);
      tween.mesh.rotation.y = tween.baseRotY + tween.direction * impulse * 0.55;
      tween.mesh.scaling.x = 1 + impulse * 0.06;
      tween.mesh.scaling.z = 1 - impulse * 0.04;
      if (progress >= 1) {
        tween.mesh.rotation.y = tween.baseRotY;
        tween.mesh.scaling.set(1, 1, 1);
        this._swingTweens.delete(key);
      }
    });
  }

  _updateTrail() {
    if (!this.assets.ball || !this.assets.ballTrail?.length) return;
    this._trailHistory.unshift(this.assets.ball.position.clone());
    this._trailHistory = this._trailHistory.slice(0, 12);
    this.assets.ballTrail.forEach((ghost, index) => {
      const sample = this._trailHistory[Math.min(this._trailHistory.length - 1, (index + 1) * 3)] || this.assets.ball.position;
      ghost.position.copyFrom(sample);
    });
  }

  dispose() {
    this._disposedScene = true;
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
    if (this.engine) this.engine.stopRenderLoop();
    if (this.scene && this._beforeRender) {
      this.scene.onBeforeRenderObservable.removeCallback(this._beforeRender);
    }
    this._clayDust?.stop();
    this._aceSparks?.stop();
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
    this._cameraTween = null;
    this._ballTween = null;
    this._clayDust = null;
    this._aceSparks = null;
    this._trailHistory = [];
    this._swingTweens.clear();
    this._beforeRender = null;
    this._handleResize = null;
    this._babylon = null;
  }
}

export default TennisScene;

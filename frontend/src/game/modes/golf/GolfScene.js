import { GOLF_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';
let babylonModulePromise;

async function loadBabylonCore() {
  if (!babylonModulePromise) babylonModulePromise = import('@babylonjs/core');
  return babylonModulePromise;
}

const CAMERA_PRESETS = {
  tee: { alpha: -Math.PI / 2, beta: Math.PI / 3.1, radius: 21, target: { x: 0, y: 1.6, z: 7.5 } },
  approach: { alpha: -Math.PI / 3.2, beta: Math.PI / 2.75, radius: 18, target: { x: 0, y: 1.3, z: -2.5 } },
  pin: { alpha: -Math.PI / 1.98, beta: Math.PI / 3.9, radius: 13, target: { x: 0, y: 1.25, z: -14 } },
  flight: { alpha: -Math.PI / 2.45, beta: Math.PI / 4, radius: 16, target: { x: 0, y: 4, z: 0 } },
};

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function easeInOut(t) {
  return t < 0.5 ? 2 * t * t : 1 - ((-2 * t + 2) ** 2) / 2;
}

function toVector3(babylon, position = {}) {
  return new babylon.Vector3(position.x ?? 0, position.y ?? 0, position.z ?? 0);
}

export class GolfScene {
  constructor(canvas = null, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.BABYLON = null;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.glowLayer = null;
    this.shadowGenerator = null;
    this.assets = {};
    this.particles = {};
    this.isFallback = false;
    this._handleResize = null;
    this._beforeRender = null;
    this._cameraAngle = 'tee';
    this._cameraTween = null;
    this._ballFlight = null;
    this._swingTween = null;
    this._trailHistory = [];
    this._distancePlane = null;
    this._distanceTexture = null;
    this._timers = new Set();
    this._bunkers = [
      { x: -4.5, z: -5.5, radius: 2.25 },
      { x: 4.8, z: -11.2, radius: 2.4 },
    ];
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
    this.canvas = canvas ?? this.canvas;

    let babylon = null;
    try {
      babylon = await loadBabylonCore();

    // Disposed while loading (StrictMode remount): never create an Engine.
    if (this._disposedScene) {
      this.isFallback = true;
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }
    } catch {
      babylon = null;
    }

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'golf-fallback';
        this.canvas.style.background =
          'radial-gradient(circle at 50% 20%, #8fd3ff 0%, #56a84d 36%, #1b5e20 72%, #0b2f13 100%)';
      }
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
      ArcRotateCamera,
      Color3,
      Color4,
      DirectionalLight,
      DynamicTexture,
      Engine,
      GlowLayer,
      HemisphericLight,
      Mesh,
      MeshBuilder,
      ParticleSystem,
      Scene,
      ShadowGenerator,
      StandardMaterial,
      Vector3,
    } = babylon;

    this.BABYLON = babylon;
    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.62, 0.84, 1, 1);
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = Color3.FromHexString('#a7d9ff');
    this.scene.fogDensity = 0.0045;

    this.camera = new ArcRotateCamera('golfCamera', 0, 0, 22, Vector3.Zero(), this.scene);
    this.camera.lowerRadiusLimit = 9;
    this.camera.upperRadiusLimit = 34;
    this.camera.lowerBetaLimit = 0.3;
    this.camera.upperBetaLimit = Math.PI / 2.1;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    const hemi = new HemisphericLight('golfAmbient', new Vector3(0, 1, 0), this.scene);
    hemi.intensity = 0.82;
    hemi.diffuse = Color3.FromHexString('#f5fff0');
    hemi.groundColor = Color3.FromHexString('#1a4f22');

    const sun = new DirectionalLight('golfSun', new Vector3(-0.35, -1, 0.18), this.scene);
    sun.position = new Vector3(14, 24, 8);
    sun.intensity = 1.18;
    sun.diffuse = Color3.FromHexString('#fff2c4');
    sun.specular = Color3.FromHexString('#fff6de');

    this.shadowGenerator = new ShadowGenerator(1024, sun);
    this.shadowGenerator.useBlurExponentialShadowMap = true;
    this.shadowGenerator.blurKernel = 18;

    this.glowLayer = new GlowLayer('golfGlow', this.scene);
    this.glowLayer.intensity = 0.35;

    const sky = MeshBuilder.CreateSphere('golfSky', { diameter: 180, segments: 24 }, this.scene);
    const skyMat = new StandardMaterial('golfSkyMat', this.scene);
    skyMat.backFaceCulling = false;
    skyMat.disableLighting = true;
    skyMat.diffuseColor = Color3.FromHexString('#8bd0ff');
    skyMat.emissiveColor = Color3.FromHexString('#8bd0ff');
    sky.material = skyMat;

    const roughMat = new StandardMaterial('golfRoughMat', this.scene);
    roughMat.diffuseColor = Color3.FromHexString('#3f7f30');
    roughMat.specularColor = Color3.FromHexString('#183812');

    const fairwayMat = new StandardMaterial('golfFairwayMat', this.scene);
    fairwayMat.diffuseColor = Color3.FromHexString('#6ccc47');
    fairwayMat.specularColor = Color3.FromHexString('#285423');

    const greenMat = new StandardMaterial('golfGreenMat', this.scene);
    greenMat.diffuseColor = Color3.FromHexString('#87df5d');
    greenMat.specularColor = Color3.FromHexString('#2d6820');

    const sandMat = new StandardMaterial('golfSandMat', this.scene);
    sandMat.diffuseColor = Color3.FromHexString('#e4d3a2');
    sandMat.specularColor = Color3.FromHexString('#b6a06d');

    const waterMat = new StandardMaterial('golfWaterMat', this.scene);
    waterMat.diffuseColor = Color3.FromHexString('#42a5f5');
    waterMat.emissiveColor = Color3.FromHexString('#155b9f');
    waterMat.alpha = 0.88;

    const trunkMat = new StandardMaterial('golfTrunkMat', this.scene);
    trunkMat.diffuseColor = Color3.FromHexString('#8d5a2f');
    trunkMat.specularColor = Color3.FromHexString('#3c2511');

    const canopyMat = new StandardMaterial('golfCanopyMat', this.scene);
    canopyMat.diffuseColor = Color3.FromHexString('#3f9b3d');
    canopyMat.specularColor = Color3.FromHexString('#1f4f1e');

    const flagMat = new StandardMaterial('golfFlagMat', this.scene);
    flagMat.diffuseColor = Color3.FromHexString('#d82f2f');
    flagMat.emissiveColor = Color3.FromHexString('#4e1111');

    const pinCapMat = new StandardMaterial('golfPinCapMat', this.scene);
    pinCapMat.diffuseColor = Color3.White();
    pinCapMat.emissiveColor = Color3.FromHexString('#d7eefc');

    const golferMat = new StandardMaterial('golfGolferMat', this.scene);
    golferMat.diffuseColor = Color3.FromHexString('#f4f6fb');
    golferMat.specularColor = Color3.FromHexString('#5d6c8d');

    const caddieMat = new StandardMaterial('golfCaddieMat', this.scene);
    caddieMat.diffuseColor = Color3.FromHexString('#ffc857');
    caddieMat.emissiveColor = Color3.FromHexString('#66460f');

    const ballMat = new StandardMaterial('golfBallMat', this.scene);
    ballMat.diffuseColor = Color3.White();
    ballMat.emissiveColor = Color3.FromHexString('#d8eefb');
    ballMat.specularColor = Color3.FromHexString('#ffffff');
    ballMat.specularPower = 128;

    const rough = MeshBuilder.CreateGround('golfRough', { width: 44, height: 54, subdivisions: 4 }, this.scene);
    rough.position.y = -0.02;
    rough.material = roughMat;
    rough.receiveShadows = true;

    const teeBox = MeshBuilder.CreateBox('golfTeeBox', { width: 8.5, height: 0.5, depth: 8 }, this.scene);
    teeBox.position = new Vector3(0, 0.25, 15.5);
    teeBox.material = fairwayMat;
    teeBox.receiveShadows = true;

    const fairway = MeshBuilder.CreateBox('golfFairway', { width: 14, height: 0.34, depth: 26 }, this.scene);
    fairway.position = new Vector3(0, 0.17, 1.5);
    fairway.material = fairwayMat;
    fairway.receiveShadows = true;

    const green = MeshBuilder.CreateCylinder('golfGreen', { diameter: 14, height: 0.6, tessellation: 48 }, this.scene);
    green.position = new Vector3(0, 0.3, -13.5);
    green.material = greenMat;
    green.receiveShadows = true;

    const water = MeshBuilder.CreateGround('golfWater', { width: 8, height: 6 }, this.scene);
    water.position = new Vector3(8.5, 0.03, 0.4);
    water.rotation.x = 0;
    water.material = waterMat;

    const bunkerMeshes = this._bunkers.map((bunker, index) => {
      const mesh = MeshBuilder.CreateCylinder(
        `golfBunker${index}`,
        { diameter: bunker.radius * 2, height: 0.14, tessellation: 40 },
        this.scene
      );
      mesh.position = new Vector3(bunker.x, 0.08, bunker.z);
      mesh.material = sandMat;
      mesh.receiveShadows = true;
      return mesh;
    });

    const pin = MeshBuilder.CreateCylinder('golfPin', { diameter: 0.12, height: 4.6, tessellation: 12 }, this.scene);
    pin.position = new Vector3(0, 2.55, -14);
    pin.material = flagMat;

    const flagTop = MeshBuilder.CreateCylinder(
      'golfFlagTop',
      { diameterTop: 0, diameterBottom: 0.9, height: 1.2, tessellation: 3 },
      this.scene
    );
    flagTop.rotation.z = Math.PI / 2;
    flagTop.position = new Vector3(0.6, 3.45, -14);
    flagTop.material = pinCapMat;

    const cup = MeshBuilder.CreateCylinder('golfCup', { diameter: 0.4, height: 0.15, tessellation: 20 }, this.scene);
    cup.position = new Vector3(0, 0.39, -14);
    cup.material = new StandardMaterial('golfCupMat', this.scene);
    cup.material.diffuseColor = Color3.FromHexString('#1d1d1d');

    const golfer = MeshBuilder.CreateCapsule('golfGolfer', { radius: 0.58, height: 2.65, tessellation: 12 }, this.scene);
    golfer.position = new Vector3(-0.8, 1.62, 16.2);
    golfer.material = golferMat;

    const caddie = MeshBuilder.CreateCapsule('golfCaddie', { radius: 0.5, height: 2.35, tessellation: 12 }, this.scene);
    caddie.position = new Vector3(1.7, 1.45, 17.3);
    caddie.material = caddieMat;

    const ball = MeshBuilder.CreateSphere('golfBall', { diameter: 0.34, segments: 16 }, this.scene);
    ball.position = new Vector3(0, this._terrainHeightAt(0, 15.5) + 0.22, 15.3);
    ball.material = ballMat;

    const trail = Array.from({ length: 7 }, (_, index) => {
      const ghost = MeshBuilder.CreateSphere(`golfBallTrail${index}`, { diameter: 0.28 - index * 0.02, segments: 10 }, this.scene);
      const ghostMat = new StandardMaterial(`golfTrailMat${index}`, this.scene);
      ghostMat.diffuseColor = Color3.FromHexString('#dff5ff');
      ghostMat.emissiveColor = Color3.FromHexString('#9de3ff');
      ghostMat.alpha = clamp(0.42 - index * 0.05, 0.05, 0.42);
      ghost.material = ghostMat;
      ghost.isVisible = false;
      return ghost;
    });

    const treePositions = [
      [-12, 10], [-15, 2], [-13, -7], [-11, -15],
      [12, 12], [15, 4], [13, -4], [11, -14],
    ];
    const trees = treePositions.map(([x, z], index) => this._createTree(index, x, z, trunkMat, canopyMat));

    [teeBox, fairway, green, pin, flagTop, golfer, caddie, ball, ...bunkerMeshes, ...trees].forEach((mesh) => {
      if (mesh && mesh !== cup) this.shadowGenerator.addShadowCaster(mesh);
    });

    this.assets = {
      rough,
      teeBox,
      fairway,
      green,
      water,
      bunkers: bunkerMeshes,
      pin,
      flagTop,
      cup,
      golfer,
      caddie,
      ball,
      trail,
      trees,
    };

    this._distanceTexture = new DynamicTexture('golfDistanceTexture', { width: 512, height: 128 }, this.scene, false);
    const distanceMat = new StandardMaterial('golfDistanceMat', this.scene);
    distanceMat.diffuseTexture = this._distanceTexture;
    distanceMat.emissiveTexture = this._distanceTexture;
    distanceMat.opacityTexture = this._distanceTexture;
    distanceMat.backFaceCulling = false;
    this._distancePlane = MeshBuilder.CreatePlane('golfDistancePlane', { width: 8, height: 2 }, this.scene);
    this._distancePlane.position = new Vector3(0, 5.5, 2.2);
    this._distancePlane.billboardMode = Mesh.BILLBOARDMODE_ALL;
    this._distancePlane.material = distanceMat;

    const confetti = new ParticleSystem('golfConfetti', 640, this.scene);
    confetti.particleTexture = null;
    confetti.minEmitBox = new Vector3(-0.4, 0, -0.4);
    confetti.maxEmitBox = new Vector3(0.4, 0.6, 0.4);
    confetti.color1 = Color4.FromHexString('#ff4d4dff');
    confetti.color2 = Color4.FromHexString('#ffd54fff');
    confetti.colorDead = Color4.FromHexString('#4dd0e100');
    confetti.minLifeTime = 0.8;
    confetti.maxLifeTime = 1.8;
    confetti.minSize = 0.08;
    confetti.maxSize = 0.26;
    confetti.emitRate = 0;
    confetti.gravity = new Vector3(0, -8, 0);
    confetti.direction1 = new Vector3(-3, 5, -3);
    confetti.direction2 = new Vector3(3, 8, 3);
    confetti.emitter = pin;
    confetti.stop();

    const sandBurst = new ParticleSystem('golfSandBurst', 220, this.scene);
    sandBurst.particleTexture = null;
    sandBurst.color1 = Color4.FromHexString('#f3e0b0ff');
    sandBurst.color2 = Color4.FromHexString('#d6b780ff');
    sandBurst.colorDead = Color4.FromHexString('#8e6d3e00');
    sandBurst.minLifeTime = 0.25;
    sandBurst.maxLifeTime = 0.65;
    sandBurst.minSize = 0.05;
    sandBurst.maxSize = 0.22;
    sandBurst.emitRate = 0;
    sandBurst.gravity = new Vector3(0, -10, 0);
    sandBurst.direction1 = new Vector3(-1.4, 2.2, -1.4);
    sandBurst.direction2 = new Vector3(1.4, 3.8, 1.4);
    sandBurst.emitter = new Vector3(0, 0.2, 0);
    sandBurst.stop();

    this.particles = { confetti, sandBurst };
    this.showDistanceMarker(150);

    this._beforeRender = () => {
      this._tickCameraTween();
      this._tickSwingTween();
      this._tickBallFlight();
      this._updateTrail();
    };
    this.scene.onBeforeRenderObservable.add(this._beforeRender);
    scheduleIntegrityValidation(this, GOLF_MANIFEST);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      this._applyShakeFrame(dtMs);
      this.scene?.render();
    });

    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    this.setCameraAngle('tee');
    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  _createTree(index, x, z, trunkMat, canopyMat) {
    const { MeshBuilder, Vector3 } = this.BABYLON || {};
    if (!MeshBuilder || !Vector3 || !this.scene) return null;

    const trunk = MeshBuilder.CreateCylinder(`golfTreeTrunk${index}`, { diameter: 0.55, height: 3.2, tessellation: 10 }, this.scene);
    trunk.position = new Vector3(x, 1.55, z);
    trunk.material = trunkMat;
    this.shadowGenerator?.addShadowCaster(trunk);

    const canopy = MeshBuilder.CreateSphere(`golfTreeCanopy${index}`, { diameter: 2.8, segments: 12 }, this.scene);
    canopy.position = new Vector3(x, 3.85, z);
    canopy.material = canopyMat;
    this.shadowGenerator?.addShadowCaster(canopy);
    canopy.receiveShadows = true;

    return trunk;
  }

  _terrainHeightAt(x = 0, z = 0) {
    if (z > 10) return 0.5;
    if (z > -8) return 0.34;
    return 0.6;
  }

  _queueTimeout(callback, delay) {
    const timer = setTimeout(() => {
      this._timers.delete(timer);
      callback?.();
    }, delay);
    this._timers.add(timer);
    return timer;
  }

  setCameraAngle(angle = 'tee') {
    this._cameraAngle = angle;
    if (!this.camera || !this.BABYLON) return;

    const preset = CAMERA_PRESETS[angle] ?? CAMERA_PRESETS.tee;
    const { Vector3 } = this.BABYLON;
    this._cameraTween = {
      from: {
        alpha: this.camera.alpha,
        beta: this.camera.beta,
        radius: this.camera.radius,
        target: this.camera.target.clone(),
      },
      to: {
        alpha: preset.alpha,
        beta: preset.beta,
        radius: preset.radius,
        target: new Vector3(preset.target.x, preset.target.y, preset.target.z),
      },
      startAt: performance.now(),
      duration: angle === 'flight' ? 420 : 300,
    };
  }

  triggerHoleInOne() {
    if (this.particles.confetti) this.particles.confetti.manualEmitCount = 480;
    if (this.glowLayer) {
      this.glowLayer.intensity = 1.1;
      this._queueTimeout(() => {
        if (this.glowLayer) this.glowLayer.intensity = 0.35;
      }, 700);
    }
  }

  animateGolferSwing(power = 0.6) {
    if (!this.assets.golfer) return Promise.resolve();
    this._swingTween = {
      startAt: performance.now(),
      duration: 360,
      power: clamp(power, 0.2, 1.2),
      baseRotZ: this.assets.golfer.rotation.z,
      basePosY: this.assets.golfer.position.y,
    };
    return new Promise((resolve) => this._queueTimeout(resolve, 360));
  }

  showDistanceMarker(yards) {
    if (this.isFallback && this.canvas) {
      this.canvas.dataset.distanceMarker = `${Math.round(yards)} yds`;
      return;
    }
    if (!this._distanceTexture) return;
    const ctx = this._distanceTexture.getContext();
    ctx.clearRect(0, 0, 512, 128);
    ctx.fillStyle = 'rgba(4, 15, 29, 0.78)';
    ctx.fillRect(0, 0, 512, 128);
    ctx.strokeStyle = 'rgba(255,255,255,0.16)';
    ctx.lineWidth = 4;
    ctx.strokeRect(6, 6, 500, 116);
    ctx.fillStyle = '#9fe870';
    ctx.font = 'bold 52px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${Math.round(yards)} yds to pin`, 256, 64);
    this._distanceTexture.update();
  }

  animateBallFlight(startPos = {}, endPos = {}, apex = 8, duration = 1400) {
    if (this.isFallback || !this.assets.ball || !this.BABYLON) {
      return new Promise((resolve) => this._queueTimeout(() => resolve(endPos), duration));
    }

    const from = toVector3(this.BABYLON, startPos);
    const to = toVector3(this.BABYLON, endPos);
    from.y = startPos.y ?? this._terrainHeightAt(from.x, from.z) + 0.22;
    to.y = endPos.y ?? this._terrainHeightAt(to.x, to.z) + 0.22;
    this.assets.ball.position.copyFrom(from);
    this._trailHistory = Array.from({ length: 8 }, () => from.clone());
    this.setCameraAngle('flight');

    return new Promise((resolve) => {
      this._ballFlight = {
        from,
        to,
        apex: Math.max(apex, from.y + 2.4, to.y + 1.8),
        duration: Math.max(480, duration),
        startAt: performance.now(),
        resolve,
      };
    });
  }

  _tickCameraTween() {
    if (!this._cameraTween || !this.camera) return;
    const now = performance.now();
    const progress = clamp((now - this._cameraTween.startAt) / this._cameraTween.duration, 0, 1);
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

  _tickSwingTween() {
    if (!this._swingTween || !this.assets.golfer) return;
    const now = performance.now();
    const progress = clamp((now - this._swingTween.startAt) / this._swingTween.duration, 0, 1);
    const arc = Math.sin(progress * Math.PI);
    const lean = arc * 0.45 * this._swingTween.power;

    this.assets.golfer.rotation.z = this._swingTween.baseRotZ - lean;
    this.assets.golfer.position.y = this._swingTween.basePosY + arc * 0.15;

    if (this.assets.caddie) {
      this.assets.caddie.rotation.y = Math.sin(progress * Math.PI * 1.5) * 0.1;
    }

    if (progress >= 1) {
      this.assets.golfer.rotation.z = this._swingTween.baseRotZ;
      this.assets.golfer.position.y = this._swingTween.basePosY;
      if (this.assets.caddie) this.assets.caddie.rotation.y = 0;
      this._swingTween = null;
    }
  }

  _tickBallFlight() {
    if (!this._ballFlight || !this.assets.ball) return;
    const now = performance.now();
    const progress = clamp((now - this._ballFlight.startAt) / this._ballFlight.duration, 0, 1);
    const eased = easeInOut(progress);
    const { from, to, apex } = this._ballFlight;
    const midBase = lerp(from.y, to.y, 0.5);
    const arc = 4 * eased * (1 - eased);

    this.assets.ball.position.x = lerp(from.x, to.x, eased);
    this.assets.ball.position.z = lerp(from.z, to.z, eased);
    this.assets.ball.position.y = lerp(from.y, to.y, eased) + arc * (apex - midBase);
    this.assets.ball.rotation.x += 0.16;
    this.assets.ball.rotation.z += 0.1;

    if (this.camera && this._cameraAngle === 'flight') {
      this.camera.target.x = this.assets.ball.position.x;
      this.camera.target.y = this.assets.ball.position.y * 0.75;
      this.camera.target.z = this.assets.ball.position.z;
      this.camera.radius = lerp(18, 12, eased);
    }

    if (progress >= 1) {
      this.assets.ball.position.copyFrom(to);
      this.assets.ball.position.y = this._terrainHeightAt(to.x, to.z) + 0.22;
      if (this._landedInBunker(to) && this.particles.sandBurst) {
        this.particles.sandBurst.emitter = new this.BABYLON.Vector3(to.x, 0.32, to.z);
        this.particles.sandBurst.manualEmitCount = 90;
      }
      const done = this._ballFlight.resolve;
      this._ballFlight = null;
      this.setCameraAngle('pin');
      done?.({ x: to.x, y: this.assets.ball.position.y, z: to.z });
    }
  }

  _updateTrail() {
    if (!this.assets.ball || !Array.isArray(this.assets.trail)) return;
    this._trailHistory.unshift(this.assets.ball.position.clone());
    this._trailHistory = this._trailHistory.slice(0, 18);
    this.assets.trail.forEach((ghost, index) => {
      const sample = this._trailHistory[Math.min(this._trailHistory.length - 1, (index + 1) * 2)];
      if (!sample) {
        ghost.isVisible = false;
        return;
      }
      ghost.isVisible = !!this._ballFlight;
      ghost.position.copyFrom(sample);
    });
  }

  _landedInBunker(position) {
    return this._bunkers.some((bunker) => {
      const dx = (position.x ?? 0) - bunker.x;
      const dz = (position.z ?? 0) - bunker.z;
      return Math.sqrt(dx * dx + dz * dz) <= bunker.radius;
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
    this.particles.confetti?.stop?.();
    this.particles.sandBurst?.stop?.();
    this.glowLayer?.dispose?.();
    this.scene?.dispose?.();
    this.engine?.dispose?.();
    if (this.canvas) {
      delete this.canvas.dataset.sceneMode;
      delete this.canvas.dataset.distanceMarker;
      this.canvas.style.background = '';
    }
    this.BABYLON = null;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.glowLayer = null;
    this.shadowGenerator = null;
    this.assets = {};
    this.particles = {};
    this._beforeRender = null;
    this._handleResize = null;
    this._cameraTween = null;
    this._ballFlight = null;
    this._swingTween = null;
    this._trailHistory = [];
    this._distancePlane = null;
    this._distanceTexture = null;
  }
}

export default GolfScene;

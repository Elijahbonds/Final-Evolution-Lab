let babylonModulePromise = null;

const PARTICLE_TEXTURE_DATA_URI =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wn6zkQAAAAASUVORK5CYII=';

function toVector3(babylon, point = {}) {
  const { Vector3 } = babylon;
  return new Vector3(point.x ?? 0, point.y ?? 0, point.z ?? 0);
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

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

export class VolleyballScene {
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.glowLayer = null;
    this.assets = {};
    this.particles = {};
    this.isFallback = false;
    this._babylon = null;
    this._cameraAngle = 'serve';
    this._handleResize = null;
    this._activeAnimations = new Set();
    this._timeouts = new Set();
  }

  async init() {
    const babylon = await loadBabylonCore();
    this._babylon = babylon;

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'volleyball-fallback';
        this.canvas.style.background =
          'linear-gradient(180deg, #60a5fa 0%, #8dd8ff 36%, #39a1db 37%, #0f4c81 55%, #e6c78d 56%, #d9b977 100%)';
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
      StandardMaterial,
      Texture,
      Vector3,
    } = babylon;

    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.54, 0.8, 1, 1);
    this.scene.ambientColor = new Color3(0.8, 0.83, 0.9);

    this.camera = new ArcRotateCamera('volleyballCamera', -Math.PI / 2, Math.PI / 3.2, 24, new Vector3(0, 2.4, 0), this.scene);
    this.camera.lowerRadiusLimit = 10;
    this.camera.upperRadiusLimit = 36;
    this.camera.lowerBetaLimit = 0.45;
    this.camera.upperBetaLimit = Math.PI / 2.15;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('ambient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.9;
    ambient.groundColor = Color3.FromHexString('#c69d5d');

    const sun = new DirectionalLight('sun', new Vector3(-0.3, -1, 0.35), this.scene);
    sun.position = new Vector3(18, 28, -12);
    sun.intensity = 1.25;
    sun.diffuse = Color3.FromHexString('#fff4c6');
    sun.specular = Color3.FromHexString('#fff8dd');

    const shadowGenerator = new ShadowGenerator(1024, sun);
    shadowGenerator.useBlurExponentialShadowMap = true;
    shadowGenerator.blurKernel = 16;

    this.glowLayer = new GlowLayer('glow', this.scene, { blurKernelSize: 48 });
    this.glowLayer.intensity = 0.35;

    const sand = MeshBuilder.CreateGround('sand', { width: 24, height: 34, subdivisions: 2 }, this.scene);
    const sandMat = new StandardMaterial('sandMat', this.scene);
    sandMat.diffuseColor = Color3.FromHexString('#e7c98e');
    sandMat.specularColor = Color3.FromHexString('#7c6335');
    sandMat.emissiveColor = Color3.FromHexString('#261b08');
    sand.material = sandMat;
    sand.receiveShadows = true;

    const ocean = MeshBuilder.CreatePlane('ocean', { width: 70, height: 14 }, this.scene);
    ocean.position = new Vector3(0, 4, -26);
    const oceanMat = new StandardMaterial('oceanMat', this.scene);
    oceanMat.diffuseColor = Color3.FromHexString('#2aa3e0');
    oceanMat.emissiveColor = Color3.FromHexString('#0f4568');
    ocean.material = oceanMat;

    const skyDome = MeshBuilder.CreateSphere('skyDome', { diameter: 120, sideOrientation: Mesh.BACKSIDE }, this.scene);
    const skyMat = new StandardMaterial('skyMat', this.scene);
    skyMat.backFaceCulling = false;
    skyMat.diffuseColor = Color3.FromHexString('#6bc2ff');
    skyMat.emissiveColor = Color3.FromHexString('#2e83ca');
    skyDome.material = skyMat;

    const sunDisc = MeshBuilder.CreateDisc('sunDisc', { radius: 2.5, tessellation: 40 }, this.scene);
    sunDisc.position = new Vector3(20, 21, -42);
    const sunMat = new StandardMaterial('sunMat', this.scene);
    sunMat.diffuseColor = Color3.FromHexString('#fff1a8');
    sunMat.emissiveColor = Color3.FromHexString('#ffe86f');
    sunDisc.material = sunMat;
    this.glowLayer.addIncludedOnlyMesh(sunDisc);

    const lineMat = new StandardMaterial('lineMat', this.scene);
    lineMat.diffuseColor = Color3.White();
    lineMat.emissiveColor = Color3.FromHexString('#dfe9f5');
    lineMat.specularColor = Color3.Black();

    const boundarySpecs = [
      { name: 'baselineNorth', width: 9, depth: 0.12, x: 0, z: -8 },
      { name: 'baselineSouth', width: 9, depth: 0.12, x: 0, z: 8 },
      { name: 'sidelineWest', width: 0.12, depth: 16, x: -4.5, z: 0 },
      { name: 'sidelineEast', width: 0.12, depth: 16, x: 4.5, z: 0 },
      { name: 'centerMark', width: 9, depth: 0.08, x: 0, z: 0 },
    ];

    boundarySpecs.forEach((spec) => {
      const line = MeshBuilder.CreateBox(spec.name, { width: spec.width, height: 0.03, depth: spec.depth }, this.scene);
      line.position = new Vector3(spec.x, 0.025, spec.z);
      line.material = lineMat;
    });

    const poleMat = new StandardMaterial('poleMat', this.scene);
    poleMat.diffuseColor = Color3.FromHexString('#f8fafc');
    poleMat.specularColor = Color3.FromHexString('#9ca3af');

    const leftPole = MeshBuilder.CreateCylinder('leftPole', { diameter: 0.16, height: 3 }, this.scene);
    leftPole.position = new Vector3(-4.7, 1.5, 0);
    leftPole.material = poleMat;

    const rightPole = MeshBuilder.CreateCylinder('rightPole', { diameter: 0.16, height: 3 }, this.scene);
    rightPole.position = new Vector3(4.7, 1.5, 0);
    rightPole.material = poleMat;

    const netPaths = [];
    const columns = 14;
    for (let i = 0; i <= columns; i++) {
      const x = -4.45 + (i / columns) * 8.9;
      netPaths.push([
        new Vector3(x, 0.35, 0),
        new Vector3(x, 1.1, 0.06 * Math.sin(i * 0.7)),
        new Vector3(x, 1.8, 0.08 * Math.cos(i * 0.5)),
        new Vector3(x, 2.35, 0),
      ]);
    }
    const net = MeshBuilder.CreateRibbon('net', { pathArray: netPaths, sideOrientation: Mesh.DOUBLESIDE, closeArray: false }, this.scene);
    const netMat = new StandardMaterial('netMat', this.scene);
    netMat.diffuseColor = Color3.FromHexString('#f8fafc');
    netMat.emissiveColor = Color3.FromHexString('#5b6575');
    netMat.alpha = 0.58;
    net.material = netMat;

    const topTape = MeshBuilder.CreateBox('topTape', { width: 9.1, height: 0.1, depth: 0.12 }, this.scene);
    topTape.position = new Vector3(0, 2.38, 0);
    topTape.material = poleMat;

    const player = MeshBuilder.CreateCapsule('player', { radius: 0.42, height: 1.9 }, this.scene);
    player.position = new Vector3(0, 0.95, 5.8);
    const playerMat = new StandardMaterial('playerMat', this.scene);
    playerMat.diffuseColor = Color3.FromHexString('#3b82f6');
    playerMat.emissiveColor = Color3.FromHexString('#102d6a');
    player.material = playerMat;

    const opponent = MeshBuilder.CreateCapsule('opponent', { radius: 0.42, height: 1.9 }, this.scene);
    opponent.position = new Vector3(0, 0.95, -5.8);
    const opponentMat = new StandardMaterial('opponentMat', this.scene);
    opponentMat.diffuseColor = Color3.FromHexString('#ef4444');
    opponentMat.emissiveColor = Color3.FromHexString('#611919');
    opponent.material = opponentMat;

    const ball = MeshBuilder.CreateSphere('ball', { diameter: 0.5, segments: 24 }, this.scene);
    ball.position = new Vector3(0, 2.8, 2.5);
    const ballMat = new StandardMaterial('ballMat', this.scene);
    ballMat.diffuseColor = Color3.FromHexString('#fafafa');
    ballMat.specularColor = Color3.FromHexString('#111827');
    ball.material = ballMat;

    const stripe = MeshBuilder.CreateTorus('ballStripe', { diameter: 0.5, thickness: 0.06, tessellation: 36 }, this.scene);
    stripe.rotation.x = Math.PI / 2;
    stripe.parent = ball;
    const stripeMat = new StandardMaterial('stripeMat', this.scene);
    stripeMat.diffuseColor = Color3.FromHexString('#111827');
    stripeMat.emissiveColor = Color3.FromHexString('#05070d');
    stripe.material = stripeMat;

    [player, opponent, ball, leftPole, rightPole, topTape].forEach((mesh) => shadowGenerator.addShadowCaster(mesh));

    const palmMatTrunk = new StandardMaterial('palmTrunkMat', this.scene);
    palmMatTrunk.diffuseColor = Color3.FromHexString('#8b5e3c');
    const palmMatLeaves = new StandardMaterial('palmLeavesMat', this.scene);
    palmMatLeaves.diffuseColor = Color3.FromHexString('#22c55e');
    palmMatLeaves.emissiveColor = Color3.FromHexString('#0f3d1f');

    [
      [-10, -12],
      [10, -12],
      [-11, 10],
      [11, 9],
    ].forEach(([x, z], index) => {
      const trunk = MeshBuilder.CreateCylinder(`palmTrunk${index}`, { diameterTop: 0.28, diameterBottom: 0.42, height: 5.2 }, this.scene);
      trunk.position = new Vector3(x, 2.6, z);
      trunk.material = palmMatTrunk;
      trunk.rotation.z = index % 2 === 0 ? 0.08 : -0.08;
      shadowGenerator.addShadowCaster(trunk);

      for (let i = 0; i < 4; i++) {
        const frond = MeshBuilder.CreateCylinder(`palmLeaf${index}-${i}`, { diameterTop: 0, diameterBottom: 1.7, height: 2.5, tessellation: 3 }, this.scene);
        frond.position = new Vector3(x + Math.cos(i * (Math.PI / 2)) * 0.45, 5.3, z + Math.sin(i * (Math.PI / 2)) * 0.45);
        frond.rotation.z = Math.PI / 2.5;
        frond.rotation.y = i * (Math.PI / 2);
        frond.material = palmMatLeaves;
      }
    });

    const particleTexture = new Texture(PARTICLE_TEXTURE_DATA_URI, this.scene, true, false);

    const sandBurst = new ParticleSystem('sandBurst', 160, this.scene);
    sandBurst.particleTexture = particleTexture;
    sandBurst.minEmitBox = new Vector3(-0.4, 0, -0.4);
    sandBurst.maxEmitBox = new Vector3(0.4, 0.1, 0.4);
    sandBurst.color1 = new Color4(0.92, 0.82, 0.62, 1);
    sandBurst.color2 = new Color4(0.82, 0.69, 0.44, 1);
    sandBurst.gravity = new Vector3(0, -7.5, 0);
    sandBurst.minSize = 0.08;
    sandBurst.maxSize = 0.24;
    sandBurst.minLifeTime = 0.18;
    sandBurst.maxLifeTime = 0.45;
    sandBurst.emitRate = 300;
    sandBurst.disposeOnStop = false;
    sandBurst.emitter = player;
    sandBurst.stop();

    const waterSpray = new ParticleSystem('waterSpray', 220, this.scene);
    waterSpray.particleTexture = particleTexture;
    waterSpray.minEmitBox = new Vector3(-1.2, 0, -0.4);
    waterSpray.maxEmitBox = new Vector3(1.2, 0.3, 0.4);
    waterSpray.color1 = new Color4(0.65, 0.88, 1, 0.95);
    waterSpray.color2 = new Color4(0.2, 0.7, 1, 0.55);
    waterSpray.gravity = new Vector3(0, -4, 0);
    waterSpray.minSize = 0.05;
    waterSpray.maxSize = 0.18;
    waterSpray.minLifeTime = 0.25;
    waterSpray.maxLifeTime = 0.55;
    waterSpray.emitRate = 420;
    waterSpray.emitter = new Vector3(0, 0.3, -10.5);
    waterSpray.stop();

    const confetti = new ParticleSystem('confetti', 420, this.scene);
    confetti.particleTexture = particleTexture;
    confetti.minEmitBox = new Vector3(-1.8, 1.8, -1.2);
    confetti.maxEmitBox = new Vector3(1.8, 3.4, 1.2);
    confetti.color1 = new Color4(0.97, 0.31, 0.31, 1);
    confetti.color2 = new Color4(0.98, 0.87, 0.24, 1);
    confetti.colorDead = new Color4(0.2, 0.45, 0.95, 0.5);
    confetti.gravity = new Vector3(0, -2.5, 0);
    confetti.minSize = 0.06;
    confetti.maxSize = 0.22;
    confetti.minLifeTime = 0.8;
    confetti.maxLifeTime = 1.5;
    confetti.emitRate = 520;
    confetti.direction1 = new Vector3(-2, 6, -1);
    confetti.direction2 = new Vector3(2, 8, 1);
    confetti.emitter = new Vector3(0, 2.5, 0);
    confetti.stop();

    this.assets = {
      sand,
      ocean,
      skyDome,
      sunDisc,
      net,
      topTape,
      leftPole,
      rightPole,
      player,
      opponent,
      ball,
      stripe,
    };
    this.particles = { sandBurst, waterSpray, confetti };

    this.setCameraAngle('serve');

    this.engine.runRenderLoop(() => {
      this.scene?.render();
    });

    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') {
      window.addEventListener('resize', this._handleResize);
    }

    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  setCameraAngle(angle = 'serve') {
    this._cameraAngle = angle;
    if (!this.camera || !this._babylon) return;

    const { Vector3 } = this._babylon;
    const presets = {
      serve: { alpha: -Math.PI / 2.15, beta: Math.PI / 3.1, radius: 25, target: new Vector3(0, 2.2, 0) },
      spike: { alpha: -Math.PI / 2, beta: 1.02, radius: 16, target: new Vector3(0, 2.3, 1.6) },
      block: { alpha: -Math.PI / 2, beta: 0.88, radius: 10.5, target: new Vector3(0, 2.4, 0) },
    };
    const preset = presets[angle] ?? presets.serve;
    this.camera.alpha = preset.alpha;
    this.camera.beta = preset.beta;
    this.camera.radius = preset.radius;
    this.camera.setTarget(preset.target);
  }

  animateBallArc(startPos = {}, endPos = {}, apex = 5.5) {
    if (!this.assets.ball || !this._babylon) return Promise.resolve();
    const { Vector3 } = this._babylon;
    const start = toVector3(this._babylon, startPos);
    const end = toVector3(this._babylon, endPos);
    const peak = Math.max(start.y, end.y, apex);

    return this._animate(680, (t) => {
      const arc = 4 * t * (1 - t);
      this.assets.ball.position = new Vector3(
        lerp(start.x, end.x, t),
        lerp(start.y, end.y, t) + arc * (peak - lerp(start.y, end.y, 0.5)),
        lerp(start.z, end.z, t)
      );
      this.assets.stripe.rotation.y += 0.18;
    });
  }

  animateSpike() {
    if (!this.assets.player) return Promise.resolve();
    this.setCameraAngle('spike');
    const baseY = this.assets.player.position.y;

    return this._animate(360, (t) => {
      const jumpCurve = t < 0.5 ? t / 0.5 : (1 - t) / 0.5;
      this.assets.player.position.y = baseY + Math.max(0, jumpCurve) * 1.15;
      this.assets.player.scaling.x = 1 - jumpCurve * 0.06;
      this.assets.player.scaling.y = 1 + jumpCurve * 0.12;
      this.assets.player.scaling.z = 1 - jumpCurve * 0.06;
      if (this.assets.ball) {
        this.assets.ball.position.z = Math.max(-2.5, this.assets.ball.position.z - 0.06);
      }
    }, () => {
      this.assets.player.position.y = baseY;
      this.assets.player.scaling.setAll?.(1);
      if (this.assets.player.scaling.x !== undefined) {
        this.assets.player.scaling.x = 1;
        this.assets.player.scaling.y = 1;
        this.assets.player.scaling.z = 1;
      }
      this.setCameraAngle('serve');
    });
  }

  animateDig() {
    if (!this.assets.player) return Promise.resolve();
    const baseY = this.assets.player.position.y;
    this._burstParticles('sandBurst', 220, () => {
      if (this.assets.player) {
        this.particles.sandBurst.emitter = this.assets.player;
      }
    });

    return this._animate(280, (t) => {
      const crouch = t < 0.5 ? t / 0.5 : (1 - t) / 0.5;
      this.assets.player.position.y = baseY - crouch * 0.35;
      this.assets.player.rotation.z = -0.12 * crouch;
    }, () => {
      this.assets.player.position.y = baseY;
      this.assets.player.rotation.z = 0;
    });
  }

  triggerAce() {
    this._burstParticles('waterSpray', 260);
    if (this.glowLayer) {
      const previous = this.glowLayer.intensity;
      this.glowLayer.intensity = 0.75;
      this._queueTimeout(() => {
        if (this.glowLayer) this.glowLayer.intensity = previous;
      }, 240);
    }
  }

  triggerSetWin() {
    this._burstParticles('confetti', 900);
    this._burstParticles('waterSpray', 320);
    this.setCameraAngle('block');
    if (this.glowLayer) {
      this.glowLayer.intensity = 0.95;
      this._queueTimeout(() => {
        if (this.glowLayer) this.glowLayer.intensity = 0.35;
        this.setCameraAngle('serve');
      }, 700);
    }
  }

  dispose() {
    this._activeAnimations.forEach((cancel) => cancel());
    this._activeAnimations.clear();
    this._timeouts.forEach((id) => clearTimeout(id));
    this._timeouts.clear();

    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }

    Object.values(this.particles).forEach((system) => {
      try {
        system?.dispose?.();
      } catch {}
    });
    this.particles = {};

    try {
      this.glowLayer?.dispose?.();
      this.scene?.dispose?.();
      this.engine?.dispose?.();
    } catch {}

    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.glowLayer = null;
    this.assets = {};
    this._babylon = null;
  }

  _animate(durationMs, onFrame, onDone) {
    return new Promise((resolve) => {
      if (typeof onFrame !== 'function') {
        resolve();
        return;
      }

      const start = typeof performance !== 'undefined' ? performance.now() : Date.now();
      let cancelled = false;
      let rafId = null;
      const cancel = () => {
        cancelled = true;
        if (rafId !== null && typeof cancelAnimationFrame === 'function') {
          cancelAnimationFrame(rafId);
        }
      };

      this._activeAnimations.add(cancel);

      const tick = (now) => {
        if (cancelled) {
          this._activeAnimations.delete(cancel);
          resolve();
          return;
        }
        const elapsed = (now ?? Date.now()) - start;
        const t = Math.max(0, Math.min(1, elapsed / durationMs));
        onFrame(t);
        if (t >= 1) {
          this._activeAnimations.delete(cancel);
          onDone?.();
          resolve();
          return;
        }
        rafId = typeof requestAnimationFrame === 'function'
          ? requestAnimationFrame(tick)
          : setTimeout(() => tick(Date.now()), 16);
      };

      tick(start);
    });
  }

  _burstParticles(name, durationMs, beforeStart) {
    const system = this.particles[name];
    if (!system) return;
    beforeStart?.();
    system.start();
    this._queueTimeout(() => system.stop(), durationMs);
  }

  _queueTimeout(callback, delay) {
    const id = setTimeout(() => {
      this._timeouts.delete(id);
      callback();
    }, delay);
    this._timeouts.add(id);
    return id;
  }
}

export default VolleyballScene;

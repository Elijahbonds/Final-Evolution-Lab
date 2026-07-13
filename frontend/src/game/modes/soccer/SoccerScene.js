let babylonModulePromise = null;

async function loadBabylonCore() {
  if (babylonModulePromise) return babylonModulePromise;
  babylonModulePromise = (async () => {
    if (typeof window !== 'undefined' && window.BABYLON) return window.BABYLON;
    try {
      const importer = new Function('specifier', 'return import(specifier);');
      return await importer('@babylonjs/core');
    } catch {
      return null;
    }
  })();
  return babylonModulePromise;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export class SoccerScene {
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.BABYLON = null;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.glowLayer = null;
    this.particles = null;
    this.assets = {};
    this.isFallback = false;
    this._handleResize = null;
    this._timers = new Set();
    this._goalNetMeshes = [];
    this._crowdMeshes = [];
    this._cameraAngle = 'penalty';
    this._ballHome = { x: 0, y: 0.36, z: -15.5 };
    this._keeperHome = { x: 0, y: 1.1, z: -28 };
  }

  async init() {
    const babylon = await loadBabylonCore();

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'soccer-fallback';
        this.canvas.style.background =
          'radial-gradient(ellipse at 50% 25%, #78c850 0%, #237a3b 48%, #0d2d18 100%)';
      }
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
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
      SpotLight,
      StandardMaterial,
      Vector3,
    } = babylon;
    this.BABYLON = babylon;

    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.53, 0.79, 0.99, 1);
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = Color3.FromHexString('#87c2ff');
    this.scene.fogDensity = 0.006;

    const camera = new babylon.ArcRotateCamera(
      'soccerCamera',
      -Math.PI / 2,
      Math.PI / 2.9,
      20,
      new Vector3(0, 1.6, -22),
      this.scene
    );
    camera.attachControl(this.canvas, true);
    camera.lowerRadiusLimit = 12;
    camera.upperRadiusLimit = 32;
    camera.lowerBetaLimit = 0.4;
    camera.upperBetaLimit = Math.PI / 2.1;
    camera.wheelDeltaPercentage = 0.01;
    this.camera = camera;

    const ambient = new HemisphericLight('stadiumAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.82;
    ambient.diffuse = Color3.FromHexString('#d9f7d0');
    ambient.groundColor = Color3.FromHexString('#0f4021');

    const sun = new DirectionalLight('stadiumSun', new Vector3(-0.2, -1, 0.55), this.scene);
    sun.position = new Vector3(18, 24, -6);
    sun.intensity = 1.1;
    sun.diffuse = Color3.FromHexString('#fff2c2');

    const shadowGen = new ShadowGenerator(1024, sun);
    shadowGen.useBlurExponentialShadowMap = true;
    shadowGen.blurKernel = 20;

    const floodlightLeft = new SpotLight(
      'floodlightLeft',
      new Vector3(-18, 16, -10),
      new Vector3(0.45, -1, -0.5),
      Math.PI / 2.4,
      2.2,
      this.scene
    );
    floodlightLeft.intensity = 140;
    floodlightLeft.diffuse = Color3.FromHexString('#d8ecff');

    const floodlightRight = new SpotLight(
      'floodlightRight',
      new Vector3(18, 16, -10),
      new Vector3(-0.45, -1, -0.5),
      Math.PI / 2.4,
      2.2,
      this.scene
    );
    floodlightRight.intensity = 140;
    floodlightRight.diffuse = Color3.FromHexString('#d8ecff');

    const pitch = MeshBuilder.CreateGround('pitch', { width: 34, height: 60, subdivisions: 4 }, this.scene);
    const pitchMat = new StandardMaterial('pitchMat', this.scene);
    pitchMat.diffuseColor = Color3.FromHexString('#2f9e44');
    pitchMat.specularColor = Color3.FromHexString('#143d20');
    pitch.material = pitchMat;
    pitch.receiveShadows = true;

    const stripeMat = new StandardMaterial('stripeMat', this.scene);
    stripeMat.diffuseColor = Color3.FromHexString('#3eb559');
    stripeMat.specularColor = Color3.Black();
    for (let i = 0; i < 6; i++) {
      const stripe = MeshBuilder.CreateGround(`pitchStripe${i}`, { width: 34, height: 10 }, this.scene);
      stripe.position.z = 25 - i * 10;
      stripe.position.y = 0.01;
      stripe.material = i % 2 === 0 ? stripeMat : pitchMat;
    }

    const lineMat = new StandardMaterial('lineMat', this.scene);
    lineMat.diffuseColor = Color3.White();
    lineMat.emissiveColor = Color3.FromHexString('#dde7ef');
    lineMat.specularColor = Color3.Black();

    const centerCircle = MeshBuilder.CreateTorus('centerCircle', { diameter: 9.15, thickness: 0.08, tessellation: 64 }, this.scene);
    centerCircle.rotation.x = Math.PI / 2;
    centerCircle.position.y = 0.05;
    centerCircle.material = lineMat;

    const penaltySpot = MeshBuilder.CreateCylinder('penaltySpot', { diameter: 0.24, height: 0.04, tessellation: 24 }, this.scene);
    penaltySpot.position = new Vector3(0, 0.04, -15.5);
    penaltySpot.material = lineMat;

    const penaltyArc = MeshBuilder.CreateTorus('penaltyArc', { diameter: 7.3, thickness: 0.08, tessellation: 64 }, this.scene);
    penaltyArc.scaling.z = 0.58;
    penaltyArc.rotation.x = Math.PI / 2;
    penaltyArc.position = new Vector3(0, 0.05, -20);
    penaltyArc.material = lineMat;

    const goalPostMat = new StandardMaterial('goalPostMat', this.scene);
    goalPostMat.diffuseColor = Color3.White();
    goalPostMat.emissiveColor = Color3.FromHexString('#7fd7ff');
    goalPostMat.specularColor = Color3.FromHexString('#ffffff');
    goalPostMat.specularPower = 128;

    const goalLeft = MeshBuilder.CreateCylinder('goalLeft', { height: 2.6, diameter: 0.18, tessellation: 24 }, this.scene);
    goalLeft.position = new Vector3(-3.7, 1.3, -28);
    goalLeft.material = goalPostMat;

    const goalRight = MeshBuilder.CreateCylinder('goalRight', { height: 2.6, diameter: 0.18, tessellation: 24 }, this.scene);
    goalRight.position = new Vector3(3.7, 1.3, -28);
    goalRight.material = goalPostMat;

    const crossbar = MeshBuilder.CreateCylinder('crossbar', { height: 7.6, diameter: 0.18, tessellation: 24 }, this.scene);
    crossbar.rotation.z = Math.PI / 2;
    crossbar.position = new Vector3(0, 2.55, -28);
    crossbar.material = goalPostMat;

    const supportLeft = MeshBuilder.CreateCylinder('supportLeft', { height: 2.8, diameter: 0.12, tessellation: 18 }, this.scene);
    supportLeft.position = new Vector3(-3.7, 1.38, -30.3);
    supportLeft.material = goalPostMat;

    const supportRight = MeshBuilder.CreateCylinder('supportRight', { height: 2.8, diameter: 0.12, tessellation: 18 }, this.scene);
    supportRight.position = new Vector3(3.7, 1.38, -30.3);
    supportRight.material = goalPostMat;

    this._goalNetMeshes = [];
    for (let i = 0; i < 9; i++) {
      const ring = MeshBuilder.CreateTorus(
        `goalNetRing${i}`,
        { diameter: 7.3 - i * 0.28, thickness: 0.035, tessellation: 40 },
        this.scene
      );
      ring.rotation.x = Math.PI / 2;
      ring.position = new Vector3(0, 2.1 - i * 0.18, -28.25 - i * 0.22);
      const netMat = new StandardMaterial(`goalNetMat${i}`, this.scene);
      netMat.diffuseColor = Color3.White();
      netMat.alpha = 0.52;
      netMat.specularColor = Color3.Black();
      ring.material = netMat;
      this._goalNetMeshes.push(ring);
    }

    const standConfigs = [
      { id: 'north', position: new Vector3(0, 3.2, 29), rotationY: Math.PI, width: 36, height: 8 },
      { id: 'south', position: new Vector3(0, 3.2, -31), rotationY: 0, width: 36, height: 8 },
      { id: 'east', position: new Vector3(17, 3.2, 0), rotationY: -Math.PI / 2, width: 60, height: 8 },
      { id: 'west', position: new Vector3(-17, 3.2, 0), rotationY: Math.PI / 2, width: 60, height: 8 },
    ];
    this._crowdMeshes = standConfigs.map((config, index) => {
      const plane = MeshBuilder.CreatePlane(`crowdStrip${config.id}`, { width: config.width, height: config.height }, this.scene);
      plane.position = config.position;
      plane.rotation.y = config.rotationY;
      const crowdMat = new StandardMaterial(`crowdMat${config.id}`, this.scene);
      crowdMat.diffuseColor = Color3.FromHexString(index % 2 === 0 ? '#23345f' : '#3b264f');
      crowdMat.emissiveColor = Color3.FromHexString('#0d1224');
      crowdMat.backFaceCulling = false;
      plane.material = crowdMat;
      return plane;
    });

    ['-14', '14'].forEach((x, index) => {
      const tower = MeshBuilder.CreateBox(`lightTower${index}`, { width: 0.45, height: 14, depth: 0.45 }, this.scene);
      tower.position = new Vector3(Number(x), 7, -10);
      const towerMat = new StandardMaterial(`towerMat${index}`, this.scene);
      towerMat.diffuseColor = Color3.FromHexString('#708090');
      tower.material = towerMat;

      const lampRack = MeshBuilder.CreateBox(`lampRack${index}`, { width: 2.8, height: 0.35, depth: 0.8 }, this.scene);
      lampRack.position = new Vector3(Number(x), 13.7, -10.2);
      const lampMat = new StandardMaterial(`lampMat${index}`, this.scene);
      lampMat.diffuseColor = Color3.FromHexString('#e5efff');
      lampMat.emissiveColor = Color3.FromHexString('#8ec8ff');
      lampRack.material = lampMat;
    });

    const ball = MeshBuilder.CreateSphere('soccerBall', { diameter: 0.36, segments: 24 }, this.scene);
    ball.position = new Vector3(this._ballHome.x, this._ballHome.y, this._ballHome.z);
    const ballMat = new StandardMaterial('ballMat', this.scene);
    ballMat.diffuseColor = Color3.FromHexString('#fff7b2');
    ballMat.emissiveColor = Color3.FromHexString('#ffd60a');
    ballMat.specularColor = Color3.White();
    ball.material = ballMat;
    shadowGen.addShadowCaster(ball);

    const goalkeeper = MeshBuilder.CreateCapsule(
      'goalkeeper',
      { radius: 0.45, height: 2.1, tessellation: 12, subdivisions: 3 },
      this.scene
    );
    goalkeeper.position = new Vector3(this._keeperHome.x, this._keeperHome.y, this._keeperHome.z);
    const keeperMat = new StandardMaterial('keeperMat', this.scene);
    keeperMat.diffuseColor = Color3.FromHexString('#d62828');
    keeperMat.emissiveColor = Color3.FromHexString('#4f0f10');
    goalkeeper.material = keeperMat;
    shadowGen.addShadowCaster(goalkeeper);

    [goalLeft, goalRight, crossbar, supportLeft, supportRight].forEach((mesh) => shadowGen.addShadowCaster(mesh));

    this.glowLayer = new GlowLayer('soccerGlow', this.scene);
    this.glowLayer.intensity = 0.65;

    this.particles = new ParticleSystem('soccerConfetti', 260, this.scene);
    this.particles.emitter = new Vector3(0, 2.4, -27.6);
    this.particles.minEmitBox = new Vector3(-1.8, -0.2, -0.2);
    this.particles.maxEmitBox = new Vector3(1.8, 0.4, 0.2);
    this.particles.color1 = new Color4(0.98, 0.84, 0.12, 1);
    this.particles.color2 = new Color4(0.1, 0.82, 0.46, 1);
    this.particles.colorDead = new Color4(0, 0, 0, 0);
    this.particles.minSize = 0.05;
    this.particles.maxSize = 0.16;
    this.particles.minLifeTime = 0.8;
    this.particles.maxLifeTime = 1.8;
    this.particles.emitRate = 0;
    this.particles.minEmitPower = 2;
    this.particles.maxEmitPower = 6;
    this.particles.gravity = new Vector3(0, -8, 0);
    this.particles.direction1 = new Vector3(-2.5, 4, -1.5);
    this.particles.direction2 = new Vector3(2.5, 7, 1.5);
    this.particles.start();

    this.assets = {
      pitch,
      centerCircle,
      penaltyArc,
      penaltySpot,
      goal: { goalLeft, goalRight, crossbar, supportLeft, supportRight },
      goalNet: this._goalNetMeshes,
      crowd: this._crowdMeshes,
      ball,
      goalkeeper,
      ambient,
      sun,
      floodlightLeft,
      floodlightRight,
      shadowGen,
    };

    this.setCameraAngle('penalty');
    this.engine.runRenderLoop(() => this.scene?.render());
    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  setCameraAngle(angle) {
    if (!this.camera) return;
    this._cameraAngle = angle;
    const presets = {
      penalty: {
        alpha: -Math.PI / 2,
        beta: Math.PI / 2.9,
        radius: 18,
        target: { x: 0, y: 1.35, z: -23.5 },
      },
      goalkeeper: {
        alpha: Math.PI / 2,
        beta: Math.PI / 2.75,
        radius: 22,
        target: { x: 0, y: 1.7, z: -21.5 },
      },
    };
    const preset = presets[angle] ?? presets.penalty;
    this.camera.alpha = preset.alpha;
    this.camera.beta = preset.beta;
    this.camera.radius = preset.radius;
    if (this.BABYLON?.Vector3) {
      this.camera.setTarget(new this.BABYLON.Vector3(preset.target.x, preset.target.y, preset.target.z));
    }
  }

  triggerGoalCelebration() {
    if (this.particles) {
      this.particles.manualEmitCount = 120;
    }
    if (this.glowLayer) {
      this.glowLayer.intensity = 1.8;
      this._setTimer(() => {
        if (this.glowLayer) this.glowLayer.intensity = 0.65;
      }, 420);
    }

    const basePositions = this._goalNetMeshes.map((mesh) => mesh.position.z);
    let step = 0;
    const wobble = setInterval(() => {
      step += 0.18;
      this._goalNetMeshes.forEach((mesh, index) => {
        mesh.position.z = basePositions[index] - Math.sin(step * 3.5 + index * 0.45) * 0.1 * Math.exp(-step * 0.4);
      });
      this._crowdMeshes.forEach((mesh, index) => {
        if (mesh.material) {
          mesh.material.alpha = clamp(0.88 - (index % 2) * 0.1 + Math.sin(step * 6 + index) * 0.08, 0.6, 1);
        }
      });
      if (step > 3.2) {
        clearInterval(wobble);
        this._timers.delete(wobble);
        this._goalNetMeshes.forEach((mesh, index) => { mesh.position.z = basePositions[index]; });
        this._crowdMeshes.forEach((mesh) => {
          if (mesh.material) mesh.material.alpha = 1;
        });
      }
    }, 16);
    this._timers.add(wobble);
  }

  animateBallKick(direction = {}, power = 0.6) {
    const ball = this.assets.ball;
    if (!ball) return Promise.resolve();

    const targetX = clamp(direction.x ?? 0, -4.8, 4.8);
    const targetY = clamp(direction.y ?? (0.4 + power * 1.5), 0.25, 2.45);
    const targetZ = clamp(direction.z ?? -28.1, -31, -24.5);
    const start = { x: this._ballHome.x, y: this._ballHome.y, z: this._ballHome.z };
    const duration = 520 + Math.round((1 - clamp(power, 0, 1)) * 260);
    const startedAt = Date.now();

    if (this._ballFlightTimer) {
      clearInterval(this._ballFlightTimer);
      this._timers.delete(this._ballFlightTimer);
    }

    ball.position.set(start.x, start.y, start.z);
    ball.rotation.set(0, 0, 0);

    return new Promise((resolve) => {
      const timer = setInterval(() => {
        const elapsed = Date.now() - startedAt;
        const t = clamp(elapsed / duration, 0, 1);
        const arcHeight = Math.sin(t * Math.PI) * (0.45 + power * 1.35);
        ball.position.x = start.x + (targetX - start.x) * t;
        ball.position.y = start.y + (targetY - start.y) * t + arcHeight;
        ball.position.z = start.z + (targetZ - start.z) * t;
        ball.rotation.x += 0.18 + power * 0.08;
        ball.rotation.z += 0.1 + Math.abs(targetX) * 0.02;

        if (t >= 1) {
          clearInterval(timer);
          this._timers.delete(timer);
          this._setTimer(() => this._resetBall(), 850);
          resolve({ x: ball.position.x, y: ball.position.y, z: ball.position.z });
        }
      }, 16);

      this._ballFlightTimer = timer;
      this._timers.add(timer);
    });
  }

  animateGoalkeeperDive(side = 'center') {
    const keeper = this.assets.goalkeeper;
    if (!keeper) return Promise.resolve();

    const targetX = side === 'left' ? -2.8 : side === 'right' ? 2.8 : 0;
    const targetY = side === 'center' ? this._keeperHome.y + 0.15 : this._keeperHome.y - 0.18;
    const targetZRot = side === 'left' ? -0.55 : side === 'right' ? 0.55 : 0;
    const startedAt = Date.now();
    const duration = side === 'center' ? 320 : 420;

    if (this._keeperDiveTimer) {
      clearInterval(this._keeperDiveTimer);
      this._timers.delete(this._keeperDiveTimer);
    }

    return new Promise((resolve) => {
      const timer = setInterval(() => {
        const t = clamp((Date.now() - startedAt) / duration, 0, 1);
        keeper.position.x = this._keeperHome.x + (targetX - this._keeperHome.x) * t;
        keeper.position.y = this._keeperHome.y + (targetY - this._keeperHome.y) * Math.sin(t * Math.PI);
        keeper.rotation.z = targetZRot * t;
        keeper.rotation.x = 0.12 * Math.sin(t * Math.PI);

        if (t >= 1) {
          clearInterval(timer);
          this._timers.delete(timer);
          this._setTimer(() => this._resetGoalkeeper(), 420);
          resolve(side);
        }
      }, 16);

      this._keeperDiveTimer = timer;
      this._timers.add(timer);
    });
  }

  _resetBall() {
    const ball = this.assets.ball;
    if (!ball) return;
    ball.position.set(this._ballHome.x, this._ballHome.y, this._ballHome.z);
    ball.rotation.set(0, 0, 0);
  }

  _resetGoalkeeper() {
    const keeper = this.assets.goalkeeper;
    if (!keeper) return;
    keeper.position.set(this._keeperHome.x, this._keeperHome.y, this._keeperHome.z);
    keeper.rotation.set(0, 0, 0);
  }

  _setTimer(fn, delay) {
    const timer = setTimeout(() => {
      this._timers.delete(timer);
      fn();
    }, delay);
    this._timers.add(timer);
    return timer;
  }

  dispose() {
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
    this._timers.forEach((timer) => {
      clearTimeout(timer);
      clearInterval(timer);
    });
    this._timers.clear();
    this.particles?.stop();
    this.glowLayer?.dispose();
    if (this.engine) this.engine.stopRenderLoop();
    this.scene?.dispose();
    this.engine?.dispose();
    if (this.canvas) {
      delete this.canvas.dataset.sceneMode;
      this.canvas.style.background = '';
    }
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.BABYLON = null;
    this.glowLayer = null;
    this.particles = null;
    this.assets = {};
    this._goalNetMeshes = [];
    this._crowdMeshes = [];
    this._handleResize = null;
  }
}

export default SoccerScene;

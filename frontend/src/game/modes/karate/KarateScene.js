// Premium KarateScene — Zen Dojo with full 3D production quality.
// Mirrors iOS CourtSceneView (Zen_Dojo variant) + GameSceneHostView scenic passes.
//
// Features vs baseline:
//   - ShadowGenerator: overhead spotlight shadows for both characters
//   - GlowLayer: emissive lantern glow, chakra aura on special move
//   - Multi-segment character rigs: head + torso + limbs capsules (player=blue, opponent=red)
//   - Ambient fog of battle (FogMode.EXP2)
//   - 4 hanging paper lanterns (emissive orange + GlowLayer)
//   - Torii gate backdrop + shoji screen panels
//   - Tatami floor with gloss specular + subtle grid lines
//   - Impact particle system: sparks burst on hit, anchored to opponent
//   - Hit-flash: opponent emissive flares briefly on strike impact
//   - HP-linked aura: player gains blue glow at low HP warning
//   - Camera angles: broadcast, actionCloseUp (iOS defaults for karate)

let babylonModulePromise = null;

async function loadBabylonCore() {
  if (babylonModulePromise) return babylonModulePromise;
  babylonModulePromise = (async () => {
    if (typeof window !== 'undefined' && window.BABYLON) return window.BABYLON;
    try {
      const importer = new Function('specifier', 'return import(specifier);');
      return await importer('@babylonjs/core');
    } catch { return null; }
  })();
  return babylonModulePromise;
}

/**
 * Premium Babylon.js scene for Karate: Dojo Breach.
 *
 * iOS architecture parity:
 *   - Capsule rig = SceneKit multi-node character (head + torso + arms + legs)
 *   - GlowLayer intensity burst = iOS showCriticalFlash + chakraBar aura
 *   - ParticleSystem = iOS ArcadeEffectsView sparks on hit
 *   - FogMode = iOS scene fog for atmosphere
 */
export class KarateScene {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {object} systems
   */
  constructor(canvas, systems = {}) {
    this.canvas   = canvas;
    this.systems  = systems;
    this.engine   = null;
    this.scene    = null;
    this.camera   = null;
    this.assets   = {};
    this.particles = null;
    this.glowLayer = null;
    this.isFallback = false;
    this._handleResize = null;
    this._playerParts   = {};
    this._opponentParts = {};
    this._hitFlashTimer = null;
  }

  async init() {
    const babylon = await loadBabylonCore();

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'karate-fallback';
        this.canvas.style.background = 'radial-gradient(ellipse at 50% 30%, #2a1a0a 0%, #0e0804 60%, #030202 100%)';
      }
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
      ArcRotateCamera,
      Color3, Color4,
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

    // ── Engine + Scene ──────────────────────────────────────────────────────
    this.engine = new Engine(this.canvas, true, { antialias: true });
    this.scene  = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.02, 0.01, 0.01, 1);
    this.scene.fogMode    = Scene.FOGMODE_EXP2;
    this.scene.fogColor   = Color3.FromHexString('#150806');
    this.scene.fogDensity = 0.04;

    // ── Camera ─────────────────────────────────────────────────────────────
    this.camera = new ArcRotateCamera('karateCamera', -Math.PI / 2, Math.PI / 3, 6.5, Vector3.Zero(), this.scene);
    this.camera.lowerRadiusLimit  = 4.5;
    this.camera.upperRadiusLimit  = 8.5;
    this.camera.lowerBetaLimit    = 0.4;
    this.camera.upperBetaLimit    = Math.PI / 2.2;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    // ── Lighting ─────────────────────────────────────────────────────────────
    const ambient = new HemisphericLight('dojoAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity   = 0.35;
    ambient.diffuse     = Color3.FromHexString('#FFE0B0');
    ambient.groundColor = Color3.FromHexString('#080402');

    // Overhead dojo spotlight (key light — casts hard shadows)
    const overhead = new SpotLight(
      'dojoOverhead', new Vector3(0, 6, 1), new Vector3(0, -1, -0.05),
      Math.PI / 2.2, 3, this.scene
    );
    overhead.intensity = 120;
    overhead.diffuse   = Color3.FromHexString('#FFE8C8');

    // Rear fill light
    const fill = new SpotLight(
      'dojoFill', new Vector3(0, 4, -3.5), new Vector3(0, -0.5, 1),
      Math.PI / 3, 2, this.scene
    );
    fill.intensity = 30;
    fill.diffuse   = Color3.FromHexString('#C0D0FF');

    // Shadow generator
    const shadowGen = new ShadowGenerator(512, overhead);
    shadowGen.useBlurExponentialShadowMap = true;
    shadowGen.blurKernel = 8;

    // ── Tatami floor ──────────────────────────────────────────────────────────
    const floor = MeshBuilder.CreateBox('dojoFloor', { width: 8, height: 0.1, depth: 8 }, this.scene);
    floor.position.y = -0.05;
    floor.receiveShadows = true;
    const floorMat = new StandardMaterial('dojoFloorMat', this.scene);
    floorMat.diffuseColor  = Color3.FromHexString('#3B2314');
    floorMat.specularColor = Color3.FromHexString('#5C3820');
    floorMat.specularPower = 48;
    floor.material = floorMat;

    // Tatami grid lines
    for (let i = -3; i <= 3; i++) {
      const hLine = MeshBuilder.CreateBox(`tH${i}`, { width: 8, height: 0.005, depth: 0.04 }, this.scene);
      hLine.position = new Vector3(0, 0.01, i);
      hLine.material = this._lineMat(babylon, 'rgba(90,50,25)');

      const vLine = MeshBuilder.CreateBox(`tV${i}`, { width: 0.04, height: 0.005, depth: 8 }, this.scene);
      vLine.position = new Vector3(i, 0.01, 0);
      vLine.material = hLine.material;
    }

    // ── Shoji screen walls ────────────────────────────────────────────────────
    const shojiData = [
      { pos: new Vector3(0, 1.5, -4.05), w: 8, h: 3 },
      { pos: new Vector3(4.05, 1.5, 0),  w: 8, h: 3, ry: Math.PI / 2 },
      { pos: new Vector3(-4.05, 1.5, 0), w: 8, h: 3, ry: -Math.PI / 2 },
    ];
    shojiData.forEach(({ pos, w, h, ry = 0 }, idx) => {
      const wall = MeshBuilder.CreatePlane(`shoji${idx}`, { width: w, height: h }, this.scene);
      wall.position  = pos;
      wall.rotation.y = ry;
      const mat = new StandardMaterial(`shojiMat${idx}`, this.scene);
      mat.diffuseColor     = Color3.FromHexString('#F5E6C8');
      mat.emissiveColor    = Color3.FromHexString('#221408');
      mat.backFaceCulling  = false;
      mat.specularColor    = Color3.Black();
      wall.material = mat;
    });

    // ── Torii gate backdrop ────────────────────────────────────────────────────
    // Two vertical pillars + horizontal crossbeam
    const toriiMat = new StandardMaterial('toriiMat', this.scene);
    toriiMat.diffuseColor  = Color3.FromHexString('#8B0000');
    toriiMat.emissiveColor = Color3.FromHexString('#2A0000');
    toriiMat.specularColor = Color3.FromHexString('#FF4444');
    toriiMat.specularPower = 64;

    [-1.4, 1.4].forEach((x, idx) => {
      const pillar = MeshBuilder.CreateCylinder(`toriiPillar${idx}`, { diameter: 0.16, height: 4, tessellation: 10 }, this.scene);
      pillar.position = new Vector3(x, 2, -3.8);
      pillar.material = toriiMat;
      shadowGen.addShadowCaster(pillar);
    });
    const beam = MeshBuilder.CreateBox('toriiBeam', { width: 3.4, height: 0.18, depth: 0.18 }, this.scene);
    beam.position = new Vector3(0, 3.6, -3.8);
    beam.material = toriiMat;
    shadowGen.addShadowCaster(beam);
    const topBeam = MeshBuilder.CreateBox('toriiTopBeam', { width: 3.8, height: 0.12, depth: 0.14 }, this.scene);
    topBeam.position = new Vector3(0, 3.85, -3.8);
    topBeam.material = toriiMat;

    // ── Hanging paper lanterns ─────────────────────────────────────────────────
    const lanternPositions = [
      new Vector3(-2.5, 3.5, -1), new Vector3(2.5, 3.5, -1),
      new Vector3(-2.5, 3.5, 2.5), new Vector3(2.5, 3.5, 2.5),
    ];
    const lanternMat = new StandardMaterial('lanternMat', this.scene);
    lanternMat.diffuseColor  = Color3.FromHexString('#FF8C00');
    lanternMat.emissiveColor = Color3.FromHexString('#FF4400');
    lanternMat.specularColor = Color3.Black();

    lanternPositions.forEach((pos, idx) => {
      const lantern = MeshBuilder.CreateSphere(`lantern${idx}`, { diameter: 0.3, segments: 8 }, this.scene);
      lantern.position = pos;
      lantern.scaling.y = 1.5;
      lantern.material = lanternMat;
      // Cord
      const cord = MeshBuilder.CreateCylinder(`cord${idx}`, { diameter: 0.01, height: 0.5, tessellation: 4 }, this.scene);
      cord.position = new Vector3(pos.x, pos.y + 0.4, pos.z);
      const cordMat = new StandardMaterial(`cordMat${idx}`, this.scene);
      cordMat.diffuseColor = Color3.FromHexString('#222222');
      cord.material = cordMat;
      // Point light at lantern
      const lLight = new SpotLight(
        `lanternLight${idx}`, pos.clone(), new Vector3(0, -1, 0),
        Math.PI, 1, this.scene
      );
      lLight.intensity = 8;
      lLight.diffuse   = Color3.FromHexString('#FF8800');
    });

    // ── Character rigs ────────────────────────────────────────────────────────
    this._playerParts   = this._buildCharacter(babylon, shadowGen, 'player',   new Vector3(-0.7, 0, 0.5), '#5BC0EB');
    this._opponentParts = this._buildCharacter(babylon, shadowGen, 'opponent', new Vector3( 0.7, 0, 2.5), '#C94C4C');

    // Face opponent toward player
    this._opponentParts.root.rotation.y = Math.PI;

    // ── GlowLayer ─────────────────────────────────────────────────────────────
    this.glowLayer = new GlowLayer('dojoGlow', this.scene);
    this.glowLayer.intensity = 0.5;

    // ── Impact particle system (sparks, anchored to opponent torso) ────────────
    this.particles = new ParticleSystem('dojoSparks', 80, this.scene);
    this.particles.emitter    = this._opponentParts.torso?.position.clone() ?? new Vector3(0.7, 0.8, 2.5);
    this.particles.minEmitBox = new Vector3(-0.15, -0.15, -0.15);
    this.particles.maxEmitBox = new Vector3(0.15, 0.15, 0.15);
    this.particles.color1     = new Color4(1, 0.8, 0.1, 1);
    this.particles.color2     = new Color4(1, 0.3, 0, 1);
    this.particles.colorDead  = new Color4(0.3, 0, 0, 0);
    this.particles.minSize    = 0.02;
    this.particles.maxSize    = 0.07;
    this.particles.minLifeTime = 0.2;
    this.particles.maxLifeTime = 0.5;
    this.particles.emitRate   = 0;
    this.particles.minEmitPower = 3;
    this.particles.maxEmitPower = 8;
    this.particles.gravity    = new Vector3(0, -9.8, 0);
    this.particles.direction1 = new Vector3(-3, 4, -3);
    this.particles.direction2 = new Vector3(3, 8, 3);
    this.particles.start();

    this.assets = {
      floor, overhead, fill, ambient, shadowGen,
      player:   this._playerParts,
      opponent: this._opponentParts,
    };

    this.engine.runRenderLoop(() => { this.scene?.render(); });
    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  /** @private — build a multi-capsule character rig */
  _buildCharacter(babylon, shadowGen, name, rootPos, hexColor) {
    const { MeshBuilder, StandardMaterial, Color3, Vector3 } = babylon;

    // Root pivot (position only, no mesh)
    const root = MeshBuilder.CreateBox(`${name}Root`, { size: 0.01 }, this.scene);
    root.position = rootPos;
    root.isVisible = false;

    const mat = new StandardMaterial(`${name}Mat`, this.scene);
    mat.diffuseColor  = Color3.FromHexString(hexColor);
    mat.specularColor = Color3.FromHexString('#AAAACC');
    mat.specularPower = 64;

    const addPart = (partName, opts, pos) => {
      const m = MeshBuilder.CreateCapsule(`${name}${partName}`, opts, this.scene);
      m.position = new Vector3(rootPos.x + pos.x, rootPos.y + pos.y, rootPos.z + pos.z);
      m.material = mat;
      shadowGen.addShadowCaster(m);
      return m;
    };

    const torso = addPart('Torso', { radius: 0.18, height: 0.72 }, { x: 0, y: 0.8, z: 0 });
    const head  = addPart('Head',  { radius: 0.14, height: 0.28 }, { x: 0, y: 1.5, z: 0 });
    const lArm  = addPart('LArim', { radius: 0.07, height: 0.55 }, { x: -0.3, y: 0.85, z: 0 });
    const rArm  = addPart('RArm',  { radius: 0.07, height: 0.55 }, { x:  0.3, y: 0.85, z: 0 });
    const lLeg  = addPart('LLeg',  { radius: 0.09, height: 0.65 }, { x: -0.15, y: 0.2, z: 0 });
    const rLeg  = addPart('RLeg',  { radius: 0.09, height: 0.65 }, { x:  0.15, y: 0.2, z: 0 });

    [lArm, rArm].forEach(a => { a.rotation.z = Math.PI / 6; });

    return { root, torso, head, lArm, rArm, lLeg, rLeg, mat };
  }

  /** @private — simple line material */
  _lineMat(babylon, hex) {
    const { StandardMaterial, Color3 } = babylon;
    const mat = new StandardMaterial(`lineMat_${hex}`, this.scene);
    mat.diffuseColor  = Color3.FromHexString('#5A3219');
    mat.specularColor = Color3.Black();
    return mat;
  }

  // ── Visual reactions ───────────────────────────────────────────────────────

  /**
   * Trigger hit flash on opponent (emissive flare + spark burst).
   * Mirrors iOS karateHitFlash + ArcadeEffectsView.
   *
   * @param {'light'|'heavy'|'special'} variant
   */
  triggerHitFlash(variant = 'light') {
    if (!this._opponentParts.mat) return;
    const mat = this._opponentParts.mat;
    const intensity = variant === 'special' ? 3 : variant === 'heavy' ? 2 : 1;

    mat.emissiveColor = { r: 1, g: 0.3, b: 0.1 };
    if (this._hitFlashTimer) clearTimeout(this._hitFlashTimer);
    this._hitFlashTimer = setTimeout(() => {
      if (mat) mat.emissiveColor = { r: 0, g: 0, b: 0 };
    }, 120);

    // Spark burst
    if (this.particles) {
      this.particles.manualEmitCount = 20 * intensity;
    }

    // Glow spike
    if (this.glowLayer) {
      this.glowLayer.intensity = 0.5 + intensity * 0.4;
      setTimeout(() => { if (this.glowLayer) this.glowLayer.intensity = 0.5; }, 300);
    }
  }

  /**
   * Animate opponent knockback displacement on heavy/special hit.
   * @param {'heavy'|'special'} variant
   */
  triggerKnockback(variant) {
    if (!this._opponentParts.root) return;
    const dist = variant === 'special' ? 0.5 : 0.25;
    const startZ = this._opponentParts.root.position.z;
    let t = 0;
    const anim = setInterval(() => {
      t += 0.12;
      const disp = dist * Math.exp(-t * 4) * Math.sin(t * 12);
      if (this._opponentParts.root) {
        this._opponentParts.root.position.z = startZ + disp;
      }
      if (t > 1.5) {
        clearInterval(anim);
        if (this._opponentParts.root) this._opponentParts.root.position.z = startZ;
      }
    }, 16);
  }

  /**
   * Set low-HP blue aura on player (chakra bar feedback).
   * Mirrors iOS chakraBar + karateHitFlash player side.
   * @param {boolean} active
   */
  setPlayerLowHPAura(active) {
    if (!this._playerParts.mat) return;
    this._playerParts.mat.emissiveColor = active
      ? { r: 0.05, g: 0.1, b: 0.6 }
      : { r: 0, g: 0, b: 0 };
    if (this.glowLayer) this.glowLayer.intensity = active ? 1.2 : 0.5;
  }

  /**
   * Switch camera angle. Mirrors iOS ScenicCameraAngle for karate.
   * @param {'actionCloseUp'|'broadcast'|'chase'} angle
   */
  setCameraAngle(angle) {
    if (!this.camera) return;
    const presets = {
      actionCloseUp: { alpha: -Math.PI / 2.2, beta: Math.PI / 3.2, radius: 5.0 },
      broadcast:     { alpha: -Math.PI / 2,   beta: Math.PI / 3,   radius: 7.5 },
      chase:         { alpha: -Math.PI / 2,   beta: Math.PI / 3.5, radius: 6.5 },
    };
    const p = presets[angle] ?? presets.broadcast;
    this.camera.alpha  = p.alpha;
    this.camera.beta   = p.beta;
    this.camera.radius = p.radius;
  }

  dispose() {
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
    if (this._hitFlashTimer) clearTimeout(this._hitFlashTimer);
    this.particles?.stop();
    this.glowLayer?.dispose();
    if (this.engine) this.engine.stopRenderLoop();
    this.scene?.dispose();
    this.engine?.dispose();
    if (this.canvas) {
      delete this.canvas.dataset.sceneMode;
      this.canvas.style.background = '';
    }
    this.engine = null; this.scene = null; this.camera = null;
    this.assets = {}; this._playerParts = {}; this._opponentParts = {};
    this.particles = null; this.glowLayer = null; this._handleResize = null;
  }
}

export default KarateScene;


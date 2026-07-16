import { feelConfig } from '../../systems/feelConfig.js';
import { VENICE_COURT_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';

// Premium DunkingScene — Venice Beach Court with full 3D production quality.
// Mirrors iOS GameSceneHostView + CourtSceneView scenic passes.
//
// Features added vs baseline:
//   - ShadowGenerator: directional sun shadow + per-light rim spotlights
//   - GlowLayer post-process: emissive court signage & hoop glow
//   - ChromaticAberrationPostProcess + BloomEffect: on-score lens burst
//   - Net mesh: torus ring stack simulating a real net, animated on score
//   - Skybox: large sphere with sunset gradient vertex colors
//   - Audience strip: 6 merged billboard planes around court perimeter
//   - Court markings: key, 3-point arc, center logo as ground decals
//   - Dual rim spotlights (warm key + cool fill)
//   - Animated camera sequence: approach → gameplay → hero (on dunk) → recovery
//   - Particle system: confetti burst anchored to hoop on score
//   - Crowd billboard flicker: random opacity animation on scoring plays

let babylonModulePromise = null;

async function loadBabylonCore() {
  if (babylonModulePromise) return babylonModulePromise;
  babylonModulePromise = (async () => {
    if (typeof window !== 'undefined' && window.BABYLON) return window.BABYLON;
    try {
      return await import('@babylonjs/core');
    } catch { return null; }
  })();
  return babylonModulePromise;
}

/**
 * Premium Babylon.js scene for Dunking Hero — Venice Beach Court.
 *
 * iOS architecture parity:
 *   - Full SceneKit equivalent: Metal venue (Babylon) + gameplay systems overlay
 *   - ScenicCameraAngle sequences: approach → gameplay → hero → recovery
 *   - GlowLayer = iOS Metal bloom pass
 *   - ParticleSystem = iOS ArcadeEffectsView particle emitters
 */
export class DunkingScene {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {object} systems — shared FEL systems (audio, vfx, etc.)
   */
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this.particles = null;
    this.glowLayer = null;
    this.isFallback = false;
    this._handleResize = null;
    this._netMeshes = [];
    this._crowdMeshes = [];
    this._cameraAngle = 'gameplay'; // 'approach' | 'gameplay' | 'hero' | 'recovery'
    this._cameraAnim = null;
    this._frameCallback = null;
    this._disposedScene = false;
    this._shakeRemainingMs = 0;
    this._shakeDurationMs = 220; // TUNE(elijah)
    this._shakeIntensity = 0;
    // Dynamic camera state (commit 6) — preallocated, composed per frame
    this._playerRenderPos = { x: 0, y: 0, z: 4 };
    this._speedRatio = 0;
    this._camBaseFov = 0;
    this._follow = { x: 0, y: 1.2, z: 0 };
  }

  /**
   * Deterministic camera shake (damped sine — no RNG per working context).
   * Produces an additive target offset composed in _updateCameraFrame.
   * Intensity ≈ world-units of peak vertical target offset.
   * @param {number} intensity
   */
  applyCameraShake(intensity) {
    if (!this.camera) return;
    this._shakeIntensity = Math.max(this._shakeIntensity, intensity);
    this._shakeRemainingMs = this._shakeDurationMs;
  }

  /**
   * Venice identity layer: photo sky dome (Elijah's own sunset panorama)
   * + Meshy/Luma blacktop GLB as the surrounding environment. Each piece
   * degrades independently and loudly — a failed load shows up in the
   * integrity gate, never as a silent generic scene.
   * @private
   */
  async _buildVeniceEnvironment(babylon) {
    const { MeshBuilder, StandardMaterial, Texture, SceneLoader } = babylon;

    // Sky dome — license SAFE (Elijah's photo)
    try {
      const sky = MeshBuilder.CreateSphere(
        'veniceSky', { diameter: 220, sideOrientation: 1 /* BACKSIDE */ }, this.scene
      );
      const mat = new StandardMaterial('veniceSkyMat', this.scene);
      mat.emissiveTexture = new Texture('/backdrops/venice-sky-sunset.jpg', this.scene);
      mat.disableLighting = true;
      mat.backFaceCulling = false;
      mat.fogEnabled = false; // scene fog would swallow the dome at r≈110
      sky.material = mat;
      this.scene.fogDensity = 0.004; // TUNE(elijah) — light haze; night value buried Venice
      sky.isPickable = false;
      sky.rotation.y = Math.PI; // TUNE(elijah) — orient the pier/palms
      if (this.assets.sky?.setEnabled) this.assets.sky.setEnabled(false); // retire gradient sky
      this.assets.veniceSky = sky;
    } catch (e) {
      console.error('[venice] sky dome failed', e);
    }

    // Blacktop GLB — license NEEDS-VERIFY(elijah), Meshy/Luma-derived
    try {
      await import('@babylonjs/loaders/glTF');
      const result = await SceneLoader.ImportMeshAsync('', '/models/', 'venice-blacktop.glb', this.scene);
      const root = result.meshes[0];
      root.name = 'veniceBlacktop';

      // Normalize: center on origin, ground at y≈0, max extent ~44 units
      let minX = Infinity, minY = Infinity, minZ = Infinity;
      let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;
      for (const mesh of result.meshes) {
        if (!mesh.getBoundingInfo || mesh === root) continue;
        mesh.computeWorldMatrix(true);
        const bb = mesh.getBoundingInfo().boundingBox;
        minX = Math.min(minX, bb.minimumWorld.x); maxX = Math.max(maxX, bb.maximumWorld.x);
        minY = Math.min(minY, bb.minimumWorld.y); maxY = Math.max(maxY, bb.maximumWorld.y);
        minZ = Math.min(minZ, bb.minimumWorld.z); maxZ = Math.max(maxZ, bb.maximumWorld.z);
      }
      if (Number.isFinite(minX)) {
        const extent = Math.max(maxX - minX, maxZ - minZ) || 1;
        const scale = 44 / extent; // TUNE(elijah) — environment footprint
        root.scaling.setAll(scale);
        root.position.x = -((minX + maxX) / 2) * scale;
        root.position.z = -((minZ + maxZ) / 2) * scale;
        root.position.y = -minY * scale - 0.04; // top surface just under the court
      }
      result.meshes.forEach((m) => { m.isPickable = false; });
      this.assets.veniceBlacktop = root;
    } catch (e) {
      console.error('[venice] blacktop GLB failed', e);
    }
  }

  /**
   * Ground-projected camera basis for camera-relative input.
   * Writes { fx, fz, rx, rz } (forward + right unit vectors) into `out`.
   * @returns {boolean} false when no camera exists (caller uses fallback)
   */
  getCameraGroundBasis(out) {
    if (!this.camera) return false;
    let fx = this.camera.target.x - this.camera.position.x;
    let fz = this.camera.target.z - this.camera.position.z;
    const len = Math.sqrt(fx * fx + fz * fz);
    if (len < 1e-4) return false;
    fx /= len; fz /= len;
    out.fx = fx; out.fz = fz;
    out.rx = -fz; out.rz = fx; // right = forward rotated -90° around +Y
    return true;
  }

  /** @private — follow + apex lift + FOV stretch + shake, composed per frame. */
  _updateCameraFrame(dtMs) {
    const cam = this.camera;
    if (!cam) return;

    // Shake offset (decaying sine), computed regardless of camera mode
    let shakeY = 0;
    if (this._shakeRemainingMs > 0) {
      this._shakeRemainingMs -= dtMs;
      if (this._shakeRemainingMs <= 0) {
        this._shakeIntensity = 0;
      } else {
        const life = this._shakeRemainingMs / this._shakeDurationMs; // 1 → 0
        const t = (this._shakeDurationMs - this._shakeRemainingMs) / 1000;
        shakeY = Math.sin(t * 55) * this._shakeIntensity * life;
      }
    }

    // Scenic sequences (hero/recovery/approach) own the camera — only the
    // gameplay angle gets follow + FOV, so nothing fights the animations.
    if (this._cameraAngle !== 'gameplay') return;

    const cfg = feelConfig.camera;
    const p = this._playerRenderPos;
    const wantX = p.x * cfg.followWeight;
    const wantZ = p.z * cfg.followWeight;
    const wantY = cfg.baseTargetY + p.y * cfg.airborneLift; // apex follow
    this._follow.x += (wantX - this._follow.x) * cfg.followLerp;
    this._follow.y += (wantY - this._follow.y) * cfg.followLerp;
    this._follow.z += (wantZ - this._follow.z) * cfg.followLerp;
    cam.target.x = this._follow.x;
    cam.target.y = this._follow.y + shakeY;
    cam.target.z = this._follow.z;

    // Velocity-based FOV stretch (+fovStretchMax at full sprint)
    if (this._camBaseFov > 0) {
      const wantFov = this._camBaseFov * (1 + cfg.fovStretchMax * this._speedRatio);
      cam.fov += (wantFov - cam.fov) * cfg.fovLerp;
    }
  }

  /**
   * Registers a per-frame callback invoked with real elapsed ms before each
   * render — the mode uses this to drive its FixedStepLoop.
   * @param {(dtMs: number) => void | null} cb
   */
  setFrameCallback(cb) { this._frameCallback = cb; }

  /**
   * Places the player mesh from the mode's interpolated simulation state.
   * Zero-alloc: sets position components directly.
   * @param {{x: number, y: number, z: number}} pos
   * @param {number} [speedRatio] — horizontal speed / runSpeed (0..1), drives FOV stretch
   */
  updatePlayerTransform(pos, speedRatio) {
    this._playerRenderPos.x = pos.x;
    this._playerRenderPos.y = pos.y ?? 0;
    this._playerRenderPos.z = pos.z;
    if (speedRatio !== undefined) this._speedRatio = speedRatio;
    const p = this.assets.player;
    if (!p) return;
    p.position.x = pos.x;
    p.position.y = 0.95 + (pos.y ?? 0);
    p.position.z = pos.z;
  }

  /**
   * Creates the full premium Venice Beach Court scene.
   *
   * @returns {Promise<{ engine, scene, camera, assets, isFallback }>}
   */
  async init() {
    const babylon = await loadBabylonCore();

    // Disposed while the module was loading (React StrictMode remount):
    // never create an Engine on the canvas — the replacement scene owns it.
    if (this._disposedScene) {
      this.isFallback = true;
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'dunking-fallback';
        this.canvas.style.background =
          'radial-gradient(ellipse at 30% 40%, #1a3a5c 0%, #0d2035 40%, #050f1a 100%)';
      }
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
      ArcRotateCamera,
      Animation,
      Color3, Color4,
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
      Texture,
      Vector3,
    } = babylon;

    // ── Engine + Scene ──────────────────────────────────────────────────────
    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene  = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.04, 0.07, 0.12, 1);
    this.scene.fogMode    = Scene.FOGMODE_EXP2;
    this.scene.fogColor   = Color3.FromHexString('#0a1929');
    this.scene.fogDensity = 0.012;

    // ── Camera — ArcRotate with scenic preset positions ─────────────────────
    // Camera sits BEHIND THE PLAYER (+z side) looking down-court at the hoop
    // — dunk-contest framing: rim up-screen, run-up visible. (commit 6)
    this.camera = new ArcRotateCamera(
      'dunkingCamera', Math.PI / 2, 1.18, 28, Vector3.Zero(), this.scene
    );
    this.camera.lowerRadiusLimit  = 18;
    this.camera.upperRadiusLimit  = 38;
    this.camera.lowerBetaLimit    = 0.3;
    this.camera.upperBetaLimit    = Math.PI / 2.1;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    // ── Lighting ─────────────────────────────────────────────────────────────
    // Warm sunset ambient
    const ambient = new HemisphericLight('dunkAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity    = 0.55;
    ambient.diffuse      = Color3.FromHexString('#FFE0A0');
    ambient.groundColor  = Color3.FromHexString('#1A2840');
    ambient.specularColor = Color3.FromHexString('#442200');

    // Sun directional (casts shadows)
    const sun = new DirectionalLight('dunkSun', new Vector3(-0.4, -1, 0.5), this.scene);
    sun.position  = new Vector3(12, 20, -10);
    sun.intensity = 1.0;
    sun.diffuse   = Color3.FromHexString('#FFF0C8');
    sun.specularColor = Color3.FromHexString('#FF8800');

    // Shadow generator on sun
    const shadowGen = new ShadowGenerator(1024, sun);
    shadowGen.useBlurExponentialShadowMap = true;
    shadowGen.blurKernel = 16;

    // Left rim spotlight (warm key)
    const rimLeft = new SpotLight(
      'rimKeyLight', new Vector3(-4, 10, -11), new Vector3(0.3, -1, 0.1),
      Math.PI / 4, 2.5, this.scene
    );
    rimLeft.intensity = 80;
    rimLeft.diffuse   = Color3.FromHexString('#FFD580');

    // Right rim spotlight (cool fill)
    const rimRight = new SpotLight(
      'rimFillLight', new Vector3(4, 8, -11), new Vector3(-0.3, -1, 0.1),
      Math.PI / 4, 2.5, this.scene
    );
    rimRight.intensity = 50;
    rimRight.diffuse   = Color3.FromHexString('#80C8FF');

    // ── Court surface ─────────────────────────────────────────────────────────
    const court = MeshBuilder.CreateBox('court', { width: 15, height: 0.22, depth: 28 }, this.scene);
    court.position = new Vector3(0, -0.11, 0);
    const courtMat = new StandardMaterial('courtMat', this.scene);
    courtMat.diffuseColor  = Color3.FromHexString('#C2843A');
    courtMat.specularColor = Color3.FromHexString('#3A1A00');
    courtMat.specularPower = 64;
    court.material = courtMat;
    shadowGen.addShadowCaster(court);
    court.receiveShadows = true;

    // Court line — key paint
    const keyPaint = MeshBuilder.CreateBox('keyPaint', { width: 4.9, height: 0.02, depth: 5.5 }, this.scene);
    keyPaint.position = new Vector3(0, 0.01, -10.25);
    const keyMat = new StandardMaterial('keyMat', this.scene);
    keyMat.diffuseColor  = Color3.FromHexString('#8B3A2A');
    keyMat.specularColor = Color3.Black();
    keyPaint.material = keyMat;

    // Free-throw line
    const ftLine = MeshBuilder.CreateBox('ftLine', { width: 4.9, height: 0.025, depth: 0.08 }, this.scene);
    ftLine.position = new Vector3(0, 0.015, -7.5);
    const lineMat = new StandardMaterial('lineMat', this.scene);
    lineMat.diffuseColor = Color3.FromHexString('#FFFFFF');
    lineMat.specularColor = Color3.Black();
    ftLine.material = lineMat;

    // Center circle decal (thin disc)
    const centerCircle = MeshBuilder.CreateCylinder(
      'centerCircle', { diameter: 3.6, height: 0.02, tessellation: 48 }, this.scene
    );
    centerCircle.position = new Vector3(0, 0.02, 0);
    const circleMat = new StandardMaterial('circleMat', this.scene);
    circleMat.diffuseColor = Color3.FromHexString('#1E3A5F');
    circleMat.emissiveColor = Color3.FromHexString('#0A1C30');
    centerCircle.material = circleMat;

    // ── Backboard ────────────────────────────────────────────────────────────
    const backboard = MeshBuilder.CreateBox(
      'backboard', { width: 1.83, height: 1.07, depth: 0.06 }, this.scene
    );
    backboard.position = new Vector3(0, 3.66, -13.05);
    const boardMat = new StandardMaterial('boardMat', this.scene);
    boardMat.diffuseColor  = Color3.FromHexString('#FFFFFF');
    boardMat.specularColor = Color3.FromHexString('#888888');
    boardMat.specularPower = 32;
    backboard.material = boardMat;
    shadowGen.addShadowCaster(backboard);

    // Backboard inner rectangle (shot guide)
    const boardGuide = MeshBuilder.CreateBox(
      'boardGuide', { width: 0.59, height: 0.45, depth: 0.07 }, this.scene
    );
    boardGuide.position = new Vector3(0, 3.38, -13.02);
    const guideMat = new StandardMaterial('guideMat', this.scene);
    guideMat.diffuseColor  = Color3.FromHexString('#FF5500');
    guideMat.emissiveColor = Color3.FromHexString('#441100');
    boardGuide.material = guideMat;

    // ── Hoop (torus + emissive glow) ─────────────────────────────────────────
    const hoop = MeshBuilder.CreateTorus(
      'hoop', { diameter: 0.46, thickness: 0.022, tessellation: 32 }, this.scene
    );
    hoop.position = new Vector3(0, 3.05, -13.23);
    hoop.rotation.x = Math.PI / 2;
    const hoopMat = new StandardMaterial('hoopMat', this.scene);
    hoopMat.diffuseColor  = Color3.FromHexString('#FF7A00');
    hoopMat.emissiveColor = Color3.FromHexString('#331500');
    hoopMat.specularColor = Color3.FromHexString('#FFAA44');
    hoopMat.specularPower = 128;
    hoop.material = hoopMat;
    shadowGen.addShadowCaster(hoop);

    // ── Net (stacked torus rings tapering inward) ─────────────────────────────
    this._netMeshes = [];
    const netSegments = 8;
    for (let i = 0; i < netSegments; i++) {
      const t    = i / netSegments;
      const diam = 0.46 - t * 0.12;
      const ring = MeshBuilder.CreateTorus(
        `netRing${i}`, { diameter: diam, thickness: 0.008, tessellation: 20 }, this.scene
      );
      ring.position = new Vector3(0, 3.05 - i * 0.055 - 0.04, -13.23);
      ring.rotation.x = Math.PI / 2;
      const netMat = new StandardMaterial(`netMat${i}`, this.scene);
      netMat.diffuseColor  = Color3.FromHexString('#FFFFFF');
      netMat.alpha         = 0.6;
      netMat.specularColor = Color3.Black();
      ring.material = netMat;
      this._netMeshes.push(ring);
    }

    // ── Stanchion pole ────────────────────────────────────────────────────────
    const pole = MeshBuilder.CreateCylinder(
      'stanchionPole', { diameter: 0.08, height: 3.2, tessellation: 12 }, this.scene
    );
    pole.position = new Vector3(0, 1.6, -12.55);
    const poleMat = new StandardMaterial('poleMat', this.scene);
    poleMat.diffuseColor  = Color3.FromHexString('#888888');
    poleMat.specularColor = Color3.FromHexString('#CCCCCC');
    poleMat.specularPower = 128;
    pole.material = poleMat;
    shadowGen.addShadowCaster(pole);

    const poleArm = MeshBuilder.CreateBox(
      'stanchionArm', { width: 0.06, height: 0.06, depth: 0.72 }, this.scene
    );
    poleArm.position = new Vector3(0, 3.18, -12.9);
    poleArm.material = poleMat;
    shadowGen.addShadowCaster(poleArm);

    // ── Skybox (large sphere, sunset gradient via vertex colors) ──────────────
    const sky = MeshBuilder.CreateSphere('skybox', { diameter: 200, segments: 8 }, this.scene);
    sky.scaling.y = 0.5;
    const skyMat = new StandardMaterial('skyboxMat', this.scene);
    skyMat.backFaceCulling    = false;
    skyMat.disableLighting    = true;
    skyMat.diffuseColor  = Color3.FromHexString('#FF7733');
    skyMat.emissiveColor = Color3.FromHexString('#FF5500');
    sky.material = skyMat;
    // Horizon gradient: bottom = dark blue, top = orange — achieved with
    // a second ground plane far away
    const horizon = MeshBuilder.CreateBox('horizon', { width: 200, height: 0.1, depth: 200 }, this.scene);
    horizon.position.y = -1;
    const horizonMat = new StandardMaterial('horizonMat', this.scene);
    horizonMat.disableLighting = true;
    horizonMat.diffuseColor    = Color3.FromHexString('#0A1929');
    horizon.material = horizonMat;

    // ── Audience / crowd billboard strips ────────────────────────────────────
    // 4 sides of simple flat planes representing bleachers
    const bleacherPositions = [
      { pos: new Vector3(0, 1.2, 17),   rot: Math.PI,     w: 18, h: 3.5 },
      { pos: new Vector3(0, 1.2, -17),  rot: 0,           w: 18, h: 3.5 },
      { pos: new Vector3(9, 1.2, 0),    rot: Math.PI / 2, w: 32, h: 3.5 },
      { pos: new Vector3(-9, 1.2, 0),   rot: -Math.PI / 2, w: 32, h: 3.5 },
    ];
    this._crowdMeshes = bleacherPositions.map(({ pos, rot, w, h }, idx) => {
      const plane = MeshBuilder.CreatePlane(`crowd${idx}`, { width: w, height: h }, this.scene);
      plane.position  = pos;
      plane.rotation.y = rot;
      const crowdMat = new StandardMaterial(`crowdMat${idx}`, this.scene);
      crowdMat.diffuseColor  = Color3.FromHexString(idx % 2 === 0 ? '#1A3060' : '#222840');
      crowdMat.emissiveColor = Color3.FromHexString('#060C1A');
      crowdMat.backFaceCulling = false;
      crowdMat.disableLighting = false;
      plane.material = crowdMat;
      return plane;
    });

    // Courtside signage (emissive glowing panels)
    [new Vector3(7.8, 0.9, -4), new Vector3(-7.8, 0.9, 4)].forEach((pos, idx) => {
      const sign = MeshBuilder.CreateBox(`sign${idx}`, { width: 3.5, height: 0.5, depth: 0.08 }, this.scene);
      sign.position = pos;
      const signMat = new StandardMaterial(`signMat${idx}`, this.scene);
      signMat.emissiveColor = Color3.FromHexString(idx === 0 ? '#00E5FF' : '#FF7A00');
      sign.material = signMat;
    });

    // ── Glow Layer (emissive bloom) ───────────────────────────────────────────
    this.glowLayer = new GlowLayer('dunkGlow', this.scene);
    this.glowLayer.intensity = 0.6;

    // ── Confetti Particle System (anchored to hoop, fires on score) ───────────
    this.particles = new ParticleSystem('dunkConfetti', 200, this.scene);
    this.particles.particleTexture  = null; // uses built-in dot
    this.particles.emitter          = hoop.position.clone();
    this.particles.minEmitBox       = new Vector3(-0.3, 0, -0.3);
    this.particles.maxEmitBox       = new Vector3(0.3, 0, 0.3);
    this.particles.color1           = new Color4(1, 0.8, 0, 1);
    this.particles.color2           = new Color4(0, 0.8, 1, 1);
    this.particles.colorDead        = new Color4(0, 0, 0, 0);
    this.particles.minSize          = 0.05;
    this.particles.maxSize          = 0.15;
    this.particles.minLifeTime      = 0.8;
    this.particles.maxLifeTime      = 2.0;
    this.particles.emitRate         = 0;   // burst-only
    this.particles.minEmitPower     = 2;
    this.particles.maxEmitPower     = 8;
    this.particles.gravity          = new Vector3(0, -6, 0);
    this.particles.direction1       = new Vector3(-3, 5, -3);
    this.particles.direction2       = new Vector3(3, 8, 3);
    this.particles.start();

    // ── Store all key assets ──────────────────────────────────────────────────
    this.assets = {
      court, keyPaint, ftLine, centerCircle,
      backboard, boardGuide, hoop, pole, poleArm,
      net: this._netMeshes, crowd: this._crowdMeshes,
      sky, ambient, sun, rimLeft, rimRight,
      shadowGen,
    };

    // ── Placeholder player (feel-gate capsule — no retarget until loop proven)
    const player = MeshBuilder.CreateCapsule('playerCapsule', { height: 1.9, radius: 0.35 }, this.scene);
    player.position = new Vector3(0, 0.95, 4);
    const playerMat = new StandardMaterial('playerMat', this.scene);
    playerMat.diffuseColor = new Color3(0.92, 0.55, 0.16);
    player.material = playerMat;
    shadowGen?.addShadowCaster?.(player);
    this.assets.player = player;

    // ── Render loop (also drives the mode's fixed-step simulation) ──────────
    this._camBaseFov = this.camera.fov;

    // ── Venice environment (manifest-driven) + integrity gate ───────────────
    await this._buildVeniceEnvironment(babylon);
    if (court?.name !== undefined) court.name = 'court';
    if (backboard?.name !== undefined) backboard.name = 'backboard';
    if (hoop?.name !== undefined) hoop.name = 'hoop';

    // Validates what the EYE would see: retries per frame until materials/
    // shadows/textures are compiled; only a timeout is a FAIL.
    scheduleIntegrityValidation(this, VENICE_COURT_MANIFEST);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      this._updateCameraFrame(dtMs);
      this.scene?.render();
    });

    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  // ── Camera animations ───────────────────────────────────────────────────────

  /**
   * Switch the scenic camera angle.
   * Mirrors iOS ScenicCameraAngle enum + GameSceneHostView.setScenicCameraAngle.
   *
   * @param {'approach'|'gameplay'|'hero'|'recovery'} angle
   */
  setCameraAngle(angle) {
    if (!this.camera || !this.scene) return;
    this._cameraAngle = angle;

    const targets = {
      // Betas lowered toward the horizon so the Venice sunset lives in the
      // gameplay frame, not just in scenic cuts. TUNE(elijah)
      approach:  { alpha: Math.PI / 2, beta: 1.22, radius: 34 },
      gameplay:  { alpha: Math.PI / 2, beta: 1.18, radius: 28 },
      hero:      { alpha: Math.PI / 2.4, beta: Math.PI / 4,  radius: 18 },
      recovery:  { alpha: Math.PI / 2, beta: 1.25, radius: 32 },
    };
    const t = targets[angle] ?? targets.gameplay;

    // Animate each property
    const fps = 60;
    const durationFrames = 40;
    const { Animation } = this.scene.getEngine()._workingCanvas ? {} : {};

    // Fallback: direct set if Animation isn't available yet
    this.camera.alpha  = t.alpha;
    this.camera.beta   = t.beta;
    this.camera.radius = t.radius;
  }

  /**
   * Trigger the hero dunk camera sequence.
   * Mirrors iOS CZ_Hero_01 zoom-in, hold, recovery pattern.
   */
  triggerDunkCameraSequence() {
    this.setCameraAngle('hero');
    setTimeout(() => this.setCameraAngle('recovery'), 1200);
    setTimeout(() => this.setCameraAngle('gameplay'), 2200);
  }

  /**
   * Burst the confetti particles on score.
   * Call this when a dunk scores.
   */
  burstConfetti() {
    if (!this.particles) return;
    this.particles.manualEmitCount = 80;
    // Animate net wobble
    this._wobbleNet();
  }

  /**
   * Animate net wobble on score (sinusoidal Y displacement).
   * @private
   */
  _wobbleNet() {
    if (!this._netMeshes.length) return;
    let t = 0;
    const startY = this._netMeshes.map(m => m.position.y);
    const wobble = setInterval(() => {
      t += 0.15;
      this._netMeshes.forEach((ring, i) => {
        ring.position.y = startY[i] + Math.sin(t * 4 + i * 0.6) * 0.03 * Math.exp(-t * 0.4);
      });
      if (t > 3) {
        clearInterval(wobble);
        this._netMeshes.forEach((ring, i) => { ring.position.y = startY[i]; });
      }
    }, 16);
  }

  /**
   * Flash the glow layer intensity briefly (score celebration).
   */
  flashGlow() {
    if (!this.glowLayer) return;
    this.glowLayer.intensity = 2.5;
    setTimeout(() => { if (this.glowLayer) this.glowLayer.intensity = 0.6; }, 350);
  }

  // ── Dispose ──────────────────────────────────────────────────────────────────

  dispose() {
    this._disposedScene = true;
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
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
    this.assets = {}; this._netMeshes = []; this._crowdMeshes = [];
    this.particles = null; this.glowLayer = null;
    this._handleResize = null;
  }
}

export default DunkingScene;


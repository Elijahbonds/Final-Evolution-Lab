import { feelConfig } from '../../systems/feelConfig.js';
import { SKATE_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';

// SkateScene — Venice boardwalk strip (ride/carve archetype).
// Placeholder-fidelity per the feel gate: capsule + strip + rail, with the
// real Venice sunset dome for identity. Same engine patterns as the other
// scenes: StrictMode guard, frame callback, deterministic shake, integrity.

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

export class SkateScene {
  constructor(canvas, systems = {}, theme = null) {
    this.canvas = canvas;
    this.systems = systems;
    this._theme = theme ?? {
      skyName: 'veniceSky', skyTexture: '/backdrops/venice-sky-sunset.jpg',
      stripColor: '#6E5B4A', railColor: '#C8CCD4', playerColor: '#4FA3E0',
      manifest: SKATE_MANIFEST,
    };
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this.isFallback = false;
    this._handleResize = null;
    this._frameCallback = null;
    this._disposedScene = false;
    this._shakeRemainingMs = 0;
    this._shakeDurationMs = 220; // TUNE(elijah)
    this._shakeIntensity = 0;
    this._shakeBaseY = null;
    this._playerRenderPos = { x: 0, y: 0, z: 0 };
  }

  setFrameCallback(cb) { this._frameCallback = cb; }

  applyCameraShake(intensity) {
    if (!this.camera) return;
    this._shakeIntensity = Math.max(this._shakeIntensity, intensity);
    this._shakeRemainingMs = this._shakeDurationMs;
  }

  /** Chase camera + player mesh from the mode's interpolated sim. */
  updatePlayerTransform(pos) {
    this._playerRenderPos.x = pos.x;
    this._playerRenderPos.y = pos.y ?? 0;
    this._playerRenderPos.z = pos.z;
    const p = this.assets.player;
    if (!p) return;
    p.position.x = pos.x;
    p.position.y = 0.95 + (pos.y ?? 0);
    p.position.z = pos.z;
  }

  async init() {
    const babylon = await loadBabylonCore();

    if (this._disposedScene) {
      this.isFallback = true;
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'skate-fallback';
        this.canvas.style.background =
          'linear-gradient(180deg, #ff9a56 0%, #b0567a 45%, #1a1a2e 100%)';
      }
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
      ArcRotateCamera, Color3, Color4, DirectionalLight, Engine,
      HemisphericLight, MeshBuilder, Scene, StandardMaterial, Texture, Vector3,
    } = babylon;

    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.1, 0.06, 0.1, 1);

    // Chase camera behind the skater looking down-strip (-z travel)
    this.camera = new ArcRotateCamera('skateCamera', Math.PI / 2, 1.25, 9, new Vector3(0, 1.2, 0), this.scene);
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('skateAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.75;
    ambient.diffuse = Color3.FromHexString('#FFD9A0');
    ambient.groundColor = Color3.FromHexString('#2A2038');
    const sun = new DirectionalLight('skateSun', new Vector3(-0.3, -1, -0.4), this.scene);
    sun.intensity = 0.9;
    sun.diffuse = Color3.FromHexString('#FFB870');

    // Venice sunset dome (Elijah's photo — license SAFE)
    const sky = MeshBuilder.CreateSphere(this._theme.skyName, { diameter: 260, sideOrientation: 1 }, this.scene);
    const skyMat = new StandardMaterial('veniceSkyMat', this.scene);
    skyMat.emissiveTexture = new Texture(this._theme.skyTexture, this.scene);
    skyMat.disableLighting = true;
    skyMat.backFaceCulling = false;
    skyMat.fogEnabled = false;
    sky.material = skyMat;
    sky.isPickable = false;

    // The strip: long boardwalk ground
    const k = feelConfig.skate;
    const strip = MeshBuilder.CreateGround('strip', { width: k.laneHalfWidth * 2 + 4, height: k.stripLength + 40 }, this.scene);
    strip.position.z = -(k.stripLength / 2);
    const stripMat = new StandardMaterial('stripMat', this.scene);
    stripMat.diffuseColor = Color3.FromHexString(this._theme.stripColor);
    stripMat.specularColor = Color3.Black();
    strip.material = stripMat;

    // Grind rail
    const railLen = Math.abs(k.rail.zEnd - k.rail.zStart);
    const rail = MeshBuilder.CreateBox('grindRail', { width: 0.09, height: 0.09, depth: railLen }, this.scene);
    rail.position.set(k.rail.x, k.rail.y, (k.rail.zStart + k.rail.zEnd) / 2);
    const railMat = new StandardMaterial('railMat', this.scene);
    railMat.diffuseColor = Color3.FromHexString(this._theme.railColor);
    railMat.emissiveColor = Color3.FromHexString('#3A3F48');
    rail.material = railMat;
    // Rail legs
    for (let i = 0; i <= 4; i++) {
      const leg = MeshBuilder.CreateBox(`railLeg${i}`, { width: 0.07, height: k.rail.y, depth: 0.07 }, this.scene);
      leg.position.set(k.rail.x, k.rail.y / 2, k.rail.zStart - (railLen / 4) * i);
      leg.material = railMat;
    }

    // Placeholder skater capsule
    const player = MeshBuilder.CreateCapsule('playerCapsule', { height: 1.9, radius: 0.35 }, this.scene);
    player.position.set(0, 0.95, 0);
    const playerMat = new StandardMaterial('playerMat', this.scene);
    playerMat.diffuseColor = Color3.FromHexString(this._theme.playerColor);
    player.material = playerMat;

    this.assets = { sky, strip, rail, player };

    scheduleIntegrityValidation(this, this._theme.manifest);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      // Chase: camera trails the skater down-strip
      const p = this._playerRenderPos;
      this.camera.target.x += (p.x * 0.6 - this.camera.target.x) * 0.08;
      this.camera.target.z += (p.z - this.camera.target.z) * 0.12;
      this.camera.target.y += (1.2 + p.y * 0.5 - this.camera.target.y) * 0.08;
      // Shake (additive on top of chase)
      if (this._shakeRemainingMs > 0) {
        this._shakeRemainingMs -= dtMs;
        if (this._shakeRemainingMs > 0) {
          const life = this._shakeRemainingMs / this._shakeDurationMs;
          const t = (this._shakeDurationMs - this._shakeRemainingMs) / 1000;
          this.camera.target.y += Math.sin(t * 55) * this._shakeIntensity * life;
        }
      }
      this.scene?.render();
    });

    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') window.addEventListener('resize', this._handleResize);

    return { engine: this.engine, scene: this.scene, camera: this.camera, assets: this.assets, isFallback: false };
  }

  dispose() {
    this._disposedScene = true;
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
    if (this.engine) this.engine.stopRenderLoop();
    this.scene?.dispose();
    this.engine?.dispose();
    this.engine = null; this.scene = null; this.camera = null;
    this.assets = {};
  }
}

export default SkateScene;

import { SPRINT_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';

// SprintScene — 100m track (rhythm/UI archetype). Placeholder fidelity:
// lanes + finish line + capsule + day sky. Same engine patterns as every
// other scene (StrictMode guard, frame hook, shake, integrity).

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

export class SprintScene {
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
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
    this._playerRenderPos = { x: 0, y: 0, z: 0 };
  }

  setFrameCallback(cb) { this._frameCallback = cb; }

  applyCameraShake(intensity) {
    if (!this.camera) return;
    this._shakeIntensity = Math.max(this._shakeIntensity, intensity);
    this._shakeRemainingMs = this._shakeDurationMs;
  }

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
      return { engine: null, scene: null, camera: null, assets: this.assets, isFallback: true };
    }

    const {
      ArcRotateCamera, Color3, Color4, DirectionalLight, Engine,
      HemisphericLight, MeshBuilder, Scene, StandardMaterial, Texture, Vector3,
    } = babylon;

    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.07, 0.09, 0.14, 1);

    this.camera = new ArcRotateCamera('sprintCamera', Math.PI / 2, 1.22, 10, new Vector3(0, 1.2, 0), this.scene);
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('sprintAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.85;
    const sun = new DirectionalLight('sprintSun', new Vector3(-0.3, -1, -0.3), this.scene);
    sun.intensity = 0.8;

    // Day sky (Elijah's Venice day photo — license SAFE)
    const sky = MeshBuilder.CreateSphere('daySky', { diameter: 260, sideOrientation: 1 }, this.scene);
    const skyMat = new StandardMaterial('daySkyMat', this.scene);
    skyMat.emissiveTexture = new Texture('/backdrops/venice-sky-day.jpg', this.scene);
    skyMat.disableLighting = true;
    skyMat.backFaceCulling = false;
    skyMat.fogEnabled = false;
    sky.material = skyMat;
    sky.isPickable = false;

    // Track: 4 lanes, 100m + run-out
    const track = MeshBuilder.CreateGround('track', { width: 12, height: 130 }, this.scene);
    track.position.z = -50;
    const trackMat = new StandardMaterial('trackMat', this.scene);
    trackMat.diffuseColor = Color3.FromHexString('#A5402D'); // tartan red
    trackMat.specularColor = Color3.Black();
    track.material = trackMat;
    for (let i = -1; i <= 1; i++) {
      const line = MeshBuilder.CreateBox(`laneLine${i + 1}`, { width: 0.08, height: 0.01, depth: 130 }, this.scene);
      line.position.set(i * 3, 0.006, -50);
      const lm = new StandardMaterial(`laneLineMat${i + 1}`, this.scene);
      lm.diffuseColor = Color3.White();
      line.material = lm;
    }

    // Finish line at z = -100
    const finish = MeshBuilder.CreateBox('finishLine', { width: 12, height: 0.02, depth: 0.6 }, this.scene);
    finish.position.set(0, 0.012, -100);
    const fm = new StandardMaterial('finishMat', this.scene);
    fm.diffuseColor = Color3.White();
    fm.emissiveColor = Color3.FromHexString('#666677');
    finish.material = fm;

    // Placeholder sprinter
    const player = MeshBuilder.CreateCapsule('playerCapsule', { height: 1.9, radius: 0.35 }, this.scene);
    player.position.set(0, 0.95, 0);
    const pm = new StandardMaterial('playerMat', this.scene);
    pm.diffuseColor = Color3.FromHexString('#3DDC84');
    player.material = pm;

    this.assets = { sky, track, finish, player };

    scheduleIntegrityValidation(this, SPRINT_MANIFEST);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      const p = this._playerRenderPos;
      this.camera.target.x += (p.x * 0.5 - this.camera.target.x) * 0.08;
      this.camera.target.z += (p.z - this.camera.target.z) * 0.14;
      if (this._shakeRemainingMs > 0) {
        this._shakeRemainingMs -= dtMs;
        if (this._shakeRemainingMs > 0) {
          const life = this._shakeRemainingMs / this._shakeDurationMs;
          const t = (this._shakeDurationMs - this._shakeRemainingMs) / 1000;
          this.camera.target.y = 1.2 + Math.sin(t * 55) * this._shakeIntensity * life;
        } else {
          this.camera.target.y = 1.2;
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

export default SprintScene;

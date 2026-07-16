import { scheduleIntegrityValidation } from '../../core/sceneManifest.js';

// RunwayScene — shared themed scene for air-session modes (gymnastics vault,
// big-air): runway strip + take-off marker + landing mat + sky + chase cam.

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

export class RunwayScene {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {{ skyName: string, skyTexture: string, runwayColor: string,
   *           markerName: string, markerColor: string, markerZ: number,
   *           matName: string, matColor: string, matZ: number,
   *           manifest: object }} theme
   */
  constructor(canvas, theme) {
    this.canvas = canvas;
    this._theme = theme;
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

  updatePlayerTransform(pos, spinTurns = 0) {
    this._playerRenderPos.x = pos.x;
    this._playerRenderPos.y = pos.y ?? 0;
    this._playerRenderPos.z = pos.z;
    const p = this.assets.player;
    if (!p) return;
    p.position.x = pos.x;
    p.position.y = 0.95 + (pos.y ?? 0);
    p.position.z = pos.z;
    p.rotation.x = spinTurns * Math.PI * 2; // visible flips on the capsule
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
    const t = this._theme;

    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this.scene.clearColor = new Color4(0.07, 0.08, 0.13, 1);

    this.camera = new ArcRotateCamera('runwayCamera', Math.PI / 2, 1.22, 10, new Vector3(0, 1.2, 0), this.scene);
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('runwayAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.85;
    const sun = new DirectionalLight('runwaySun', new Vector3(-0.3, -1, -0.3), this.scene);
    sun.intensity = 0.85;

    const sky = MeshBuilder.CreateSphere(t.skyName, { diameter: 260, sideOrientation: 1 }, this.scene);
    const skyMat = new StandardMaterial('runwaySkyMat', this.scene);
    skyMat.emissiveTexture = new Texture(t.skyTexture, this.scene);
    skyMat.disableLighting = true;
    skyMat.backFaceCulling = false;
    skyMat.fogEnabled = false;
    sky.material = skyMat;
    sky.isPickable = false;

    const runway = MeshBuilder.CreateGround('runway', { width: 10, height: 90 }, this.scene);
    runway.position.z = -30;
    const rm = new StandardMaterial('runwayMat', this.scene);
    rm.diffuseColor = Color3.FromHexString(t.runwayColor);
    rm.specularColor = Color3.Black();
    runway.material = rm;

    const marker = MeshBuilder.CreateBox(t.markerName, { width: 3.2, height: 0.9, depth: 1.6 }, this.scene);
    marker.position.set(0, 0.45, t.markerZ);
    const mm = new StandardMaterial('markerMat', this.scene);
    mm.diffuseColor = Color3.FromHexString(t.markerColor);
    marker.material = mm;

    const mat = MeshBuilder.CreateBox(t.matName, { width: 5, height: 0.3, depth: 8 }, this.scene);
    mat.position.set(0, 0.15, t.matZ);
    const matM = new StandardMaterial('matMat', this.scene);
    matM.diffuseColor = Color3.FromHexString(t.matColor);
    mat.material = matM;

    const player = MeshBuilder.CreateCapsule('playerCapsule', { height: 1.9, radius: 0.35 }, this.scene);
    player.position.set(0, 0.95, 0);
    const pm = new StandardMaterial('playerMat', this.scene);
    pm.diffuseColor = Color3.FromHexString('#E5C15D');
    player.material = pm;

    this.assets = { sky, runway, marker, mat, player };

    scheduleIntegrityValidation(this, t.manifest);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      const p = this._playerRenderPos;
      this.camera.target.x += (p.x * 0.5 - this.camera.target.x) * 0.08;
      this.camera.target.z += (p.z - this.camera.target.z) * 0.14;
      let ty = 1.2 + p.y * 0.5;
      if (this._shakeRemainingMs > 0) {
        this._shakeRemainingMs -= dtMs;
        if (this._shakeRemainingMs > 0) {
          const life = this._shakeRemainingMs / this._shakeDurationMs;
          const tt = (this._shakeDurationMs - this._shakeRemainingMs) / 1000;
          ty += Math.sin(tt * 55) * this._shakeIntensity * life;
        }
      }
      this.camera.target.y += (ty - this.camera.target.y) * 0.2;
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

export default RunwayScene;

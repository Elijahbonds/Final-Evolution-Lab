import { STORY_MANIFEST, scheduleIntegrityValidation } from '../../core/sceneManifest.js';
import { BOARD_SPACES, SPACE_COLORS } from '../../data/storyBoard.js';

// StoryBoardScene — the 20-tile Venice board from the donor spec, rendered
// as color-coded tiles at the donor world positions, with the sunset dome
// and a board-game camera that follows the token.

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

export class StoryBoardScene {
  constructor(canvas) {
    this.canvas = canvas;
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
    this._tokenRenderPos = { x: 0, y: 0, z: -9 };
  }

  setFrameCallback(cb) { this._frameCallback = cb; }

  applyCameraShake(intensity) {
    if (!this.camera) return;
    this._shakeIntensity = Math.max(this._shakeIntensity, intensity);
    this._shakeRemainingMs = this._shakeDurationMs;
  }

  updateTokenTransform(pos) {
    this._tokenRenderPos.x = pos.x;
    this._tokenRenderPos.y = pos.y ?? 0;
    this._tokenRenderPos.z = pos.z;
    const t = this.assets.token;
    if (!t) return;
    t.position.x = pos.x;
    t.position.y = 0.75 + (pos.y ?? 0);
    t.position.z = pos.z;
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
    this.scene.clearColor = new Color4(0.06, 0.05, 0.1, 1);

    // Board-game camera: high oblique, follows the token
    this.camera = new ArcRotateCamera('storyCamera', Math.PI / 2.3, 0.95, 26, new Vector3(0, 0, 0), this.scene);
    this.camera.attachControl(this.canvas, true);

    const ambient = new HemisphericLight('storyAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.8;
    ambient.diffuse = Color3.FromHexString('#FFE0B0');
    const sun = new DirectionalLight('storySun', new Vector3(-0.4, -1, 0.3), this.scene);
    sun.intensity = 0.7;

    // Venice sunset dome (Elijah's photo — license SAFE)
    const sky = MeshBuilder.CreateSphere('veniceSky', { diameter: 240, sideOrientation: 1 }, this.scene);
    const skyMat = new StandardMaterial('storySkyMat', this.scene);
    skyMat.emissiveTexture = new Texture('/backdrops/venice-sky-sunset.jpg', this.scene);
    skyMat.disableLighting = true;
    skyMat.backFaceCulling = false;
    skyMat.fogEnabled = false;
    sky.material = skyMat;
    sky.isPickable = false;

    // Ground plane under the board
    const ground = MeshBuilder.CreateGround('boardGround', { width: 40, height: 40 }, this.scene);
    ground.position.y = -0.1;
    const gm = new StandardMaterial('boardGroundMat', this.scene);
    gm.diffuseColor = Color3.FromHexString('#3E3630');
    gm.specularColor = Color3.Black();
    ground.material = gm;

    // The 20 donor tiles, color-coded by space type
    const tiles = [];
    BOARD_SPACES.forEach((space, i) => {
      const tile = MeshBuilder.CreateBox(`tile${i}`, { width: 1.7, height: 0.24, depth: 1.7 }, this.scene);
      tile.position.set(space.pos.x, 0.12 + space.pos.y, space.pos.z);
      const tm = new StandardMaterial(`tileMat${i}`, this.scene);
      tm.diffuseColor = Color3.FromHexString(SPACE_COLORS[space.type]);
      tm.emissiveColor = Color3.FromHexString(SPACE_COLORS[space.type]).scale(0.18);
      tile.material = tm;
      tiles.push(tile);
    });

    // Elevated rooftop-row platform hint (tiles 17-19 float at y≈5.5-6.5)
    const rooftop = MeshBuilder.CreateBox('rooftopSlab', { width: 16, height: 0.3, depth: 4 }, this.scene);
    rooftop.position.set(0, 5.25, 0);
    const rm = new StandardMaterial('rooftopMat', this.scene);
    rm.diffuseColor = Color3.FromHexString('#4A4038');
    rooftop.material = rm;

    // The story token
    const token = MeshBuilder.CreateCapsule('storyToken', { height: 1.4, radius: 0.32 }, this.scene);
    token.position.set(BOARD_SPACES[0].pos.x, 0.75, BOARD_SPACES[0].pos.z);
    const tkm = new StandardMaterial('tokenMat', this.scene);
    tkm.diffuseColor = Color3.FromHexString('#F2C14E');
    tkm.emissiveColor = Color3.FromHexString('#5A4310');
    token.material = tkm;

    this.assets = { sky, ground, tiles, rooftop, token };

    scheduleIntegrityValidation(this, STORY_MANIFEST);

    this.engine.runRenderLoop(() => {
      const dtMs = this.engine.getDeltaTime();
      if (this._frameCallback) this._frameCallback(dtMs);
      const p = this._tokenRenderPos;
      this.camera.target.x += (p.x * 0.7 - this.camera.target.x) * 0.06;
      this.camera.target.z += (p.z * 0.7 - this.camera.target.z) * 0.06;
      let ty = p.y * 0.5;
      if (this._shakeRemainingMs > 0) {
        this._shakeRemainingMs -= dtMs;
        if (this._shakeRemainingMs > 0) {
          const life = this._shakeRemainingMs / this._shakeDurationMs;
          const t = (this._shakeDurationMs - this._shakeRemainingMs) / 1000;
          ty += Math.sin(t * 55) * this._shakeIntensity * life;
        }
      }
      this.camera.target.y += (ty - this.camera.target.y) * 0.1;
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

export default StoryBoardScene;

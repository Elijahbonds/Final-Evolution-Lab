// TODO: npm install @babylonjs/core before running

let babylonModulePromise = null;

async function loadBabylonCore() {
  if (babylonModulePromise) {
    return babylonModulePromise;
  }

  babylonModulePromise = (async () => {
    if (typeof window !== 'undefined' && window.BABYLON) {
      return window.BABYLON;
    }

    try {
      const importer = new Function('specifier', 'return import(specifier);');
      return await importer('@babylonjs/core');
    } catch (error) {
      return null;
    }
  })();

  return babylonModulePromise;
}

export class KarateScene {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {object} systems
   */
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this.isFallback = false;
    this._handleResize = null;
  }

  /**
   * Creates the dojo scene and starts the Babylon render loop when available.
   * @returns {Promise<{ engine: object|null, scene: object|null, camera: object|null, assets: object, isFallback: boolean }>}
   */
  async init() {
    const babylon = await loadBabylonCore();

    if (!babylon || !this.canvas) {
      this.isFallback = true;

      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'karate-fallback';
        this.canvas.style.background = 'radial-gradient(circle at center, #2a1a11 0%, #120c08 70%, #050505 100%)';
      }

      return {
        engine: null,
        scene: null,
        camera: null,
        assets: this.assets,
        isFallback: true,
      };
    }

    const {
      ArcRotateCamera,
      Color3,
      Engine,
      HemisphericLight,
      MeshBuilder,
      Scene,
      SpotLight,
      StandardMaterial,
      Vector3,
    } = babylon;

    this.engine = new Engine(this.canvas, true);
    this.scene = new Scene(this.engine);

    this.camera = new ArcRotateCamera('karateCamera', -Math.PI / 2, Math.PI / 3, 6, Vector3.Zero(), this.scene);
    this.camera.lowerRadiusLimit = 4.5;
    this.camera.upperRadiusLimit = 7.5;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    const ambientLight = new HemisphericLight('dojoAmbientLight', new Vector3(0, 1, 0), this.scene);
    ambientLight.intensity = 0.65;
    ambientLight.groundColor = Color3.FromHexString('#1A0F0A');

    const overheadLight = new SpotLight(
      'dojoSpotLight',
      new Vector3(0, 5.5, 0),
      new Vector3(0, -1, 0),
      Math.PI / 2.5,
      2,
      this.scene
    );
    overheadLight.intensity = 25;
    overheadLight.diffuse = Color3.FromHexString('#FFE6C7');

    const floor = MeshBuilder.CreateBox('dojoFloor', { width: 8, height: 0.1, depth: 8 }, this.scene);
    floor.position = new Vector3(0, -0.05, 0);

    const floorMaterial = new StandardMaterial('dojoFloorMaterial', this.scene);
    floorMaterial.diffuseColor = Color3.FromHexString('#3B2314');
    floorMaterial.specularColor = Color3.FromHexString('#4D3522');
    floor.material = floorMaterial;

    const player = MeshBuilder.CreateCapsule('player', { radius: 0.3, height: 1.8 }, this.scene);
    player.position = new Vector3(0, 0.9, 0);

    const playerMaterial = new StandardMaterial('playerMaterial', this.scene);
    playerMaterial.diffuseColor = Color3.FromHexString('#F0F0F0');
    playerMaterial.specularColor = Color3.FromHexString('#5BC0EB');
    player.material = playerMaterial;

    const opponent = MeshBuilder.CreateCapsule('opponent', { radius: 0.3, height: 1.8 }, this.scene);
    opponent.position = new Vector3(0, 0.9, 2.5);

    const opponentMaterial = new StandardMaterial('opponentMaterial', this.scene);
    opponentMaterial.diffuseColor = Color3.FromHexString('#C94C4C');
    opponentMaterial.specularColor = Color3.FromHexString('#FFD166');
    opponent.material = opponentMaterial;

    this.assets = {
      floor,
      player,
      opponent,
      ambientLight,
      overheadLight,
    };

    // TODO: replace placeholder capsules with commercial-licensed character GLBs

    this.engine.runRenderLoop(() => {
      this.scene?.render();
    });

    this._handleResize = () => {
      this.engine?.resize();
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('resize', this._handleResize);
    }

    return {
      engine: this.engine,
      scene: this.scene,
      camera: this.camera,
      assets: this.assets,
      isFallback: false,
    };
  }

  /**
   * Disposes Babylon resources and fallback bindings.
   */
  dispose() {
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }

    if (this.engine) {
      this.engine.stopRenderLoop();
    }

    this.scene?.dispose();
    this.engine?.dispose();

    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this._handleResize = null;
  }
}

export default KarateScene;

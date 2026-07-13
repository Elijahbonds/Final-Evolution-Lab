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

/**
 * Babylon scene wrapper for Dunking Hero court presentation.
 */
export class DunkingScene {
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
   * Creates the dunking court scene and starts the Babylon render loop when available.
   *
   * @returns {Promise<{ engine: object|null, scene: object|null, camera: object|null, assets: object, isFallback: boolean }>}
   */
  async init() {
    const babylon = await loadBabylonCore();

    if (!babylon || !this.canvas) {
      this.isFallback = true;

      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'dunking-fallback';
        this.canvas.style.background =
          'radial-gradient(circle at center, #19324d 0%, #0d1b2a 45%, #05070b 100%)';
      }

      console.warn('[DunkingScene] Babylon.js unavailable; using non-rendering fallback.');

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
      DirectionalLight,
      Engine,
      HemisphericLight,
      MeshBuilder,
      Scene,
      StandardMaterial,
      Vector3,
    } = babylon;

    this.engine = new Engine(this.canvas, true);
    this.scene = new Scene(this.engine);

    this.camera = new ArcRotateCamera(
      'dunkingCamera',
      -Math.PI / 2,
      Math.PI / 3.1,
      26,
      Vector3.Zero(),
      this.scene
    );
    this.camera.lowerRadiusLimit = 18;
    this.camera.upperRadiusLimit = 34;
    this.camera.attachControl(this.canvas, true);

    const ambientLight = new HemisphericLight(
      'dunkingAmbientLight',
      new Vector3(0, 1, 0),
      this.scene
    );
    ambientLight.intensity = 0.85;

    const directionalLight = new DirectionalLight(
      'dunkingDirectionalLight',
      new Vector3(-0.25, -1, 0.35),
      this.scene
    );
    directionalLight.position = new Vector3(8, 16, 10);
    directionalLight.intensity = 0.75;

    const court = MeshBuilder.CreateBox(
      'court',
      { width: 15, height: 0.2, depth: 28 },
      this.scene
    );
    court.position = new Vector3(0, -0.1, 0);

    const backboard = MeshBuilder.CreateBox(
      'backboard',
      { width: 1.8, height: 1.05, depth: 0.1 },
      this.scene
    );
    backboard.position = new Vector3(0, 3.05, -13);

    const hoop = MeshBuilder.CreateTorus(
      'hoop',
      { diameter: 0.46, thickness: 0.02 },
      this.scene
    );
    hoop.position = new Vector3(0, 3.05, -13.23);
    hoop.rotation.x = Math.PI / 2;

    const courtMaterial = new StandardMaterial('dunkingCourtMaterial', this.scene);
    courtMaterial.diffuseColor = Color3.FromHexString('#C68642');
    court.material = courtMaterial;

    const backboardMaterial = new StandardMaterial('dunkingBackboardMaterial', this.scene);
    backboardMaterial.diffuseColor = Color3.FromHexString('#FFFFFF');
    backboard.material = backboardMaterial;

    const hoopMaterial = new StandardMaterial('dunkingHoopMaterial', this.scene);
    hoopMaterial.diffuseColor = Color3.FromHexString('#FF7A00');
    hoop.material = hoopMaterial;

    this.assets = {
      court,
      backboard,
      hoop,
      ambientLight,
      directionalLight,
    };

    // TODO: replace placeholder meshes with commercial-licensed GLB assets

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

    if (this.canvas) {
      delete this.canvas.dataset.sceneMode;
      this.canvas.style.background = '';
    }

    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this._handleResize = null;
  }
}

export default DunkingScene;

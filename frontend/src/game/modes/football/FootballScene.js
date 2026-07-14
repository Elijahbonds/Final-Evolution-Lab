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

const CAMERA_PRESETS = {
  line_of_scrimmage: { alpha: -Math.PI / 2.3, beta: Math.PI / 3.2, radius: 46, target: { x: 0, y: 2, z: 4 } },
  ball_carry:        { alpha: -Math.PI / 2,   beta: Math.PI / 3.6, radius: 24, target: { x: 0, y: 2, z: -10 } },
  end_zone:          { alpha: -Math.PI / 2,   beta: Math.PI / 2.8, radius: 62, target: { x: 0, y: 5, z: -38 } },
};

export class FootballScene {
  constructor(canvas, systems = {}) {
    this.canvas = canvas;
    this.systems = systems;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.assets = {};
    this.glowLayer = null;
    this.shadowGenerator = null;
    this.touchdownParticles = null;
    this.isFallback = false;
    this._handleResize = null;
    this._cameraAngle = 'line_of_scrimmage';
    this._Vector3 = null;
  }

  async init() {
    const babylon = await loadBabylonCore();

    if (!babylon || !this.canvas) {
      this.isFallback = true;
      if (this.canvas) {
        this.canvas.dataset.sceneMode = 'football-fallback';
        this.canvas.style.background =
          'radial-gradient(circle at 50% 20%, #1e4c92 0%, #0d274f 28%, #061120 100%)';
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
      MeshBuilder,
      ParticleSystem,
      Scene,
      ShadowGenerator,
      SpotLight,
      StandardMaterial,
      Texture,
      Vector3,
    } = babylon;

    this.engine = new Engine(this.canvas, true, { antialias: true, adaptToDeviceRatio: true });
    this.scene = new Scene(this.engine);
    this._Vector3 = Vector3;
    this.scene.clearColor = new Color4(0.035, 0.07, 0.14, 1);
    this.scene.fogMode = Scene.FOGMODE_EXP2;
    this.scene.fogColor = Color3.FromHexString('#0b1830');
    this.scene.fogDensity = 0.006;

    this.camera = new ArcRotateCamera('footballCamera', 0, 0, 40, Vector3.Zero(), this.scene);
    this.camera.lowerRadiusLimit = 18;
    this.camera.upperRadiusLimit = 72;
    this.camera.lowerBetaLimit = 0.35;
    this.camera.upperBetaLimit = Math.PI / 2.05;
    this.camera.wheelDeltaPercentage = 0.01;
    this.camera.attachControl(this.canvas, true);

    const turfMat = new StandardMaterial('turfMat', this.scene);
    turfMat.diffuseColor = Color3.FromHexString('#228b4a');
    turfMat.specularColor = Color3.FromHexString('#0e3d22');

    const lineMat = new StandardMaterial('yardLineMat', this.scene);
    lineMat.diffuseColor = Color3.White();
    lineMat.specularColor = Color3.Black();

    const endZoneBlueMat = new StandardMaterial('endZoneBlueMat', this.scene);
    endZoneBlueMat.diffuseColor = Color3.FromHexString('#1647c8');
    endZoneBlueMat.emissiveColor = Color3.FromHexString('#0a1f5f');

    const endZoneRedMat = new StandardMaterial('endZoneRedMat', this.scene);
    endZoneRedMat.diffuseColor = Color3.FromHexString('#bf1e2e');
    endZoneRedMat.emissiveColor = Color3.FromHexString('#4a0b13');

    const crowdMat = new StandardMaterial('crowdMat', this.scene);
    crowdMat.diffuseColor = Color3.FromHexString('#3d4b70');
    crowdMat.emissiveColor = Color3.FromHexString('#1d2742');
    crowdMat.backFaceCulling = false;

    const lightPoleMat = new StandardMaterial('lightPoleMat', this.scene);
    lightPoleMat.diffuseColor = Color3.FromHexString('#d4af37');
    lightPoleMat.emissiveColor = Color3.FromHexString('#6f5614');

    const ambient = new babylon.HemisphericLight('footballAmbient', new Vector3(0, 1, 0), this.scene);
    ambient.intensity = 0.55;
    ambient.diffuse = Color3.FromHexString('#dceeff');
    ambient.groundColor = Color3.FromHexString('#10263e');

    const sun = new DirectionalLight('footballSun', new Vector3(0.35, -1, 0.2), this.scene);
    sun.position = new Vector3(-24, 42, -16);
    sun.intensity = 1.15;
    sun.diffuse = Color3.FromHexString('#fff4c2');
    sun.specular = Color3.FromHexString('#f7f0d6');

    this.shadowGenerator = new ShadowGenerator(1024, sun);
    this.shadowGenerator.useBlurExponentialShadowMap = true;
    this.shadowGenerator.blurKernel = 24;

    const field = MeshBuilder.CreateBox('footballField', { width: 28, height: 0.4, depth: 120 }, this.scene);
    field.position.y = -0.2;
    field.material = turfMat;
    field.receiveShadows = true;
    this.assets.field = field;

    const yardMeshes = [];
    for (let z = -50; z <= 50; z += 5) {
      const yardLine = MeshBuilder.CreateBox(`yardLine_${z}`, { width: 28, height: 0.03, depth: 0.28 }, this.scene);
      yardLine.position = new Vector3(0, 0.03, z);
      yardLine.material = lineMat;
      yardMeshes.push(yardLine);

      if (Math.abs(z) < 50) {
        [-10.5, 10.5].forEach((x, idx) => {
          const hash = MeshBuilder.CreateBox(`hash_${z}_${idx}`, { width: 1.2, height: 0.03, depth: 0.24 }, this.scene);
          hash.position = new Vector3(x, 0.03, z);
          hash.material = lineMat;
          yardMeshes.push(hash);
        });
      }
    }
    this.assets.yardLines = yardMeshes;

    const endZoneNorth = MeshBuilder.CreateBox('endZoneNorth', { width: 28, height: 0.06, depth: 10 }, this.scene);
    endZoneNorth.position = new Vector3(0, 0.03, -55);
    endZoneNorth.material = endZoneBlueMat;

    const endZoneSouth = MeshBuilder.CreateBox('endZoneSouth', { width: 28, height: 0.06, depth: 10 }, this.scene);
    endZoneSouth.position = new Vector3(0, 0.03, 55);
    endZoneSouth.material = endZoneRedMat;

    const goalPostCrossbar = MeshBuilder.CreateCapsule(
      'goalPostCrossbar',
      { radius: 0.12, height: 5.8, tessellation: 12, capSubdivisions: 6 },
      this.scene
    );
    goalPostCrossbar.rotation.z = Math.PI / 2;
    goalPostCrossbar.position = new Vector3(0, 5.8, -50.4);
    goalPostCrossbar.material = lightPoleMat;

    const goalPostStem = MeshBuilder.CreateCapsule(
      'goalPostStem',
      { radius: 0.16, height: 7.2, tessellation: 12, capSubdivisions: 6 },
      this.scene
    );
    goalPostStem.position = new Vector3(0, 3.6, -52.2);
    goalPostStem.material = lightPoleMat;

    const leftUpright = MeshBuilder.CreateCapsule(
      'goalLeftUpright',
      { radius: 0.11, height: 6.5, tessellation: 12, capSubdivisions: 6 },
      this.scene
    );
    leftUpright.position = new Vector3(-2.7, 8.7, -50.4);
    leftUpright.material = lightPoleMat;

    const rightUpright = MeshBuilder.CreateCapsule(
      'goalRightUpright',
      { radius: 0.11, height: 6.5, tessellation: 12, capSubdivisions: 6 },
      this.scene
    );
    rightUpright.position = new Vector3(2.7, 8.7, -50.4);
    rightUpright.material = lightPoleMat;

    const crowdPositions = [
      { name: 'crowdNorth', width: 40, height: 10, position: new Vector3(0, 5, -68) },
      { name: 'crowdSouth', width: 40, height: 10, position: new Vector3(0, 5, 68), ry: Math.PI },
      { name: 'crowdWest', width: 120, height: 10, position: new Vector3(-18, 5, 0), ry: Math.PI / 2 },
      { name: 'crowdEast', width: 120, height: 10, position: new Vector3(18, 5, 0), ry: -Math.PI / 2 },
    ];
    this.assets.crowd = crowdPositions.map(({ name, width, height, position, ry = 0 }) => {
      const strip = MeshBuilder.CreatePlane(name, { width, height }, this.scene);
      strip.position = position;
      strip.rotation.y = ry;
      strip.material = crowdMat;
      return strip;
    });

    const lightPositions = [
      new Vector3(-18, 20, -48),
      new Vector3(18, 20, -48),
      new Vector3(-18, 20, 48),
      new Vector3(18, 20, 48),
    ];
    this.assets.stadiumLights = lightPositions.map((position, idx) => {
      const beam = new SpotLight(
        `stadiumLight_${idx}`,
        position,
        new Vector3(-position.x * 0.02, -1, -position.z * 0.02),
        Math.PI / 3.4,
        2,
        this.scene
      );
      beam.intensity = 65;
      beam.diffuse = Color3.FromHexString(idx % 2 ? '#dceeff' : '#fff2b2');
      return beam;
    });

    const lightTowerMeshes = lightPositions.map((position, idx) => {
      const tower = MeshBuilder.CreateBox(`lightTower_${idx}`, { width: 0.4, height: 20, depth: 0.4 }, this.scene);
      tower.position = new Vector3(position.x, 10, position.z);
      tower.material = lightPoleMat;
      return tower;
    });

    const playerBodyMat = new StandardMaterial('playerBodyMat', this.scene);
    playerBodyMat.diffuseColor = Color3.FromHexString('#f4f7fb');
    playerBodyMat.specularColor = Color3.FromHexString('#5d7391');

    const helmetMat = new StandardMaterial('helmetMat', this.scene);
    helmetMat.diffuseColor = Color3.FromHexString('#1f5fd1');
    helmetMat.emissiveColor = Color3.FromHexString('#0d2858');

    const defenderMat = new StandardMaterial('defenderMat', this.scene);
    defenderMat.diffuseColor = Color3.FromHexString('#de3747');
    defenderMat.specularColor = Color3.FromHexString('#6f1018');

    const defenderHelmetMat = new StandardMaterial('defenderHelmetMat', this.scene);
    defenderHelmetMat.diffuseColor = Color3.FromHexString('#820d18');
    defenderHelmetMat.emissiveColor = Color3.FromHexString('#36070d');

    const player = MeshBuilder.CreateCapsule(
      'ballCarrier',
      { radius: 0.55, height: 2.6, tessellation: 12, capSubdivisions: 6 },
      this.scene
    );
    player.position = new Vector3(0, 1.3, 28);
    player.material = playerBodyMat;
    this.shadowGenerator.addShadowCaster(player);

    const playerHelmet = MeshBuilder.CreateSphere('playerHelmet', { diameter: 1.02, segments: 12 }, this.scene);
    playerHelmet.position = new Vector3(0, 2.58, 28);
    playerHelmet.material = helmetMat;
    this.shadowGenerator.addShadowCaster(playerHelmet);

    const defenders = Array.from({ length: 3 }, (_, idx) => {
      const defender = MeshBuilder.CreateCapsule(
        `defender_${idx}`,
        { radius: 0.52, height: 2.45, tessellation: 12, capSubdivisions: 6 },
        this.scene
      );
      defender.position = new Vector3((idx - 1) * 4, 1.22, 4 + idx * 5);
      defender.material = defenderMat;
      this.shadowGenerator.addShadowCaster(defender);

      const helmet = MeshBuilder.CreateSphere(`defenderHelmet_${idx}`, { diameter: 0.96, segments: 10 }, this.scene);
      helmet.position = new Vector3(defender.position.x, 2.45, defender.position.z);
      helmet.material = defenderHelmetMat;
      this.shadowGenerator.addShadowCaster(helmet);

      return { body: defender, helmet };
    });

    const ball = MeshBuilder.CreateSphere('football', { diameter: 0.5, segments: 10 }, this.scene);
    ball.scaling = new Vector3(0.6, 1, 0.6);
    ball.position = new Vector3(0.72, 1.65, 28.2);
    const ballMat = new StandardMaterial('footballMat', this.scene);
    ballMat.diffuseColor = Color3.FromHexString('#7a4a20');
    ballMat.specularColor = Color3.FromHexString('#d1a36d');
    ball.material = ballMat;
    this.shadowGenerator.addShadowCaster(ball);

    const sidelineWest = MeshBuilder.CreateBox('sidelineWest', { width: 0.18, height: 0.04, depth: 120 }, this.scene);
    sidelineWest.position = new Vector3(-13.95, 0.05, 0);
    sidelineWest.material = lineMat;
    const sidelineEast = MeshBuilder.CreateBox('sidelineEast', { width: 0.18, height: 0.04, depth: 120 }, this.scene);
    sidelineEast.position = new Vector3(13.95, 0.05, 0);
    sidelineEast.material = lineMat;

    this.glowLayer = new GlowLayer('footballGlow', this.scene, { blurKernelSize: 64 });
    this.glowLayer.intensity = 0.45;
    this.glowLayer.addIncludedOnlyMesh(playerHelmet);
    this.glowLayer.addIncludedOnlyMesh(ball);
    this.assets.stadiumLights.forEach((_, idx) => {
      const tower = lightTowerMeshes[idx];
      if (tower) this.glowLayer.addIncludedOnlyMesh(tower);
    });

    this.assets.player = { body: player, helmet: playerHelmet };
    this.assets.defenders = defenders;
    this.assets.ball = ball;
    this.assets.goalPost = { goalPostCrossbar, goalPostStem, leftUpright, rightUpright };
    this.assets.lightTowers = lightTowerMeshes;

    this.touchdownParticles = new ParticleSystem('touchdownFireworks', 1600, this.scene);
    this.touchdownParticles.particleTexture = new Texture(
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAANRJREFUKFNjZICC////Z2RgYGRk+A8EDAwM/4eHh5GQkJDh4eE/xsbG/x8fH3YwMDA8RkZGf8bGxn8g0Pr6+v+JiYn/x8fH/2NjY/8DAwP/h4eH/zMxM/4KCgv8/Pz//gYGB/wMDA/8ZGxn/8fHx/wcHB/8TEhL/JiYm/xMTE/8zMzP/4eHh/8fHx/9ra2v/AwMD/4uLi/8nJyf8fHx//CwsL/6urq/9nZ2f8fHx//MDAw/5ubm/9ZWVn/f39//w8PD/+MjIz/Ghoa/xQUFP8MDAz/XV1d/0hISJgYGBgYAJb1JxXm7Z2wAAAAAElFTkSuQmCC',
      this.scene,
      true,
      false
    );
    this.touchdownParticles.minEmitBox = new Vector3(-2, 8, -52);
    this.touchdownParticles.maxEmitBox = new Vector3(2, 10, -48);
    this.touchdownParticles.color1 = Color4.FromHexString('#ffd54aff');
    this.touchdownParticles.color2 = Color4.FromHexString('#4cc9f0ff');
    this.touchdownParticles.colorDead = Color4.FromHexString('#ef476f00');
    this.touchdownParticles.minSize = 0.18;
    this.touchdownParticles.maxSize = 0.36;
    this.touchdownParticles.minLifeTime = 0.45;
    this.touchdownParticles.maxLifeTime = 1.2;
    this.touchdownParticles.emitRate = 0;
    this.touchdownParticles.blendMode = ParticleSystem.BLENDMODE_ONEONE;
    this.touchdownParticles.gravity = new Vector3(0, -8, 0);
    this.touchdownParticles.direction1 = new Vector3(-8, 8, -8);
    this.touchdownParticles.direction2 = new Vector3(8, 14, 8);
    this.touchdownParticles.minAngularSpeed = 0;
    this.touchdownParticles.maxAngularSpeed = Math.PI;
    this.touchdownParticles.minEmitPower = 3;
    this.touchdownParticles.maxEmitPower = 8;
    this.touchdownParticles.updateSpeed = 0.018;

    this.engine.runRenderLoop(() => this.scene?.render());
    this._handleResize = () => this.engine?.resize();
    if (typeof window !== 'undefined') {
      window.addEventListener('resize', this._handleResize);
    }

    this.setCameraAngle('line_of_scrimmage');

    return {
      engine: this.engine,
      scene: this.scene,
      camera: this.camera,
      assets: this.assets,
      isFallback: false,
    };
  }

  setCameraAngle(angle = 'line_of_scrimmage') {
    this._cameraAngle = CAMERA_PRESETS[angle] ? angle : 'line_of_scrimmage';
    if (!this.camera || !this.scene) return this._cameraAngle;
    const preset = CAMERA_PRESETS[this._cameraAngle];
    this.camera.alpha = preset.alpha;
    this.camera.beta = preset.beta;
    this.camera.radius = preset.radius;
    if (this._Vector3) {
      this.camera.setTarget(new this._Vector3(preset.target.x, preset.target.y, preset.target.z));
    }
    return this._cameraAngle;
  }

  triggerTouchdown() {
    if (this.isFallback) return;
    this.setCameraAngle('end_zone');
    if (this.glowLayer) {
      this.glowLayer.intensity = 0.9;
      setTimeout(() => {
        if (this.glowLayer) this.glowLayer.intensity = 0.45;
      }, 900);
    }
    if (this.touchdownParticles) {
      this.touchdownParticles.manualEmitCount = 420;
      this.touchdownParticles.start();
      setTimeout(() => this.touchdownParticles?.stop(), 750);
    }
  }

  animatePlayerRun(direction = 'up') {
    const player = this.assets.player?.body;
    const helmet = this.assets.player?.helmet;
    const ball = this.assets.ball;
    if (!player || !helmet || !ball) return;

    const laneDelta =
      direction === 'left' ? -0.7 :
      direction === 'right' ? 0.7 :
      direction === 'up-left' ? -0.45 :
      direction === 'up-right' ? 0.45 :
      0;
    const forwardDelta = direction === 'down' ? 0.4 : -1.15;

    player.position.x = Math.max(-10.5, Math.min(10.5, player.position.x + laneDelta));
    player.position.z = Math.max(-53, Math.min(33, player.position.z + forwardDelta));
    player.position.y = 1.25 + Math.abs(Math.sin(Date.now() / 110)) * 0.08;
    helmet.position.x = player.position.x;
    helmet.position.z = player.position.z;
    helmet.position.y = player.position.y + 1.28;
    ball.position.x = player.position.x + 0.72;
    ball.position.z = player.position.z + 0.15;
    ball.position.y = player.position.y + 0.35;
    ball.rotation.z += 0.28;

    this.assets.defenders?.forEach(({ body, helmet }, idx) => {
      body.position.z += 0.14 + idx * 0.04;
      helmet.position.z = body.position.z;
    });

    if (this._cameraAngle === 'ball_carry' && this.camera?.target) {
      this.camera.target.x = player.position.x;
      this.camera.target.z = player.position.z - 16;
    }
  }

  animateDefenderTackle(defIdx = 0) {
    const defender = this.assets.defenders?.[defIdx];
    const player = this.assets.player?.body;
    const helmet = this.assets.player?.helmet;
    if (!defender?.body || !player || !helmet) return;

    defender.body.position.x += (player.position.x - defender.body.position.x) * 0.55;
    defender.body.position.z += (player.position.z - defender.body.position.z) * 0.72;
    defender.helmet.position.x = defender.body.position.x;
    defender.helmet.position.z = defender.body.position.z;

    player.position.z += 1.3;
    helmet.position.z = player.position.z;

    this.systems?.vfx?.trigger?.('camera_shake', { intensity: 0.55, duration: 220 });
  }

  dispose() {
    if (typeof window !== 'undefined' && this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
    this._handleResize = null;
    this.touchdownParticles?.dispose?.();
    this.touchdownParticles = null;
    this.glowLayer?.dispose?.();
    this.glowLayer = null;
    this.shadowGenerator?.dispose?.();
    this.shadowGenerator = null;
    this.scene?.dispose?.();
    this.scene = null;
    this.engine?.dispose?.();
    this.engine = null;
    this.camera = null;
    this.assets = {};
    this._Vector3 = null;
  }
}

export { loadBabylonCore };
export default FootballScene;

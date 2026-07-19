// Babylon mini-avatar: loads the canonical rig, applies MiniAvatarSpec proportions
// (per-bone scaling) + palette, and can play clips through the app's
// CharacterAnimator. Used by the avatar reveal AND ExerciseMoviePlayer.
//
// INTEGRATION: `loadCanonicalRig` must come from the app's asset layer (10-phase
// Phase 1.1 canonical Mixamo-named skeleton). Declared as a prop for wiring.

import { useEffect, useRef } from 'react';
import {
  Engine, Scene, ArcRotateCamera, HemisphericLight, DirectionalLight,
  Vector3, Color3, Color4, type AbstractMesh, type Skeleton,
} from '@babylonjs/core';
import type { MiniAvatarSpec } from '../shared/contracts';

export interface LoadedRig {
  root: AbstractMesh;
  skeleton: Skeleton;
  /** e.g. mesh material slots for palette recolor */
  setPalette(p: MiniAvatarSpec['palette']): void;
  playClip(name: string, loop: boolean): void;
  stopClips(): void;
}

const BONE_SCALE_MAP: Record<keyof Omit<MiniAvatarSpec['proportions'], 'height'>, string[]> = {
  torso: ['mixamorig:Spine', 'mixamorig:Spine1', 'mixamorig:Spine2'],
  arms: ['mixamorig:LeftArm', 'mixamorig:RightArm'],
  forearms: ['mixamorig:LeftForeArm', 'mixamorig:RightForeArm'],
  legs: ['mixamorig:LeftUpLeg', 'mixamorig:RightUpLeg'],
  shins: ['mixamorig:LeftLeg', 'mixamorig:RightLeg'],
  shoulders: ['mixamorig:LeftShoulder', 'mixamorig:RightShoulder'],
  hips: ['mixamorig:Hips'],
};

export function applyProportions(rig: LoadedRig, spec: MiniAvatarSpec): void {
  rig.root.scaling.setAll(spec.proportions.height);
  for (const [key, bones] of Object.entries(BONE_SCALE_MAP)) {
    const s = spec.proportions[key as keyof typeof BONE_SCALE_MAP];
    for (const name of bones) {
      const bone = rig.skeleton.bones.find((b) => b.name === name);
      // Length lives on the bone's local scale along its axis; uniform scale reads
      // cleaner on stylized rigs than axis-picking per bone.
      bone?.getTransformNode()?.scaling.setAll(s);
    }
  }
  rig.setPalette(spec.palette);
}

export function MiniAvatarPreview(props: {
  spec: MiniAvatarSpec;
  loadCanonicalRig: (scene: Scene) => Promise<LoadedRig>;
  clip?: string;                    // idle by default; ExerciseMoviePlayer passes exercise clips
  loop?: boolean;
  spin?: boolean;                   // reveal moment: slow turntable
  className?: string;
  onRig?: (rig: LoadedRig) => void;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current!;
    const engine = new Engine(canvas, true, { antialias: true });
    const scene = new Scene(engine);
    scene.clearColor = new Color4(0, 0, 0, 0);

    const cam = new ArcRotateCamera('cam', Math.PI / 2, Math.PI / 2.4, 3.4, new Vector3(0, 1, 0), scene);
    cam.lowerRadiusLimit = 2; cam.upperRadiusLimit = 6;
    cam.attachControl(canvas, true);

    const key = new DirectionalLight('key', new Vector3(-0.5, -1, -0.3), scene);
    key.intensity = 2.2;
    const fill = new HemisphericLight('fill', new Vector3(0, 1, 0), scene);
    fill.intensity = 0.7; fill.groundColor = new Color3(0.35, 0.35, 0.4);

    let disposed = false;
    props.loadCanonicalRig(scene).then((rig) => {
      if (disposed) return;
      applyProportions(rig, props.spec);
      rig.playClip(props.clip ?? 'idle', props.loop ?? true);
      props.onRig?.(rig);
    });

    engine.runRenderLoop(() => {
      if (props.spin) cam.alpha += 0.004;
      scene.render();
    });
    const onResize = () => engine.resize();
    window.addEventListener('resize', onResize);

    return () => {
      disposed = true;
      window.removeEventListener('resize', onResize);
      scene.dispose(); engine.dispose();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [props.spec.avatarId, props.clip]);

  return <canvas ref={canvasRef} className={props.className ?? 'h-72 w-full'} />;
}

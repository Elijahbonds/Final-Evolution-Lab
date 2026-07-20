// RenderPipeline — the second half of the flat-screenshot fix. Babylon's
// DefaultRenderingPipeline gives bloom (the umbrella highlights, scoreboard,
// and stadium lights currently have zero glow), anti-aliasing (edges are
// currently raw/jagged at these camera distances), and image-processing
// tonemapping + a mood-tinted vignette (the "golden hour" mood is a sky
// gradient right now — this makes the WHOLE frame feel like golden hour,
// the way a real camera/game would grade it). One pipeline per scene,
// mood-matched to the same presets LightRig uses.

import { DefaultRenderingPipeline } from '@babylonjs/core';
import type { Camera, Scene } from '@babylonjs/core';

export interface MoodGrade {
  bloomThreshold: number; bloomWeight: number; bloomScale: number;
  exposure: number; contrast: number;
  vignetteColor: [number, number, number, number]; vignetteWeight: number;
}

export const MOOD_GRADE: Record<string, MoodGrade> = {
  goldenHour: {
    bloomThreshold: 0.65, bloomWeight: 0.35, bloomScale: 0.5,
    exposure: 1.15, contrast: 1.12,
    vignetteColor: [0.25, 0.12, 0.05, 0], vignetteWeight: 1.4,
  },
  dojoWarm: {
    bloomThreshold: 0.7, bloomWeight: 0.25, bloomScale: 0.4,
    exposure: 1.0, contrast: 1.18,
    vignetteColor: [0.1, 0.04, 0.02, 0], vignetteWeight: 1.8,
  },
  alpineNoon: {
    bloomThreshold: 0.78, bloomWeight: 0.3, bloomScale: 0.5,
    exposure: 1.2, contrast: 1.08,
    vignetteColor: [0.05, 0.08, 0.12, 0], vignetteWeight: 1.1,
  },
  stadiumNight: {
    bloomThreshold: 0.55, bloomWeight: 0.5, bloomScale: 0.6,
    exposure: 1.05, contrast: 1.22,
    vignetteColor: [0, 0.02, 0.06, 0], vignetteWeight: 2.2,
  },
  default: {
    bloomThreshold: 0.7, bloomWeight: 0.3, bloomScale: 0.5,
    exposure: 1.1, contrast: 1.1,
    vignetteColor: [0.06, 0.06, 0.08, 0], vignetteWeight: 1.3,
  },
};

export class RenderPipeline {
  private pipeline: DefaultRenderingPipeline;

  constructor(private scene: Scene, cameras: Camera[], mood: keyof typeof MOOD_GRADE | string = 'default') {
    // fxaa true = free anti-aliasing; bloom/sharpen enabled explicitly below
    this.pipeline = new DefaultRenderingPipeline('felPipeline', true, scene, cameras);
    this.pipeline.fxaaEnabled = true;
    this.pipeline.bloomEnabled = true;
    this.pipeline.sharpenEnabled = true;
    this.pipeline.sharpen.edgeAmount = 0.25;
    this.pipeline.imageProcessing.vignetteEnabled = true;
    this.pipeline.imageProcessing.toneMappingEnabled = true;
    this.applyMood(mood);
  }

  applyMood(mood: keyof typeof MOOD_GRADE | string): void {
    const g = MOOD_GRADE[mood] ?? MOOD_GRADE.default;
    this.pipeline.bloomThreshold = g.bloomThreshold;
    this.pipeline.bloomWeight = g.bloomWeight;
    this.pipeline.bloomScale = g.bloomScale;
    this.pipeline.imageProcessing.exposure = g.exposure;
    this.pipeline.imageProcessing.contrast = g.contrast;
    this.pipeline.imageProcessing.vignetteColor.set(...g.vignetteColor);
    this.pipeline.imageProcessing.vignetteWeight = g.vignetteWeight;
  }

  /** Brief exposure pulse for a highlight moment (dunk flush, touchdown,
   *  goal) — reads as a camera-flash beat without a hard cut. Self-reverts. */
  flashBeat(ctx: { scene: Scene }): void {
    const base = this.pipeline.imageProcessing.exposure;
    this.pipeline.imageProcessing.exposure = base * 1.35;
    const obs = ctx.scene.onBeforeRenderObservable.add(() => {
      this.pipeline.imageProcessing.exposure += (base - this.pipeline.imageProcessing.exposure) * 0.15;
      if (Math.abs(this.pipeline.imageProcessing.exposure - base) < 0.01) {
        this.pipeline.imageProcessing.exposure = base;
        ctx.scene.onBeforeRenderObservable.remove(obs);
      }
    });
  }

  dispose(): void { this.pipeline.dispose(); }
}

// WIRING (ModeHarness, once per mode load, AFTER the camera exists):
//   const renderFx = new RenderPipeline(scene, [camera], modeConfig.mood);
//   ... on mode dispose: renderFx.dispose();
// Optional per-mode flourish (already called from the M43 files' big
// moments if you want it — safe to skip, purely additive):
//   renderFx.flashBeat({ scene }); // on a made dunk / touchdown / goal
//
// PERFORMANCE NOTE: DefaultRenderingPipeline is a well-optimized, standard
// Babylon feature — the cost here is bloom's extra render targets. If a
// lower-end device profile is ever needed, expose a `quality: 'low'|'high'`
// param that skips bloomEnabled/sharpenEnabled and keeps only fxaa +
// image-processing (near-zero cost, most of the visual lift).

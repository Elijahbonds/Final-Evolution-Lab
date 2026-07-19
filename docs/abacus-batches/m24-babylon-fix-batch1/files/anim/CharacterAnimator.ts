// CharacterAnimator — one Babylon controller per character. Weighted cross-fades,
// onEnd callbacks, resolver-backed lookups. Bind pose is unreachable: a resolved
// clip always plays.

import type { AnimationGroup, Scene, Observer } from '@babylonjs/core';
import { resolveClip } from './clipResolver';

export interface PlayOpts {
  loop?: boolean;
  speedRatio?: number;
  fadeSec?: number;
  onEnd?: () => void;
}

export class CharacterAnimator {
  private groups = new Map<string, AnimationGroup>();
  private current: AnimationGroup | null = null;
  private fadeObs: Observer<Scene> | null = null;
  private endObs = new Map<AnimationGroup, Observer<AnimationGroup>>();

  constructor(private scene: Scene, groups: AnimationGroup[]) {
    for (const g of groups) this.register(g);
  }

  register(g: AnimationGroup): void {
    g.stop();
    this.groups.set(g.name, g);
  }

  get clipNames(): Set<string> { return new Set(this.groups.keys()); }

  play(name: string, opts: PlayOpts = {}): AnimationGroup | null {
    const r = resolveClip(name, this.clipNames);
    const next = this.groups.get(r.clip);
    if (!next) return null;                      // only possible with an empty library

    const { loop = false, speedRatio = 1, fadeSec = 0.15, onEnd } = opts;
    const finalSpeed = speedRatio * r.speedRatio;

    const prev = this.current;
    if (prev === next && next.isPlaying) {       // restart same clip cleanly
      next.stop();
    }

    next.speedRatio = Math.abs(finalSpeed);
    // negative speed = play from end (Babylon supports goToFrame + negative ratio)
    next.start(loop, Math.abs(finalSpeed), finalSpeed < 0 ? next.to : next.from,
               finalSpeed < 0 ? next.from : next.to, false);
    next.setWeightForAllAnimatables(0);

    if (onEnd) {
      this.endObs.get(next)?.remove();
      const obs = next.onAnimationGroupEndObservable.addOnce(() => onEnd());
      this.endObs.set(next, obs as unknown as Observer<AnimationGroup>);
    }

    this.crossFade(prev, next, fadeSec);
    this.current = next;
    return next;
  }

  /** Frame-driven weight ramp: prev→0, next→1. */
  private crossFade(prev: AnimationGroup | null, next: AnimationGroup, fadeSec: number): void {
    this.fadeObs?.remove();
    if (fadeSec <= 0) {
      prev?.stop();
      next.setWeightForAllAnimatables(1);
      return;
    }
    let t = 0;
    this.fadeObs = this.scene.onBeforeRenderObservable.add(() => {
      t += this.scene.getEngine().getDeltaTime() / 1000;
      const k = Math.min(1, t / fadeSec);
      next.setWeightForAllAnimatables(k);
      if (prev && prev !== next) prev.setWeightForAllAnimatables(1 - k);
      if (k >= 1) {
        if (prev && prev !== next) prev.stop();
        this.fadeObs?.remove();
        this.fadeObs = null;
      }
    });
  }

  setSpeed(name: string, speedRatio: number): void {
    const g = this.groups.get(resolveClip(name, this.clipNames).clip);
    if (g?.isPlaying) g.speedRatio = speedRatio;
  }

  stopAll(fadeToIdle = 'idle_stand'): void {
    this.play(fadeToIdle, { loop: true, fadeSec: 0.2 });
  }

  dispose(): void {
    this.fadeObs?.remove();
    this.endObs.forEach((o, g) => g.onAnimationGroupEndObservable.remove(o as never));
    this.groups.forEach((g) => g.stop());
  }
}

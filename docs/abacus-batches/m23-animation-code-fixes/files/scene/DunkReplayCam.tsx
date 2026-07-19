// DunkReplayCam — records the last ~4s of character-root + ball transforms and
// replays them at 0.5× from two authored angles after every made dunk.
// Recorded-transform replay (deterministic, tiny memory) — not video capture.

import { useEffect, useRef, useState } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import { Object3D, Vector3, Quaternion, PerspectiveCamera } from 'three';

const WINDOW_S = 4;
const RATE_HZ = 30;
const REPLAY_SPEED = 0.5;

interface Sample { t: number; charPos: Vector3; charQuat: Quaternion; ballPos: Vector3 }

export interface ReplayHandle {
  /** call when a dunk scores; resolves when replay ends or is skipped */
  playReplay(rimCenter: Vector3): Promise<void>;
}

export function DunkReplayCam(props: {
  character: Object3D | null;
  ball: Object3D | null;
  onHandle: (h: ReplayHandle) => void;
  /** parent gameplay camera is disabled while replay owns the view */
  setGameplayCamEnabled: (on: boolean) => void;
}) {
  const { camera } = useThree();
  const buf = useRef<Sample[]>([]);
  const [replay, setReplay] = useState<{ rim: Vector3; resolve: () => void } | null>(null);
  const rt = useRef(0);
  const acc = useRef(0);

  // ── continuous ring-buffer recording ──
  useFrame((_, dt) => {
    if (replay || !props.character || !props.ball) return;
    acc.current += dt;
    if (acc.current < 1 / RATE_HZ) return;
    acc.current = 0;
    const now = performance.now() / 1000;
    buf.current.push({
      t: now,
      charPos: props.character.getWorldPosition(new Vector3()),
      charQuat: props.character.getWorldQuaternion(new Quaternion()),
      ballPos: props.ball.getWorldPosition(new Vector3()),
    });
    const cutoff = now - WINDOW_S;
    while (buf.current.length && buf.current[0].t < cutoff) buf.current.shift();
  });

  // ── replay playback: angle A (low baseline) → angle B (rim-side profile) ──
  useFrame((_, dt) => {
    if (!replay || buf.current.length < 2) return;
    rt.current += dt * REPLAY_SPEED;
    const dur = buf.current[buf.current.length - 1].t - buf.current[0].t;
    const t = buf.current[0].t + Math.min(rt.current, dur);
    const i = Math.max(1, buf.current.findIndex((s) => s.t >= t));
    const a = buf.current[i - 1], b = buf.current[i] ?? a;
    const k = b.t === a.t ? 0 : (t - a.t) / (b.t - a.t);
    const charPos = a.charPos.clone().lerp(b.charPos, k);
    const ballPos = a.ballPos.clone().lerp(b.ballPos, k);

    // drive the recorded actors (caller renders ghosts OR reuses live meshes)
    props.character?.position.copy(charPos);
    props.character?.quaternion.copy(a.charQuat.clone().slerp(b.charQuat, k));
    props.ball?.position.copy(ballPos);

    const half = dur / 2;
    const cam = camera as PerspectiveCamera;
    if (rt.current < half) {
      // ANGLE A: low baseline, looking up the flight
      cam.position.lerp(new Vector3(charPos.x + 4.5, 0.9, charPos.z + 6.5), 0.12);
      cam.lookAt(ballPos);
    } else {
      // ANGLE B: rim-side profile at rim height — where the dunk reads
      const rim = replay.rim;
      cam.position.lerp(new Vector3(rim.x + 3.2, rim.y + 0.2, rim.z), 0.12);
      cam.lookAt(ballPos.clone().lerp(rim, 0.35));
    }
    if (rt.current >= dur) endReplay();
  });

  const endReplay = () => {
    replay?.resolve();
    setReplay(null);
    props.setGameplayCamEnabled(true);
  };

  useEffect(() => {
    props.onHandle({
      playReplay: (rimCenter: Vector3) =>
        new Promise<void>((resolve) => {
          if (buf.current.length < RATE_HZ) return resolve();  // nothing recorded
          rt.current = 0;
          props.setGameplayCamEnabled(false);
          setReplay({ rim: rimCenter.clone(), resolve });
        }),
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // skip on tap/space
  useEffect(() => {
    if (!replay) return;
    const skip = () => endReplay();
    window.addEventListener('pointerdown', skip);
    const key = (e: KeyboardEvent) => e.key === ' ' && skip();
    window.addEventListener('keydown', key);
    return () => { window.removeEventListener('pointerdown', skip); window.removeEventListener('keydown', key); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [replay]);

  return replay ? (
    <group>
      {/* REPLAY badge is DOM-side: render alongside canvas when handle is active */}
    </group>
  ) : null;
}

// Wiring (dunk mode):
//   <DunkReplayCam character={charGroup} ball={ballMesh}
//     onHandle={(h) => (replayRef.current = h)}
//     setGameplayCamEnabled={setCamEnabled} />
//   ...on scored: await replayRef.current?.playReplay(rimCenterVec3); then result flow.
//   DOM overlay while replaying: "▶ REPLAY — tap to skip".

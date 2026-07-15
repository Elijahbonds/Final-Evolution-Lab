'use client';

import { useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import type { PerfSample } from '@/lib/three-budget';

// Lives INSIDE the Canvas. Samples renderer stats + fps ~4x/sec and reports them
// out via callback so a plain DOM overlay (outside WebGL) can display the budget
// readout without costing draw calls.
export function PerfSampler({ onSample }: { onSample: (s: PerfSample) => void }) {
  const gl = useThree((s) => s.gl);
  const frames = useRef(0);
  const acc = useRef(0);
  const fps = useRef(60);

  useFrame((_, dt) => {
    frames.current += 1;
    acc.current += dt;
    if (acc.current >= 0.25) {
      fps.current = Math.round(frames.current / acc.current);
      const info = gl.info;
      onSample({
        fps: fps.current,
        calls: info.render.calls,
        triangles: info.render.triangles,
        textures: info.memory.textures,
        geometries: info.memory.geometries,
        programs: info.programs?.length ?? 0,
      });
      frames.current = 0;
      acc.current = 0;
    }
  });

  return null;
}

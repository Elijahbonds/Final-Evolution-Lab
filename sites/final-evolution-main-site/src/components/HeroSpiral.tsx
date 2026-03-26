import { Suspense, useMemo, useRef, useState, useEffect } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import * as THREE from "three";

const CYAN = "#5ce1e6";
const BLACK = "#000000";

function SpiralJumpTube() {
  const meshRef = useRef<THREE.Mesh>(null);

  const curve = useMemo(() => {
    const pts: THREE.Vector3[] = [];
    const segments = 96;
    for (let i = 0; i <= segments; i++) {
      const t = i / segments;
      const spiral = t * Math.PI * 2.8;
      const radius = 0.55 * (1 - t * 0.35);
      const y = Math.sin(t * Math.PI) * 2.4 - 0.35 + t * 0.2;
      pts.push(
        new THREE.Vector3(
          Math.cos(spiral) * radius,
          y,
          Math.sin(spiral) * radius * 0.85
        )
      );
    }
    return new THREE.CatmullRomCurve3(pts);
  }, []);

  useFrame(({ clock }) => {
    const m = meshRef.current;
    if (!m) return;
    m.rotation.y = clock.elapsedTime * 0.12;
    m.position.y = Math.sin(clock.elapsedTime * 0.6) * 0.06;
  });

  return (
    <mesh ref={meshRef}>
      <tubeGeometry args={[curve, 200, 0.07, 12, false]} />
      <meshBasicMaterial
        color={CYAN}
        transparent
        opacity={0.92}
        toneMapped={false}
      />
    </mesh>
  );
}

function Scene() {
  return (
    <>
      <color attach="background" args={[BLACK]} />
      <fog attach="fog" args={[BLACK, 4, 14]} />
      <SpiralJumpTube />
      <mesh position={[0, -2.2, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <planeGeometry args={[24, 24]} />
        <meshBasicMaterial color={BLACK} />
      </mesh>
    </>
  );
}

type HeroSpiralProps = {
  videoUrl?: string;
};

/**
 * Full-bleed hero: Three.js spiral “mid-jump” line on pure black.
 * Optional `videoUrl`: subtle ambient loop behind WebGL, or full-bleed fallback if WebGL is missing.
 *
 * **Rendering:** Uses the browser’s `requestAnimationFrame` (typically ~60 Hz on standard displays).
 * The **16.6 ms** value in the product is the **lab motion-timing target**, not a hard guarantee for this canvas.
 */
export function HeroSpiral({ videoUrl }: HeroSpiralProps) {
  const [webglOk, setWebglOk] = useState(true);

  useEffect(() => {
    try {
      const c = document.createElement("canvas");
      const gl =
        c.getContext("webgl") || c.getContext("experimental-webgl");
      if (!gl) setWebglOk(false);
    } catch {
      setWebglOk(false);
    }
  }, []);

  const ambientVideo = webglOk && Boolean(videoUrl);
  const fallbackVideo = !webglOk && Boolean(videoUrl);

  return (
    <div className="relative h-[min(100dvh,900px)] w-full overflow-hidden bg-fel-black">
      {ambientVideo ? (
        <video
          className="absolute inset-0 z-0 h-full w-full object-cover opacity-[0.22]"
          src={videoUrl}
          autoPlay
          muted
          loop
          playsInline
          aria-hidden
        />
      ) : null}

      {fallbackVideo ? (
        <video
          className="absolute inset-0 z-0 h-full w-full object-cover"
          src={videoUrl}
          autoPlay
          muted
          loop
          playsInline
          aria-hidden
        />
      ) : null}

      {webglOk ? (
        <div className="absolute inset-0 z-[1]">
          <Suspense
            fallback={
              <div className="flex h-full w-full items-center justify-center bg-fel-black text-xs text-white/40">
                Loading…
              </div>
            }
          >
            <Canvas
              className="h-full w-full"
              frameloop="always"
              dpr={[1, 2]}
              gl={{ antialias: true, alpha: false, powerPreference: "high-performance" }}
              camera={{ position: [0, 0.4, 6.2], fov: 42 }}
              onCreated={({ gl }) => {
                gl.setClearColor(BLACK, 1);
              }}
            >
              <Scene />
            </Canvas>
          </Suspense>
        </div>
      ) : !fallbackVideo ? (
        <div className="absolute inset-0 z-[1] flex flex-col items-center justify-center bg-fel-black px-6 text-center">
          <p className="text-sm text-fel-cyan/80">
            This device can’t show the 3D hero. The rest of the site works normally.
          </p>
        </div>
      ) : null}

      <div
        className="pointer-events-none absolute inset-0 z-[2] bg-gradient-to-b from-fel-black/20 via-transparent to-fel-black"
        aria-hidden
      />
    </div>
  );
}

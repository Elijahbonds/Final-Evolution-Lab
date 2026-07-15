'use client';

import { useRef, type MutableRefObject } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';

/**
 * Smooth third-person follow camera with AABB collision handling.
 * Tracks a moving target (the player) with critically-damped interpolation.
 * If boundsMin/boundsMax are provided, clamps the camera position to stay
 * within the navigable volume and above floorY / below ceilingY.
 */
export function FollowCamera({
  target,
  offset,
  lookHeight = 1.4,
  lookOffsetX = 0,
  lookOffsetZ = 0,
  stiffness = 5,
  boundsMin,
  boundsMax,
  floorY,
  ceilingY,
}: {
  target: MutableRefObject<THREE.Vector3>;
  offset: THREE.Vector3;
  lookHeight?: number;
  lookOffsetX?: number;
  lookOffsetZ?: number;
  stiffness?: number;
  boundsMin?: THREE.Vector3;
  boundsMax?: THREE.Vector3;
  floorY?: number;
  ceilingY?: number;
}) {
  const cam = useThree((s) => s.camera);
  const desired = useRef(new THREE.Vector3());
  const lookCur = useRef<THREE.Vector3 | null>(null);
  const lookTgt = useRef(new THREE.Vector3());

  useFrame((_, dtRaw) => {
    const dt = Math.min(dtRaw, 0.05);
    const t = target.current;

    // Compute desired camera position
    desired.current.copy(t).add(offset);

    // --- COLLISION: clamp to navigable AABB ---
    if (boundsMin && boundsMax) {
      desired.current.x = Math.max(boundsMin.x, Math.min(boundsMax.x, desired.current.x));
      desired.current.z = Math.max(boundsMin.z, Math.min(boundsMax.z, desired.current.z));
    }
    // Floor / ceiling clamp
    if (floorY !== undefined) {
      desired.current.y = Math.max(floorY + 1.0, desired.current.y); // minimum 1m above floor
    }
    if (ceilingY !== undefined) {
      desired.current.y = Math.min(ceilingY - 0.5, desired.current.y);
    }

    // Smooth interpolation
    const k = 1 - Math.exp(-stiffness * dt);
    cam.position.lerp(desired.current, k);

    // Look target with smooth tracking
    lookTgt.current.set(t.x + lookOffsetX, t.y + lookHeight, t.z + lookOffsetZ);
    if (!lookCur.current) lookCur.current = lookTgt.current.clone();
    lookCur.current.lerp(lookTgt.current, k);
    cam.lookAt(lookCur.current);
  });

  return null;
}

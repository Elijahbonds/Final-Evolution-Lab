// Authoritative registry of all 3D maps in FEL.
// Each entry maps to a Meshy-derived GLB in public/models/maps/.
// Scale converts the normalized [-1,1] GLB bounds to real-world metres.

export interface MapConfig {
  key: string;
  label: string;
  glb: string;            // path under public/
  scale: number;          // uniform scale to apply
  spawnPos: [number, number, number]; // player start (world coords after scale)
  spawnYaw: number;       // initial facing (radians, 0=+Z)
  camOffset: [number, number, number]; // follow-cam offset from player
  ambientColor: string;   // tint for hemisphere light
  fogColor: string;       // scene fog colour
  fogNear: number;
  fogFar: number;
  floorY: number;         // ground plane Y in world coords (after scale)
  ceilingY: number;       // approx ceiling for cam collision
  boundsMin: [number, number, number]; // navigable AABB min
  boundsMax: [number, number, number]; // navigable AABB max
  backdrop?: string;      // photographic sky/environment backdrop shown behind the map
}

export const MAPS: Record<string, MapConfig> = {
  'venice-blacktop': {
    key: 'venice-blacktop',
    label: 'Venice Blacktop Court',
    glb: '/models/maps/venice-blacktop.glb',
    scale: 14,
    spawnPos: [0, 0, 6],
    spawnYaw: Math.PI,
    camOffset: [-3, 4, 8],
    ambientColor: '#3a4a5e',
    fogColor: '#9fc0d8',
    fogNear: 34,
    fogFar: 95,
    floorY: 0,
    ceilingY: 8,
    boundsMin: [-13, 0, -13],
    boundsMax: [13, 8, 13],
    backdrop: '/backdrops/venice-sky-day.jpg',
  },
  'shop': {
    key: 'shop',
    label: 'Venice Ball Shop',
    glb: '/models/maps/shop.glb',
    scale: 6,
    spawnPos: [0, 0, 2],
    spawnYaw: 0,
    camOffset: [-2, 3, 5],
    ambientColor: '#1e1412',
    fogColor: '#0c0808',
    fogNear: 8,
    fogFar: 25,
    floorY: 0,
    ceilingY: 6,
    boundsMin: [-5, 0, -5],
    boundsMax: [5, 6, 5],
  },
  'venice-blue-court': {
    key: 'venice-blue-court',
    label: 'Venice Blue Court',
    glb: '/models/maps/venice-blue-court.glb',
    scale: 14,
    spawnPos: [0, 0, 6],
    spawnYaw: Math.PI,
    camOffset: [-3, 4, 8],
    ambientColor: '#3a2c3e',
    fogColor: '#5a4258',
    fogNear: 32,
    fogFar: 90,
    floorY: 0,
    ceilingY: 8,
    boundsMin: [-13, 0, -13],
    boundsMax: [13, 8, 13],
    backdrop: '/backdrops/venice-sky-sunset.jpg',
  },
  'venice-skatepark': {
    key: 'venice-skatepark',
    label: 'Venice Beach Skatepark',
    glb: '/models/maps/venice-skatepark.glb',
    scale: 14,
    spawnPos: [0, 0, 10],
    spawnYaw: Math.PI,
    camOffset: [-3.5, 4.5, 9],
    ambientColor: '#3a4a5e',
    fogColor: '#9fc0d8',
    fogNear: 34,
    fogFar: 95,
    floorY: 0,
    ceilingY: 9,
    boundsMin: [-13, 0, -13],
    boundsMax: [13, 9, 13],
    backdrop: '/backdrops/venice-sky-day.jpg',
  },
  'dojo': {
    key: 'dojo',
    label: 'Shimogamo Dojo',
    glb: '/models/maps/dojo.glb',
    scale: 8,
    spawnPos: [0, 0, 3],
    spawnYaw: Math.PI,
    camOffset: [-2, 3.5, 6],
    ambientColor: '#1a1412',
    fogColor: '#1a1210',
    fogNear: 16,
    fogFar: 52,
    floorY: 0,
    ceilingY: 10,
    boundsMin: [-7, 0, -6],
    boundsMax: [7, 10, 6],
    backdrop: '/backdrops/karate.jpg',
  },
};

// Lookup helpers
export function getMap(key: string): MapConfig | undefined {
  return MAPS[key];
}

export function getMapKeys(): string[] {
  return Object.keys(MAPS);
}
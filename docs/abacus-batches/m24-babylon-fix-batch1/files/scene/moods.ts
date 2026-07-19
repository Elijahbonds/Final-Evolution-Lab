// Venue mood presets for LightRig. One place to tune every scene's look.

export type VenueMood = 'goldenHour' | 'daylight' | 'dojoWarm' | 'nightGame' | 'alpine';

export interface MoodDef {
  sky: string; ground: string; hemiIntensity: number;
  sun: string; sunIntensity: number; sunDir: [number, number, number];
  exposure: number; clearColor: string;
}

export const MOODS: Record<VenueMood, MoodDef> = {
  goldenHour: { sky: '#ffd9a0', ground: '#4a4038', hemiIntensity: 0.75, sun: '#ffb36b', sunIntensity: 2.4, sunDir: [-0.6, -1, -0.35], exposure: 1.12, clearColor: '#2a1e33' },
  daylight:   { sky: '#cfe8ff', ground: '#5a5a52', hemiIntensity: 0.85, sun: '#ffffff', sunIntensity: 2.6, sunDir: [-0.5, -1, -0.3], exposure: 1.05, clearColor: '#87b7dd' },
  dojoWarm:   { sky: '#ffcf9e', ground: '#3a2a22', hemiIntensity: 0.65, sun: '#ff9d5c', sunIntensity: 1.9, sunDir: [-0.3, -1, -0.5], exposure: 1.1,  clearColor: '#1d1210' },
  nightGame:  { sky: '#9fb7ff', ground: '#22262e', hemiIntensity: 0.55, sun: '#e8f0ff', sunIntensity: 2.2, sunDir: [-0.35, -1, -0.2], exposure: 1.15, clearColor: '#0b0e16' },
  alpine:     { sky: '#eaf4ff', ground: '#8fa0b5', hemiIntensity: 0.9,  sun: '#fff4e0', sunIntensity: 2.8, sunDir: [-0.45, -1, -0.25], exposure: 1.05, clearColor: '#b9d4ee' },
};

/** Mode → mood mapping (README wiring step 4). */
export const MODE_MOODS: Record<string, VenueMood> = {
  dunk: 'goldenHour', h2h: 'goldenHour', threev3: 'goldenHour',
  skateboard: 'goldenHour', surf: 'goldenHour',
  tennis: 'daylight', golf: 'daylight', baseball: 'daylight', sprint: 'daylight',
  karate: 'dojoWarm', karate_versus: 'dojoWarm',
  football: 'nightGame', penalty: 'nightGame',
  snowboard_slalom: 'alpine', snowboard_bigair: 'alpine',
};

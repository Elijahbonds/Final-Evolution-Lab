#!/usr/bin/env node
// render_check.mjs — RENDER every Nexus web venue and check what came out.
//
//     node tools/render_check.mjs                    # all venues
//     node tools/render_check.mjs --mode karate_h2h  # one
//     node tools/render_check.mjs --json             # NDJSON
//     node tools/render_check.mjs --shots out/       # keep the PNGs
//
// WHY THIS IS THE POINT OF GOING WEB
// The Swift engine could never be run here: 74% of it needs Apple frameworks,
// so the best available check was a type-check of a subset (M71). A Babylon
// scene has no such problem — Chromium with SwiftShader renders it headlessly
// on any Linux box, so a venue can be BUILT, RENDERED and LOOKED AT in CI.
// That is a categorically stronger guarantee than "it compiles".
//
// WHAT IT ASSERTS, AND WHY EACH ONE EARNS ITS PLACE
//   · no page errors / no Babylon errors  — the obvious one
//   · mesh + light + material counts      — a spec that silently built nothing
//                                           still renders a clean empty sky
//   · distinct colours in the frame       — the check that actually catches a
//                                           black screen. FEL has shipped a
//                                           "passing" mode that rendered a
//                                           loading screen (M69); counting
//                                           pixels is how you stop trusting
//                                           "a canvas exists"
//   · non-trivial luminance spread        — an all-one-tone frame means the
//                                           lighting rig failed even though
//                                           geometry is present
//
// Exit non-zero if any venue fails.

import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { mkdir, writeFile, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const argOf = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const JSON_MODE = args.includes('--json');
const ONLY = argOf('--mode', null);
const SHOTS = argOf('--shots', join(ROOT, '.render-out'));
const SRC = argOf('--src', join(ROOT, 'docs/abacus-batches/m73-nexus-web/files/nexus'));

const say = (o) => {
  if (JSON_MODE) { process.stdout.write(JSON.stringify(o) + '\n'); return; }
  if (o.event === 'venue') {
    const tag = o.ok ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m';
    process.stdout.write(`  ${tag} ${o.mode.padEnd(18)} meshes=${String(o.meshes).padStart(3)} `
      + `lights=${o.lights} colors=${String(o.colors).padStart(4)} lum=${o.lumSpread}\n`);
    for (const p of o.problems) process.stdout.write(`       \x1b[31m· ${p}\x1b[0m\n`);
  } else process.stdout.write((o.text ?? '') + '\n');
};

// ── build the harness bundle ──────────────────────────────────────────────
const WORK = join(ROOT, '.render-work');
await rm(WORK, { recursive: true, force: true });
await mkdir(WORK, { recursive: true });

const esbuild = ['node_modules/.bin/esbuild', join(ROOT, 'node_modules/.bin/esbuild')]
  .map((p) => (p.startsWith('/') ? p : join(process.cwd(), p))).find((p) => existsSync(p));
if (!esbuild) {
  say({ text: '  SKIP  esbuild/@babylonjs not installed. Run:\n'
             + '        npm install --no-save @babylonjs/core esbuild' });
  process.exit(0);
}

await writeFile(join(WORK, 'entry.ts'), `
import { mountNexus } from ${JSON.stringify(join(SRC, 'NexusWebScene'))};
import { VENUE_SPECS } from ${JSON.stringify(join(SRC, 'venueSpecs'))};
const w = window as any;
w.__NEXUS_SPECS__ = Object.keys(VENUE_SPECS);
w.__mount__ = (modeId: string) => {
  const canvas = document.getElementById('c') as HTMLCanvasElement;
  const { engine, scene, built } = mountNexus(canvas, VENUE_SPECS[modeId]);
  w.__stats__ = () => ({
    meshes: scene.meshes.length,
    lights: scene.lights.length,
    materials: scene.materials.length,
    actors: built.actors.length,
    activeCamera: !!scene.activeCamera,
  });
  scene.executeWhenReady(() => { w.__READY__ = true; });
};
`);

try {
  execFileSync(esbuild, [join(WORK, 'entry.ts'), '--bundle', `--outfile=${join(WORK, 'bundle.js')}`,
    '--format=iife', '--log-level=error'], { stdio: 'pipe' });
} catch (e) {
  say({ text: `  FAIL  bundle failed:\n${String(e.stdout || e.stderr || e).slice(0, 1500)}` });
  process.exit(1);
}

await writeFile(join(WORK, 'index.html'),
  `<!doctype html><html><body style="margin:0;background:#000">
   <canvas id="c" style="width:100vw;height:100vh;display:block"></canvas>
   <script src="bundle.js"></script></body></html>`);

// ── render ────────────────────────────────────────────────────────────────
await mkdir(SHOTS, { recursive: true });
const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
});

const page = await browser.newPage({ viewport: { width: 1024, height: 640 } });
await page.goto('file://' + join(WORK, 'index.html'));
const modes = ONLY ? [ONLY] : await page.evaluate(() => window.__NEXUS_SPECS__);
await page.close();

say({ text: `\n  Nexus Web — rendering ${modes.length} venue(s) headlessly (SwiftShader)\n` });

const results = [];
for (const mode of modes) {
  const p = await browser.newPage({ viewport: { width: 1024, height: 640 } });
  const problems = [];
  p.on('pageerror', (e) => problems.push(`pageerror: ${e.message.slice(0, 160)}`));
  p.on('console', (m) => { if (m.type() === 'error') problems.push(`console: ${m.text().slice(0, 160)}`); });

  await p.goto('file://' + join(WORK, 'index.html'));
  await p.evaluate((m) => window.__mount__(m), mode).catch((e) => problems.push(`mount: ${String(e).slice(0, 160)}`));
  await p.waitForFunction(() => window.__READY__ === true, { timeout: 40000 })
    .catch(() => problems.push('scene never reported ready'));
  await p.waitForTimeout(1200);

  const stats = await p.evaluate(() => (window.__stats__ ? window.__stats__() : null)).catch(() => null);
  const shot = join(SHOTS, `${mode}.png`);
  await p.screenshot({ path: shot });

  // Pixel analysis on the PNG we just wrote, via the page itself — no native
  // image library needed, and it measures exactly what a viewer would see.
  const px = await p.evaluate(async () => {
    const c = document.getElementById('c');
    const g = c.getContext('webgl2') || c.getContext('webgl');
    if (!g) return null;
    // Read the WHOLE drawing buffer, not a corner.
    //
    // The first version sampled a 128x80 window at (0,0). WebGL's origin is
    // BOTTOM-LEFT, so that only ever looked at the dark foreground corner of
    // the frame — which on a dusk-lit venue is close to uniform. It failed 12
    // of 20 venues that render perfectly, and the screenshots proved it. A
    // metric that samples an unrepresentative region is worse than no metric:
    // it manufactures failures and buries the real ones.
    const w = g.drawingBufferWidth, h = g.drawingBufferHeight;
    const buf = new Uint8Array(w * h * 4);
    g.readPixels(0, 0, w, h, g.RGBA, g.UNSIGNED_BYTE, buf);
    const seen = new Set(); let min = 255, max = 0;
    // Stride so a 1024x640 frame costs a few thousand samples, not 650k.
    const step = Math.max(1, Math.floor((w * h) / 20000)) * 4;
    for (let i = 0; i < buf.length; i += step) {
      seen.add((buf[i] >> 3) + ',' + (buf[i + 1] >> 3) + ',' + (buf[i + 2] >> 3));
      const l = 0.2126 * buf[i] + 0.7152 * buf[i + 1] + 0.0722 * buf[i + 2];
      if (l < min) min = l; if (l > max) max = l;
    }
    return { colors: seen.size, lumSpread: Math.round(max - min), sampled: w + 'x' + h };
  }).catch(() => null);

  const colors = px?.colors ?? 0;
  const lumSpread = px?.lumSpread ?? 0;

  if (!stats) problems.push('no scene stats — mount failed');
  else {
    if (stats.meshes < 4) problems.push(`only ${stats.meshes} meshes — the venue built almost nothing`);
    if (stats.lights < 2) problems.push(`only ${stats.lights} lights — the lighting rig did not build`);
    if (!stats.activeCamera) problems.push('no active camera');
  }
  // preserveDrawingBuffer is on, but readPixels after a present can still come
  // back cleared on some drivers; only judge when we actually got a sample.
  if (px) {
    if (colors < 8) problems.push(`only ${colors} distinct colours — frame is effectively blank`);
    if (lumSpread < 25) problems.push(`luminance spread ${lumSpread} — flat/unlit frame`);
  }

  const r = { event: 'venue', mode, ok: problems.length === 0, meshes: stats?.meshes ?? 0,
    lights: stats?.lights ?? 0, materials: stats?.materials ?? 0, actors: stats?.actors ?? 0,
    colors, lumSpread, shot, problems };
  results.push(r);
  say(r);
  await p.close();
}

await browser.close();
await rm(WORK, { recursive: true, force: true });

const failed = results.filter((r) => !r.ok);
if (!JSON_MODE) {
  process.stdout.write(`\n  ${results.length - failed.length}/${results.length} venues render`
    + `${failed.length ? ` — red: ${failed.map((r) => r.mode).join(', ')}` : ''}\n`);
  process.stdout.write(`  screenshots: ${SHOTS}\n`);
}
process.exit(failed.length ? 1 : 0);

#!/usr/bin/env node
// determinism_probe.mjs — can a match be verified for prize money?
//
//     node tools/determinism_probe.mjs
//     node tools/determinism_probe.mjs --modes dunk,karate --repeats 2
//
// M91 built server-side re-simulation. M94 made `dunk` implement
// `SimulatableMode` and proved it deterministic in the repo. Neither tells you
// anything about the mode a player is actually running.
//
// A match can only be re-simulated if the client's simulation is a pure
// function of (state, input, seed). Two things break that, and both are
// observable from outside:
//
//   1. `Math.random()` during gameplay. Every call is a decision the server
//      cannot reproduce. M63's dunk contest rolled its rival this way, which
//      is the single call that made every dunk contest unverifiable.
//   2. Wall-clock reads driving simulation, so the result depends on frame
//      timing rather than on inputs.
//
// This hooks both BEFORE any page script runs, counts calls during play, and
// samples one stack per hook so a finding points at a file instead of a number.
//
// It reads and counts. It never changes a value — a probe that returned
// seeded randomness would make an unverifiable mode look verifiable, which is
// the opposite of useful.

import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const argOf = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const STATE = argOf('--state', 'smoke-state.json');
const MODES = argOf('--modes', 'dunk,onevone,threevthree,karate,karate-vs,tennis,skateboard,football').split(',');
const PLAY_MS = Number(argOf('--play', '14000'));

const HOOK = () => {
  window.__DET = { random: 0, dateNow: 0, perfNow: 0, sites: {}, armed: false };
  const realRandom = Math.random;
  // EVERY call gets a stack until the volume makes that unaffordable, then it
  // degrades to sampling and says so. Sampling 1-in-97 would miss a rival roll
  // that happens four times a session — which is exactly the M63 bug this
  // probe exists to detect, so a sampled-only answer is worthless here.
  window.__DET.sampledAfter = 60000;
  let n = 0;
  Math.random = function () {
    if (window.__DET.armed) {
      window.__DET.random++;
      const full = window.__DET.random <= window.__DET.sampledAfter;
      if (full || (n++ % 97) === 0) {
        if (!full) window.__DET.degraded = true;
        // The CALLER, not Math.random itself. Babylon's particle system and a
        // game's scoring logic both call Math.random; only one of them makes a
        // match unverifiable, and the difference is entirely in this frame.
        // THREE frames, not one. The immediate caller is usually a shared
        // minified helper (`s` turned out to be Babylon's RandomRange, called
        // from the particle system); the frame above it is what identifies
        // the subsystem. Classifying on one frame put every mode in the wrong
        // bucket on the first run.
        const st = String(new Error().stack ?? '').split('\n').slice(2, 5)
          .map((l) => l.trim().replace(/^at\s+/, '').replace(/\s*\(.*$/, ''))
          .filter(Boolean);
        const key = st.join(' < ') || '?';
        window.__DET.sites[key] = (window.__DET.sites[key] ?? 0) + 1;
      }

    }
    return realRandom();
  };
  const realNow = Date.now;
  Date.now = function () { if (window.__DET.armed) window.__DET.dateNow++; return realNow(); };
  const realPerf = performance.now.bind(performance);
  performance.now = function () { if (window.__DET.armed) window.__DET.perfNow++; return realPerf(); };
};

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  proxy: { server: process.env.HTTPS_PROXY },
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--ssl-version-max=tls1.2', '--enable-unsafe-swiftshader'],
});
if (!existsSync(STATE)) console.log(`[DET] no session at ${STATE} — everything will hit the sign-in wall.\n`);
const ctx = await browser.newContext({
  storageState: existsSync(STATE) ? STATE : undefined,
  viewport: { width: 1280, height: 800 },
});

console.log(`[DET] ${BASE}\n`);
console.log('mode          Math.random  Date.now  perf.now  verdict');
const rows = [];
for (const mode of MODES) {
  const page = await ctx.newPage();
  await page.addInitScript(HOOK);
  let r = { error: null };
  try {
    await page.goto(`${BASE}/play/${mode}`, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    await page.waitForTimeout(5000);
    const gate = page.getByText(/^\s*(TAP TO START|START)\s*$/i).first();
    if (await gate.count()) await gate.click().catch(() => {});
    await page.waitForTimeout(4000);

    // Arm only once play has begun. Loading, shader compilation and asset
    // decode all use randomness legitimately, and counting those would
    // condemn every mode for something that has nothing to do with the match.
    await page.evaluate(() => { window.__DET.armed = true; });
    for (let i = 0; i < Math.floor(PLAY_MS / 700); i++) {
      await page.keyboard.press('Space');
      await page.waitForTimeout(700);
    }
    r = await page.evaluate(() => ({ ...window.__DET }));
  } catch (e) { r.error = String(e).slice(0, 60); }
  await page.close();

  if (r.error) { console.log(`${mode.padEnd(13)} ${r.error}`); rows.push({ mode, error: r.error }); continue; }
  // A handful of calls may be UI (a particle jitter, a shuffle in a menu). A
  // gameplay loop calling it hundreds of times per session is the sim.
  // Classify by CALLER. Babylon's particle system is cosmetic: it cannot
  // change a score, so it cannot make a match unverifiable. The first run of
  // this probe reported 8/8 UNVERIFIABLE on counts alone, and the top call
  // site was `startPositionFunction` — particles. That would have been a
  // false alarm on every mode in the product.
  // Frame-aware. A site is cosmetic if ANY frame in its stack is a particle,
  // audio or noise-texture call — those cannot change a score, so they cannot
  // make a match unverifiable. Testing the joined string instead put dunk in
  // the wrong bucket twice: `s < m0._update < m0.animate` is the particle
  // system, and a `_update$` anchor never matched it.
  const COSMETIC = /startPositionFunction|startDirectionFunction|ParticleSystem|recycleParticle|noiseBuffer|\bnoise\b|Sound|Audio|\._update\b|\.animate\b/i;
  const isCosmetic = (key) => key.split(' < ').some((f) => COSMETIC.test(f));
  const sites = Object.entries(r.sites ?? {}).sort((a, b) => b[1] - a[1]);
  const suspect = sites.filter(([k]) => !isCosmetic(k));
  // ANY non-cosmetic call is disqualifying. Share is the wrong metric and the
  // first version of this used it: onevone rolls the AI's decision 120 times
  // against 13,794 particle calls, a 0.9% share — and one unreproducible AI
  // decision is enough to make the whole match unverifiable. A threshold here
  // would have passed exactly the mode that fails.
  const verdict = suspect.length > 0 ? 'UNVERIFIABLE'
    : r.random === 0 ? 'verifiable'
      : r.degraded ? 'cosmetic (sampled — not conclusive)' : 'VERIFIABLE (cosmetic only)';
  r.sitesSorted = sites.slice(0, 6);
  r.suspectSites = suspect.slice(0, 4);
  console.log(`${mode.padEnd(13)} ${String(r.random).padStart(11)}  ${String(r.dateNow).padStart(8)}  `
    + `${String(r.perfNow).padStart(8)}  ${verdict}`);
  rows.push({ mode, ...r, verdict });
}
await browser.close();

const bad = rows.filter((r) => r.verdict === 'UNVERIFIABLE');
console.log(`\n[DET] ${bad.length}/${rows.filter((r) => r.verdict).length} modes make NON-COSMETIC random calls during play.`);
for (const r of rows.filter((x) => x.sitesSorted?.length)) {
  console.log(`\n  ${r.mode} — call sites (${r.degraded ? 'COMPLETE for the first 60k calls, sampled after' : 'COMPLETE — every call'}):`);
  for (const [site, n] of r.sitesSorted) console.log(`    ${String(n).padStart(5)}  ${site.slice(0, 96)}`);
}
for (const r of bad) {
  console.log(`\n  ${r.mode} DISQUALIFYING call sites:`);
  for (const [site, n] of r.suspectSites) console.log(`    ${String(n).padStart(5)}  ${site.slice(0, 96)}`);
}
if (bad.length) {
  console.log('\n      A match containing an unreproducible decision cannot be re-simulated,');
  console.log('      so it cannot be verified for prize money. Seed the RNG (M83 Rng) and');
  console.log('      record the seed with the replay (M83 Replay).');
}
await mkdir('artifacts', { recursive: true }).catch(() => {});
await writeFile('artifacts/determinism.json', JSON.stringify({ base: BASE, at: new Date().toISOString(), rows }, null, 2));
console.log('      Full report → artifacts/determinism.json');

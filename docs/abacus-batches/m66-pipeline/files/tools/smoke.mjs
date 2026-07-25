#!/usr/bin/env node
// smoke.mjs — POST-DEPLOY verification against the LIVE link.
//
//     node tools/smoke.mjs                       # default: the live app
//     node tools/smoke.mjs --url https://... --modes dunk,onevone,karate
//
// WHY POST-DEPLOY AND NOT PRE-DEPLOY: the Babylon game is built by Abacus
// from dropped files — this repo cannot build it, so there is no local
// preview server to test against (the pipeline doc's `localhost:4173` step
// assumes a Vite build this project doesn't have). What IS possible, and is
// what has actually caught every live bug so far, is driving the deployed
// app with a real browser right after a drop.
//
// Checks per mode: page loads, canvas renders, no page errors, no
// `MISSING CLIP` / `SKINNING STALL` / watchdog trips, and the scene reports
// a healthy spawn. Exit 1 on any failure.

import { chromium } from 'playwright';
import { mkdir, writeFile } from 'node:fs/promises';

const args = process.argv.slice(2);
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const MODES = argOf('--modes', 'dunk,onevone,threevthree,karate').split(',');
const SHOTS = argOf('--shots', 'smoke-shots');
const LOAD_MS = Number(argOf('--wait', '9000'));

// Console patterns that mean something is actually wrong. `sanitized` and
// `authored clips registered` are healthy startup chatter — not failures.
const FATAL = [
  /MISSING CLIP/i,
  /SKINNING STALL/i,
  /WATCHDOG/i,
  /sceneFilename/i,
  /\[FEL-FRAME\]/i,
  /\[FEL-SPAWN\].*(?:only|fail)/i,
];

async function checkMode(context, mode) {
  const page = await context.newPage();
  const problems = [];
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message.slice(0, 160)}`));
  page.on('console', (m) => {
    if (m.type() !== 'error' && m.type() !== 'warning') return;
    const text = m.text();
    if (FATAL.some((re) => re.test(text))) problems.push(`console: ${text.slice(0, 160)}`);
  });

  let status = 0;
  try {
    const res = await page.goto(`${BASE}/play/${mode}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    status = res?.status() ?? 0;
    if (status >= 400) problems.push(`HTTP ${status}`);

    await page.waitForTimeout(LOAD_MS);

    // the game must actually be rendering something
    const canvas = await page.evaluate(() => {
      const c = document.querySelector('canvas');
      return c ? { w: c.clientWidth, h: c.clientHeight } : null;
    });
    if (!canvas) problems.push('no <canvas> on the page — the 3D scene never mounted');
    else if (canvas.w < 100 || canvas.h < 100) problems.push(`canvas is ${canvas.w}x${canvas.h} — collapsed layout`);

    // start the session and let it run a beat
    await page.keyboard.press('j');
    await page.waitForTimeout(3500);

    await mkdir(SHOTS, { recursive: true });
    await page.screenshot({ path: `${SHOTS}/${mode}.png` });
  } catch (e) {
    problems.push(`navigation failed: ${String(e).slice(0, 160)}`);
  }
  await page.close();
  return { mode, status, problems };
}

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });

console.log(`[SMOKE] ${BASE} — ${MODES.length} mode(s)\n`);
const results = [];
for (const mode of MODES) {
  const r = await checkMode(context, mode);
  results.push(r);
  const tag = r.problems.length ? 'FAIL' : 'PASS';
  console.log(`[SMOKE] ${tag} /play/${r.mode} (HTTP ${r.status})`);
  for (const p of r.problems) console.log(`        ${p}`);
}
await browser.close();

const failed = results.filter((r) => r.problems.length);
await writeFile('smoke-report.json', JSON.stringify({ base: BASE, results }, null, 2));
console.log(`\n[SMOKE] ${results.length - failed.length}/${results.length} passed · screenshots in ${SHOTS}/`);

if (failed.length) {
  console.log('[SMOKE] FAILING — the live build has problems in: ' + failed.map((f) => f.mode).join(', '));
  process.exit(1);
}

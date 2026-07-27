#!/usr/bin/env node
// integration_audit.mjs — ask the LIVE app which subsystems are actually running.
//
//     node tools/integration_audit.mjs
//     node tools/integration_audit.mjs --url https://... --modes dunk,karate
//
// THE FAILURE THIS EXISTS TO CATCH
// M69 shipped `groundSnap` and `CameraStandoff` in one batch. `groundSnap`
// runs in production. `CameraStandoff` shows no evidence of ever having run —
// no `[FEL-CAM]` line, and the camera is still 0.75m from the hero in
// karate-vs. Nobody knew for six batches, because every check we had ran
// against the BATCH, not against the DEPLOYED BUILD.
//
// `verify_batch.mjs` proves a drop is well-formed. `smoke.mjs` proves a mode
// loads and plays. Neither can tell you whether the code inside that mode is
// the code you shipped. This can, because every subsystem M80-M84 shipped
// announces itself on the console, and a subsystem that never speaks is a
// subsystem that never ran.
//
// It is deliberately EVIDENCE-BASED and refuses to guess. A marker that does
// not appear is reported as "no evidence", never as "broken" — a mode may
// simply not have reached the code path. The distinction matters: reporting
// absence as failure is exactly the mistake that had me declare six working
// routes broken in M77.

import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const STATE = argOf('--state', 'smoke-state.json');
const MODES = argOf('--modes', 'dunk,karate,onevone,skateboard').split(',');
const PLAY_MS = Number(argOf('--play', '12000'));

/**
 * What each shipped subsystem says when it runs.
 *
 * `signal` is proof it is present. `absence` explains what it means when the
 * signal never appears — which is not always "missing", and saying so is the
 * whole point.
 */
const SUBSYSTEMS = [
  {
    batch: 'M64', name: 'restPose (arms-down idle)',
    signal: /\[FEL-ANIM\] restPose solved/i,
    absence: 'the character is idling from the M24 keys, which sit ~8° off the arms-out bind pose',
  },
  {
    batch: 'M69', name: 'groundSnap',
    signal: /groundSnap|\[FEL-GROUND\]/i,
    absence: 'characters may float or sink at venue seams',
  },
  {
    batch: 'M69', name: 'CameraStandoff',
    signal: /\[FEL-CAM\]/i,
    absence: 'KNOWN NOT INTEGRATED as of 2026-07-26. The camera sits 0.75m from the hero in karate-vs against a 1.8m minimum. This is the reference case for why this tool exists.',
  },
  {
    batch: 'M80', name: 'external animation loader',
    signal: /\[FEL-ANIM\] (external clip|clip pack)/i,
    absence: 'no conformed mocap has been dropped yet — expected until tools/conform_clips.sh has been run',
  },
  {
    batch: 'M80', name: 'PoseProbe',
    signal: /\[FEL-POSE\]/i,
    absence: 'only reports under ?probe=1; this audit sets that flag, so silence here means it is not wired',
  },
  {
    batch: 'M81', name: 'engine lifecycle (ModeHarness v3)',
    signal: null,                       // measured, not logged — see probeEngines
    absence: 'window.__FEL_ENGINES__ absent; WebGL contexts are unmanaged and will leak across route changes',
  },
  {
    batch: 'M81', name: 'DDA / PRQ as an input',
    signal: /\[FEL-DDA\]/i,
    absence: 'PRQ is still write-only — it affects no frame of gameplay',
  },
  {
    batch: 'M82', name: 'PRQ weight table',
    signal: /\[FEL-PRQ\]/i,
    absence: 'only speaks on an UNKNOWN mode id, so silence is the healthy case here',
    silenceIsFine: true,
  },
  {
    batch: 'M83', name: 'seeded RNG',
    signal: /\[FEL-RNG\] session seed/i,
    absence: 'the match is unreplayable: no ghost can reproduce it and no prize result can be audited',
  },
  {
    batch: 'M83', name: 'deterministic SimLoop',
    signal: /\[FEL-SIM\]/i,
    absence: 'modes still run on variable dt; ghosts will drift and jump height depends on frame rate',
  },
];

async function auditMode(context, mode) {
  const page = await context.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(m.text()));
  page.on('pageerror', (e) => logs.push(`PAGEERROR ${e.message}`));

  const found = new Set();
  let engines = null;
  let authWall = false;

  try {
    // ?probe=1 turns on the dev-gated reporters (PoseProbe, and anything else
    // that self-disables in normal play).
    await page.goto(`${BASE}/play/${mode}?probe=1`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(6000);

    authWall = await page.evaluate(
      () => !!document.querySelector('input[type=password]') && !document.querySelector('canvas'),
    ).catch(() => false);

    if (!authWall) {
      // Clear the start gate — most subsystems only speak once play begins.
      await page.evaluate(() => {
        const nav = /^(hub|back|menu|settings|←|→)/i;
        const b = [...document.querySelectorAll('button,[role="button"]')]
          .filter((el) => {
            const r = el.getBoundingClientRect();
            return r.width > 80 && r.height > 28 && !nav.test((el.textContent || '').trim());
          })
          .sort((a, b2) => {
            const ra = a.getBoundingClientRect(); const rb = b2.getBoundingClientRect();
            return rb.width * rb.height - ra.width * ra.height;
          })[0];
        b?.click();
      }).catch(() => {});

      for (const k of ['Space', 'KeyW', 'KeyD', 'Space', 'ShiftLeft']) {
        await page.keyboard.press(k).catch(() => {});
        await page.waitForTimeout(400);
      }
      await page.waitForTimeout(PLAY_MS);

      engines = await page.evaluate(
        () => (window).__FEL_ENGINES__ ?? null,
      ).catch(() => null);
    }
  } catch (e) {
    logs.push(`NAV FAILED ${String(e).slice(0, 120)}`);
  }

  const blob = logs.join('\n');
  for (const s of SUBSYSTEMS) {
    if (s.signal && s.signal.test(blob)) found.add(s.name);
  }
  if (engines) found.add('engine lifecycle (ModeHarness v3)');

  await page.close();
  return { mode, found, engines, authWall, logLines: logs.length };
}

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  proxy: { server: process.env.HTTPS_PROXY },
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--ssl-version-max=tls1.2', '--enable-unsafe-swiftshader'],
});

if (!existsSync(STATE)) {
  console.log(`[AUDIT] WARNING: no session at ${STATE}. FEL is behind a sign-in wall, so`);
  console.log('        every mode will report AUTH and nothing can be measured.');
  console.log('        Capture one first:  node tools/smoke.mjs --login\n');
}

const context = await browser.newContext({
  storageState: existsSync(STATE) ? STATE : undefined,
  viewport: { width: 1280, height: 720 },
});

console.log(`[AUDIT] ${BASE} — probing ${MODES.length} mode(s) for ${SUBSYSTEMS.length} subsystems\n`);

const results = [];
for (const mode of MODES) {
  const r = await auditMode(context, mode);
  results.push(r);
  console.log(`[AUDIT] /play/${r.mode}${r.authWall ? '  — AUTH WALL, nothing measured' : ''}`
    + `  (${r.logLines} console lines)`);
}
await browser.close();

// ── report ───────────────────────────────────────────────────────────────
const walls = results.filter((r) => r.authWall);
const measured = results.filter((r) => !r.authWall);

console.log('\n┌─ SUBSYSTEM ─────────────────────────────────────────────────');
let running = 0; let absent = 0;
const rows = [];
for (const s of SUBSYSTEMS) {
  const modes = measured.filter((r) => r.found.has(s.name)).map((r) => r.mode);
  const seen = modes.length > 0;
  if (seen) running++; else if (!s.silenceIsFine) absent++;
  rows.push({ batch: s.batch, name: s.name, seen, modes });

  const tag = seen ? 'RUNNING' : s.silenceIsFine ? 'quiet  ' : 'NO EVIDENCE';
  console.log(`│ ${s.batch}  ${tag.padEnd(11)} ${s.name}`);
  if (seen) console.log(`│              seen in: ${modes.join(', ')}`);
  else if (!s.silenceIsFine) console.log(`│              → ${s.absence}`);
}
console.log('└─────────────────────────────────────────────────────────────');

for (const r of measured) {
  if (r.engines) {
    const warn = r.engines.live > 2 ? '  ← LEAKING' : '';
    console.log(`[AUDIT] ${r.mode}: WebGL contexts live=${r.engines.live} `
      + `created=${r.engines.created} peak=${r.engines.peak}${warn}`);
  }
}

if (walls.length) {
  console.log(`\n[AUDIT] ${walls.length}/${results.length} route(s) behind a sign-in wall. `
    + 'Capture a session with `node tools/smoke.mjs --login` — without one this '
    + 'audit measures nothing and its silence means nothing.');
}

await mkdir('artifacts', { recursive: true }).catch(() => {});
await writeFile('artifacts/integration-audit.json', JSON.stringify({
  base: BASE, at: new Date().toISOString(),
  modes: results.map((r) => ({ mode: r.mode, authWall: r.authWall, engines: r.engines, found: [...r.found] })),
  subsystems: rows,
}, null, 2));

console.log(`\n[AUDIT] ${running}/${SUBSYSTEMS.length} subsystems observed running`
  + (measured.length ? '' : ' — but NOTHING was measurable, so this number is meaningless'));
console.log('[AUDIT] "NO EVIDENCE" is not "broken": a mode may not reach that code path.');
console.log('        It means nobody has proof it runs, which is how CameraStandoff');
console.log('        went six batches without anyone noticing it never did.');
console.log('        Full report → artifacts/integration-audit.json');

// Exit 0 even with absences: this is a report, not a gate. Gating on it would
// make it something people route around rather than read.

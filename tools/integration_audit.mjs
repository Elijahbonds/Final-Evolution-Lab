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
 * The two viewports that matter, and they disagree.
 *
 * Added 2026-07-27 after the first real run of this tool: `dunk` fills 92% of a
 * 1280×720 desktop and 33% of an iPhone 13. Auditing one viewport would have
 * reported the canvas criterion as healthy. The founder plays on a phone.
 */
const VIEWPORTS = {
  desktop: { width: 1280, height: 720, dpr: 1, touch: false },
  phone: { width: 390, height: 844, dpr: 3, touch: true },
};
const VIEWPORT = argOf('--viewport', 'desktop');

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

/**
 * Measure the page rather than read its logs.
 *
 * `boot` and `canvas` cannot be self-reported — a subsystem can log that it
 * resized and still be 33% of the screen. These are the criteria M93 listed as
 * UNKNOWN and SPECIFIED, and they are the two this function exists to move.
 */
async function measure(page) {
  return page.evaluate(async () => {
    const c = document.querySelector('canvas');
    const r = c?.getBoundingClientRect() ?? null;
    // Walk up from the canvas recording each box, so a starved canvas can be
    // blamed on the specific ancestor that constrains it instead of on
    // "the container chain" in general.
    const chain = [];
    for (let el = c; el && chain.length < 8; el = el.parentElement) {
      const b = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      chain.push({
        tag: el.tagName.toLowerCase(),
        cls: String(el.className ?? '').slice(0, 80),
        w: Math.round(b.width), h: Math.round(b.height),
        aspectRatio: cs.aspectRatio === 'auto' ? null : cs.aspectRatio,
      });
    }
    const fps = await new Promise((res) => {
      let n = 0; const s = performance.now();
      const t = () => { n++; if (performance.now() - s < 2000) requestAnimationFrame(t); else res(n / ((performance.now() - s) / 1000)); };
      requestAnimationFrame(t);
    });
    return {
      canvas: r && c ? { cssW: Math.round(r.width), cssH: Math.round(r.height), bufW: c.width, bufH: c.height } : null,
      viewport: { w: innerWidth, h: innerHeight, dpr: devicePixelRatio },
      coverage: r ? +((r.width * r.height) / (innerWidth * innerHeight) * 100).toFixed(1) : null,
      // Backing pixels per CSS pixel. Above 4 (i.e. DPR > 2) is pure cost: it
      // is invisible on a phone and it is quadratic in the fill rate.
      pixelRatio: r && c && r.width ? +((c.width * c.height) / (r.width * r.height)).toFixed(2) : null,
      chain,
      fps: Math.round(fps * 10) / 10,
    };
  }).catch(() => null);
}

async function auditMode(context, mode) {
  const page = await context.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(m.text()));
  page.on('pageerror', (e) => logs.push(`PAGEERROR ${e.message}`));

  const found = new Set();
  let engines = null;
  let authWall = false;
  let metrics = null;
  const boot = { domMs: null, canvasMs: null, playingMs: null };
  const pageErrors = [];
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 100)));

  try {
    // ?probe=1 turns on the dev-gated reporters (PoseProbe, and anything else
    // that self-disables in normal play).
    const t0 = Date.now();
    await page.goto(`${BASE}/play/${mode}?probe=1`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    boot.domMs = Date.now() - t0;
    await page.waitForSelector('canvas', { timeout: 25000 })
      .then(() => { boot.canvasMs = Date.now() - t0; }).catch(() => {});
    await page.waitForTimeout(6000);

    authWall = await page.evaluate(
      () => !!document.querySelector('input[type=password]') && !document.querySelector('canvas'),
    ).catch(() => false);

    if (!authWall) {
      // On a touch viewport the start gate needs a REAL tap. A synthetic
      // click() leaves the mode stuck at "loaded", which on the first run of
      // this tool looked exactly like a mobile start-gate bug and was not one.
      // Reporting that would have sent someone chasing a Playwright artifact.
      if (VIEWPORTS[VIEWPORT]?.touch) {
        // ANCHORED. A loose /START|PLAY/ matched "MATCH PLAY" in the tennis
        // title before it matched the button, so tennis reported as never
        // reaching `playing` — a tooling artifact I nearly wrote up as a mode
        // that would not start.
        const gate = page.getByText(/^\s*(TAP TO START|START|BEGIN)\s*$/i).first();
        const box = await gate.boundingBox().catch(() => null);
        if (box) await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2).catch(() => {});
      }
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
      metrics = await measure(page);
    }
  } catch (e) {
    logs.push(`NAV FAILED ${String(e).slice(0, 120)}`);
  }

  const blob = logs.join('\n');
  for (const s of SUBSYSTEMS) {
    if (s.signal && s.signal.test(blob)) found.add(s.name);
  }
  if (engines) found.add('engine lifecycle (ModeHarness v3)');

  // The phase trail is the mode's own account of whether it got there.
  const trail = logs.filter((l) => l.includes('[FEL-READY]')).map((l) => l.split('→').pop().trim());

  /**
   * Health while the player does NOTHING.
   *
   * Added after the fleet scan that found skateboard, snowboard and surf
   * losing the rider through the floor with zero input. That class of bug —
   * the mode destroying itself unattended — was invisible to every check this
   * project had, because every check drove the game.
   */
  const grounding = logs.filter((l) => /missed raycasts|hard-clamping/i.test(l));
  const depths = grounding.map((l) => parseFloat((l.match(/y=(-?[\d.]+)/) || [])[1])).filter(Number.isFinite);
  const idle = {
    groundingFaults: grounding.length,
    worstDepth: depths.length ? Math.min(...depths) : null,
    pageErrors: [...new Set(pageErrors)],
  };

  await page.close();
  return { mode, found, engines, authWall, metrics, boot, trail, idle, logLines: logs.length };
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

const vp = VIEWPORTS[VIEWPORT] ?? VIEWPORTS.desktop;
const context = await browser.newContext({
  storageState: existsSync(STATE) ? STATE : undefined,
  viewport: { width: vp.width, height: vp.height },
  deviceScaleFactor: vp.dpr,
  hasTouch: vp.touch,
  isMobile: vp.touch,
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

// ── measured criteria ────────────────────────────────────────────────────
//
// These are judged, not just printed. A number nobody compares to a threshold
// is a number nobody acts on, and `boot` and `canvas` sat at UNKNOWN and
// SPECIFIED through ten phases for exactly that reason.
const MIN_COVERAGE = 55;      // below this the game is a window in a page
const MAX_PIXEL_RATIO = 4;    // DPR 2. Above it is invisible and quadratic.
const MAX_CANVAS_MS = 4000;

console.log('\n┌─ MEASURED ─────────────────────────────────────────────────');
console.log(`│ viewport: ${VIEWPORT} ${vp.width}×${vp.height} @${vp.dpr}x${vp.touch ? ' touch' : ''}`);
for (const r of measured) {
  const m = r.metrics;
  if (!m || !m.canvas) { console.log(`│ ${r.mode.padEnd(12)} no canvas — reached: ${r.trail.join(' → ') || 'nothing'}`); continue; }
  const cov = m.coverage < MIN_COVERAGE ? `${m.coverage}% FAIL` : `${m.coverage}% ok`;
  const px = m.pixelRatio > MAX_PIXEL_RATIO ? `${m.pixelRatio}× FAIL` : `${m.pixelRatio}× ok`;
  const bt = r.boot.canvasMs === null ? 'never' : r.boot.canvasMs > MAX_CANVAS_MS ? `${r.boot.canvasMs}ms SLOW` : `${r.boot.canvasMs}ms`;
  console.log(`│ ${r.mode.padEnd(12)} canvas ${m.canvas.cssW}×${m.canvas.cssH}  cover ${cov}  buffer ${px}  boot ${bt}`);
  console.log(`│              reached: ${r.trail.join(' → ') || 'nothing'}`);
  if (m.coverage < MIN_COVERAGE) {
    // Name the ancestor responsible instead of blaming "the container chain".
    // Skip the canvas itself: `getComputedStyle(canvas).aspectRatio` reports
    // the INTRINSIC ratio from its width/height attributes, so the first run
    // of this check accused the canvas of constraining itself.
    const culprit = m.chain.slice(1).find((c) => c.aspectRatio && c.tag !== 'canvas');
    console.log(`│              → starved by ${culprit ? `aspect-ratio ${culprit.aspectRatio} on <${culprit.tag} class="${culprit.cls}">` : 'an ancestor with no aspect-ratio set — inspect the chain in the JSON'}`);
  }
}
console.log('└─────────────────────────────────────────────────────────────');
console.log('[AUDIT] fps here is SOFTWARE-RENDERED (SwiftShader) and means nothing');
console.log('        about a real device. Only the geometry above is transferable.');

// ── health with no player input ──────────────────────────────────────────
const sick = measured.filter((r) => r.idle && (r.idle.groundingFaults > 0 || r.idle.pageErrors.length));
console.log('\n┌─ UNATTENDED ───────────────────────────────────────────────');
if (!sick.length) {
  console.log(`│ ${measured.length}/${measured.length} modes survive with no player input.`);
} else {
  for (const r of sick) {
    if (r.idle.groundingFaults) {
      console.log(`│ ${r.mode.padEnd(12)} ${String(r.idle.groundingFaults).padStart(4)} grounding faults, `
        + `worst y ${r.idle.worstDepth}`);
      console.log('│              → the actor is leaving the world unattended. A clamp that');
      console.log('│                keeps firing is not holding — see M96.');
    }
    for (const e of r.idle.pageErrors) console.log(`│ ${r.mode.padEnd(12)} ERROR ${e}`);
  }
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
  base: BASE, at: new Date().toISOString(), viewport: { name: VIEWPORT, ...vp },
  modes: results.map((r) => ({
    mode: r.mode, authWall: r.authWall, engines: r.engines, found: [...r.found],
    boot: r.boot, trail: r.trail, metrics: r.metrics, idle: r.idle,
  })),
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

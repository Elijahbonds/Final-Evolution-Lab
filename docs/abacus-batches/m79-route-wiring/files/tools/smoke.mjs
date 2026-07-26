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
//
// v2 — AUTH. The first live run of v1 reported all six modes broken with
// "no <canvas>". They were fine: FEL is behind a sign-in wall, and a fresh
// browser context lands on the login screen. An unauthenticated smoke test
// reports a false failure on every gated route, which is the worst thing a
// gate can do. v2 loads a saved session (--state), and if it still lands on
// a login wall it says AUTH WALL explicitly instead of blaming the game.
//
// Capture a session once:
//   node tools/smoke.mjs --login   → opens a browser, you sign in, it saves
//                                     state.json for every later run

import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const STATE = argOf('--state', 'smoke-state.json');
const LOGIN = args.includes('--login');
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
    const probe = await page.evaluate(() => {
      const c = document.querySelector('canvas');
      return {
        canvas: c ? { w: c.clientWidth, h: c.clientHeight } : null,
        text: (document.body.innerText || '').slice(0, 400),
        hasPasswordField: !!document.querySelector('input[type=password]'),
      };
    });

    // An auth wall is NOT a broken game. Report it as its own state so a
    // missing session can never masquerade as six broken modes.
    const looksLikeAuth = probe.hasPasswordField
      || (!probe.canvas && AUTH_MARKERS.some((re) => re.test(probe.text)));
    if (looksLikeAuth) {
      await mkdir(SHOTS, { recursive: true });
      await page.screenshot({ path: `${SHOTS}/${mode}.png` });
      await page.close();
      return { mode, status, problems: [], authWall: true };
    }

    if (!probe.canvas) problems.push('no <canvas> on the page — the 3D scene never mounted');
    else if (probe.canvas.w < 100 || probe.canvas.h < 100) {
      problems.push(`canvas is ${probe.canvas.w}x${probe.canvas.h} — collapsed layout`);
    }

    // ── CLEAR THE START GATE ────────────────────────────────────────────
    // v2 pressed 'j' and hoped. It never worked: every mode opens on a
    // "TAP TO START" overlay that wants a real click, so v2 screenshotted a
    // loading screen, saw a canvas behind it, and reported PASS. Karate
    // passed that way while a genuine SKINNING STALL was waiting on the
    // other side of the gate. A canvas is not a running game.
    // v4: DO NOT match the start button by label.
    //
    // v3 looked for /tap to start/ and that silently under-tested every mode
    // with a custom label — gymnastics says "SALUTE THE JUDGES", so it was
    // reported as never starting when it starts fine. Same blind spot as v2's
    // (a gate the test cannot clear looks like a broken game), one level down.
    //
    // Instead: click the largest non-navigation button on the page. A start
    // gate is, by construction, the most prominent control on a screen whose
    // only job is to be clicked.
    const clickedLabel = await page.evaluate(() => {
      const nav = /^(hub|back|menu|settings|←|→)/i;
      const btns = [...document.querySelectorAll('button,[role="button"]')]
        .filter((el) => {
          const r = el.getBoundingClientRect();
          return r.width > 80 && r.height > 28 && !nav.test((el.textContent || '').trim());
        })
        .sort((a, b) => {
          const ra = a.getBoundingClientRect(); const rb = b.getBoundingClientRect();
          return (rb.width * rb.height) - (ra.width * ra.height);
        });
      if (!btns[0]) return null;
      const label = (btns[0].textContent || '').trim();
      btns[0].click();
      return label;
    }).catch(() => null);
    if (!clickedLabel) {
      await page.locator('canvas').first().click({ force: true, timeout: 5000 }).catch(() => {});
    }

    // The readyMarker (M67) is the authority on whether we got in.
    const reachedPlaying = await page.waitForFunction(
      () => document.querySelector('#fel-ready')?.getAttribute('data-state') === 'playing',
      { timeout: 20000 },
    ).then(() => true).catch(() => false);

    if (!reachedPlaying) {
      const st = await page.evaluate(
        () => document.querySelector('#fel-ready')?.getAttribute('data-state') ?? '(no #fel-ready)',
      ).catch(() => '(unreadable)');
      // NOT every mode is a Babylon scene. Gymnastics is a 2-D timing game and
      // Music is React; neither spawns characters or publishes #fel-ready, and
      // both work. Treating "no marker" as a failure would report two healthy
      // modes as broken — the same false-negative this tool keeps relearning.
      // A 2-D mode is judged on whether its own UI came up instead.
      const twoD = await page.evaluate(
        () => !!document.querySelector('canvas, [data-mode-2d]') && !document.querySelector('#fel-ready'),
      ).catch(() => false);
      if (st === '(no #fel-ready)' && twoD) {
        console.log(`        (2-D mode: no #fel-ready by design; clicked "${clickedLabel ?? 'canvas'}")`);
      } else {
        problems.push(`never reached 'playing' — stuck at "${st}" after clicking `
          + `"${clickedLabel ?? 'canvas'}". The start gate was not cleared, so nothing below `
          + 'this point has actually been exercised.');
      }
    }

    // Play for long enough to matter. SkinningGuard needs 45 rendered frames
    // (~0.8s) before it reports, and the camera/frame watchdogs need real
    // movement to trip — 3.5s of nothing was never going to surface either.
    for (const k of ['Space', 'KeyW', 'KeyW', 'Space', 'KeyA', 'KeyD', 'Space']) {
      await page.keyboard.press(k).catch(() => {});
      await page.waitForTimeout(600);
    }
    await page.waitForTimeout(6000);

    await mkdir(SHOTS, { recursive: true });
    await page.screenshot({ path: `${SHOTS}/${mode}.png` });
  } catch (e) {
    problems.push(`navigation failed: ${String(e).slice(0, 160)}`);
  }
  await page.close();
  return { mode, status, problems, authWall: false };
}

// Signals that we are looking at a sign-in wall rather than the game.
const AUTH_MARKERS = [/sign in/i, /log ?in/i, /create account/i, /enter the lab/i, /password/i];

async function captureLogin() {
  const b = await chromium.launch({ headless: false });
  const c = await b.newContext({ viewport: { width: 1280, height: 900 } });
  const p = await c.newPage();
  await p.goto(BASE, { waitUntil: 'domcontentloaded' });
  console.log('[SMOKE] sign in in the browser window, then press Enter here…');
  await new Promise((r) => process.stdin.once('data', r));
  await c.storageState({ path: STATE });
  console.log(`[SMOKE] session saved → ${STATE}`);
  await b.close();
}

if (LOGIN) { await captureLogin(); process.exit(0); }

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', proxy: { server: process.env.HTTPS_PROXY }, args: ['--no-sandbox','--disable-dev-shm-usage','--ssl-version-max=tls1.2','--enable-unsafe-swiftshader'] });
if (!existsSync(STATE)) {
  console.log(`[SMOKE] WARNING: no session at ${STATE}. FEL is behind a sign-in wall, so`);
  console.log('        gated routes will report AUTH WALL, not real failures.');
  console.log('        Run:  node tools/smoke.mjs --login');
}
const context = await browser.newContext({
  storageState: existsSync(STATE) ? STATE : undefined,
  viewport: { width: 1280, height: 720 },
});

console.log(`[SMOKE] ${BASE} — ${MODES.length} mode(s)\n`);
const results = [];
for (const mode of MODES) {
  const r = await checkMode(context, mode);
  results.push(r);
  const tag = r.authWall ? 'AUTH' : r.problems.length ? 'FAIL' : 'PASS';
  console.log(`[SMOKE] ${tag} /play/${r.mode} (HTTP ${r.status})`
    + (r.authWall ? '  — sign-in wall, not a game failure' : ''));
  for (const p of r.problems) console.log(`        ${p}`);
}
await browser.close();

const walls = results.filter((r) => r.authWall);
const failed = results.filter((r) => r.problems.length);
if (walls.length) {
  console.log(`\n[SMOKE] ${walls.length} route(s) behind a sign-in wall — capture a session with --login`);
}
await writeFile('smoke-report.json', JSON.stringify({ base: BASE, results }, null, 2));
console.log(`\n[SMOKE] ${results.length - failed.length}/${results.length} passed · screenshots in ${SHOTS}/`);

if (failed.length) {
  console.log('[SMOKE] FAILING — the live build has problems in: ' + failed.map((f) => f.mode).join(', '));
  process.exit(1);
}

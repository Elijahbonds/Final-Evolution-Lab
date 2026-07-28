#!/usr/bin/env node
// dunk_gate.mjs — is the dunk contest shippable yet?
//
//     node tools/dunk_gate.mjs                 # phone, the viewport that matters
//     node tools/dunk_gate.mjs --desktop
//
// ONE command, ONE mode, SEVEN checks, run against the deployed build. It
// replaces reading four separate reports and deciding for yourself.
//
// Every threshold here was measured, not chosen — see docs/DUNK-FIRST.md for
// where each number came from. A check that fails prints the measurement AND
// what to do about it, because a red line with no next step is how a scorecard
// becomes wallpaper.
//
// This deliberately does NOT check verification, replays or determinism. Those
// are tier 2, and they matter only if someone wants to play the game twice.

import { chromium, devices } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const BASE = (args.includes('--url') && args[args.indexOf('--url') + 1]) || 'https://finalevolution.abacusai.app';
const STATE = 'smoke-state.json';
const PHONE = !args.includes('--desktop');

/** Captures the Babylon engine: it binds its render loop to itself. */
const HOOK = () => {
  const rb = Function.prototype.bind;
  window.__E = [];
  Function.prototype.bind = function (t, ...r) {
    try {
      if (t && typeof t === 'object' && Array.isArray(t.scenes)
        && typeof t.getRenderingCanvas === 'function' && !window.__E.includes(t)) window.__E.push(t);
    } catch { /* observing must never break the page */ }
    return rb.call(this, t, ...r);
  };
};

const MEASURE = () => {
  const out = { canvas: null, character: null, captions: null, skin: null, grounding: 0 };
  const c = document.querySelector('canvas');
  if (c) {
    const r = c.getBoundingClientRect();
    out.canvas = {
      cssW: Math.round(r.width), cssH: Math.round(r.height),
      coverage: +((r.width * r.height) / (innerWidth * innerHeight) * 100).toFixed(1),
      pixelRatio: +((c.width * c.height) / (r.width * r.height)).toFixed(2),
    };
  }
  out.captions = {
    live: document.querySelectorAll('[aria-live]').length,
    status: document.querySelectorAll('[role="status"],[role="alert"]').length,
  };

  const s = (window.__E ?? []).flatMap((e) => e.scenes ?? []).find((x) => x.skeletons?.length);
  if (s && c) {
    const sk = s.skeletons[0];
    const n = (b) => sk.bones.find((x) => x.name === b)?.getTransformNode?.();
    const head = n('Head'); const foot = n('LeftFoot') ?? n('LeftToeBase');
    if (head && foot) {
      const eng = s.getEngine();
      const V = head.getAbsolutePosition().constructor;
      const M = head.getWorldMatrix().constructor;
      const vp = s.activeCamera.viewport.toGlobal(eng.getRenderWidth(), eng.getRenderHeight());
      const P = (nd) => { nd.computeWorldMatrix(true); return V.Project(nd.getAbsolutePosition(), M.Identity(), s.getTransformMatrix(), vp); };
      const px = Math.abs(P(foot).y - P(head).y);
      out.character = {
        framePct: +((px / eng.getRenderHeight()) * 100).toFixed(1),
        cssPx: Math.round(px * (c.getBoundingClientRect().height / eng.getRenderHeight())),
      };
    }
    // Skin weights: is the mesh bound to its skeleton, or welded to one bone?
    const mesh = s.meshes.find((m) => m.skeleton === sk);
    const idx = mesh?.getVerticesData?.('matricesIndices');
    const wts = mesh?.getVerticesData?.('matricesWeights');
    if (idx && wts) {
      const tally = {};
      for (let i = 0; i < idx.length; i += 4) {
        let best = 0; let bi = 0;
        for (let k = 0; k < 4; k++) if (wts[i + k] > best) { best = wts[i + k]; bi = idx[i + k]; }
        const name = sk.bones[bi]?.name ?? `#${bi}`;
        tally[name] = (tally[name] ?? 0) + 1;
      }
      const total = Object.values(tally).reduce((a, b) => a + b, 0);
      const [bone, n2] = Object.entries(tally).sort((a, b) => b[1] - a[1])[0];
      out.skin = { dominantBone: bone, share: +((n2 / total) * 100).toFixed(1) };
    }
  }
  return out;
};

// threshold, and where it came from
const CHECKS = [
  ['canvas coverage', (m) => m.canvas?.coverage, 55, '%', 'M95: measured 26.2% on an iPhone; aspect-[16/10] on the stage wrapper'],
  ['backing pixel ratio', (m) => m.canvas?.pixelRatio, 4, 'x', 'M95: measured 9.01x — DPR 3 taken literally, 56% of fill rate for nothing', true],
  ['character on screen', (m) => m.character?.framePct, 15, '%', 'M97: measured 8.3%; camera radius 14 -> 3.0'],
  ['character size', (m) => m.character?.cssPx, 100, 'px', 'M97: a subject-anchored tell needs ~24px, which is a third of the body'],
  ['live regions', (m) => m.captions?.live, 2, '', 'M100: measured 0 in four modes; the caption bus renders nowhere'],
  ['mesh not welded', (m) => (m.skin ? +(100 - m.skin.share).toFixed(1) : null), 60, '%', 'M98: 77% of the mesh is bound to the Head bone; re-export from Blender'],
];

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  proxy: { server: process.env.HTTPS_PROXY },
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--ssl-version-max=tls1.2', '--enable-unsafe-swiftshader'],
});
const ctx = await browser.newContext(PHONE
  ? { ...devices['iPhone 13'], storageState: existsSync(STATE) ? STATE : undefined }
  : { storageState: existsSync(STATE) ? STATE : undefined, viewport: { width: 1280, height: 800 } });
const page = await ctx.newPage();
await page.addInitScript(HOOK);

const logs = [];
page.on('console', (m) => logs.push(m.text()));

console.log(`\n  DUNK GATE — ${BASE} — ${PHONE ? 'iPhone 13' : 'desktop 1280x800'}\n`);
let m = {};
try {
  await page.goto(`${BASE}/play/dunk`, { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForSelector('canvas', { timeout: 30000 });
  await page.waitForTimeout(5500);
  const gate = page.getByText(/^\s*(TAP TO START|START)\s*$/i).first();
  const gb = await gate.boundingBox().catch(() => null);
  if (gb) {
    if (PHONE) await page.touchscreen.tap(gb.x + gb.width / 2, gb.y + gb.height / 2);
    else await gate.click().catch(() => {});
  }
  await page.waitForTimeout(7000);
  m = await page.evaluate(MEASURE);
} catch (e) {
  console.log(`  could not reach the mode: ${String(e).slice(0, 80)}\n`);
}
m.grounding = logs.filter((l) => /missed raycasts|hard-clamping/i.test(l)).length;

let failed = 0;
for (const [name, get, threshold, unit, why, lowerIsBetter] of CHECKS) {
  const v = get(m);
  if (v === null || v === undefined) {
    console.log(`  ?  ${name.padEnd(22)} not measurable`);
    failed++;
    continue;
  }
  const ok = lowerIsBetter ? v <= threshold : v >= threshold;
  if (!ok) failed++;
  const want = lowerIsBetter ? `<= ${threshold}` : `>= ${threshold}`;
  console.log(`  ${ok ? 'ok' : 'NO'} ${name.padEnd(22)} ${String(v).padStart(6)}${unit}  (want ${want}${unit})`);
  if (!ok) console.log(`     -> ${why}`);
}
// Unattended health: the mode must not destroy itself while nobody plays.
const gOk = m.grounding === 0;
if (!gOk) failed++;
console.log(`  ${gOk ? 'ok' : 'NO'} ${'survives unattended'.padEnd(22)} ${String(m.grounding).padStart(6)}   (want 0 grounding faults)`);

console.log(`\n  ${CHECKS.length + 1 - failed}/${CHECKS.length + 1} checks pass.`);
console.log(failed
  ? '  NOT SHIPPABLE. Every failure above has a fix already written — see docs/DUNK-FIRST.md.\n'
  : '  SHIPPABLE on the measurable criteria. The one left is whether it is fun,\n'
    + '  and only real players answer that.\n');

await mkdir('artifacts', { recursive: true }).catch(() => {});
await writeFile('artifacts/dunk-gate.json', JSON.stringify(
  { base: BASE, viewport: PHONE ? 'iPhone 13' : 'desktop', at: new Date().toISOString(), measured: m, failed }, null, 2));
await browser.close();
process.exit(failed ? 1 : 0);

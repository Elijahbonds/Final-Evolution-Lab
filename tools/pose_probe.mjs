#!/usr/bin/env node
// pose_probe.mjs — look INSIDE the running game, without changing the app.
//
//     node tools/pose_probe.mjs
//     node tools/pose_probe.mjs --modes dunk,karate --phone
//
// WHY THIS EXISTS
// M80 shipped `PoseProbe`, which reports bone rotations from inside the app
// under `?probe=1`. It has never been wired, so for four batches the T-pose
// was diagnosed by squinting at screenshots — and I got it wrong twice.
//
// This gets the same answer without needing the app to cooperate. Babylon does
// not put its `Engine` on `window`, but it binds its render loop to itself, so
// hooking `Function.prototype.bind` before any page script runs captures any
// `this` that looks like an Engine. From there: scenes, skeletons, bones,
// world matrices, and the camera projection.
//
// WHAT IT ANSWERS THAT A SCREENSHOT CANNOT
//   - is the arm at 20 degrees from vertical, or at 90? (at 60px they are the
//     same picture, which is exactly how "the characters are T-posed" survived)
//   - how many PIXELS tall is the character? (5-9% of frame in six of eight
//     modes — the actual reason nothing is readable)
//
// It reads. It never writes. An observation tool that can change the thing it
// observes is a tool whose findings you cannot trust.

import { chromium, devices } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const argOf = (f, d) => { const i = args.indexOf(f); return i >= 0 && args[i + 1] ? args[i + 1] : d; };
const BASE = argOf('--url', 'https://finalevolution.abacusai.app');
const STATE = argOf('--state', 'smoke-state.json');
const MODES = argOf('--modes', 'dunk,onevone,karate,karate-vs,football,baseball,tennis,skateboard').split(',');
const PHONE = args.includes('--phone');

/** Runs before any page script. Captures the Babylon Engine via its bound render loop. */
const HOOK = () => {
  const realBind = Function.prototype.bind;
  window.__FEL_ENGINES_CAPTURED = [];
  Function.prototype.bind = function (thisArg, ...rest) {
    try {
      if (thisArg && typeof thisArg === 'object'
        && Array.isArray(thisArg.scenes)
        && typeof thisArg.getRenderingCanvas === 'function'
        && !window.__FEL_ENGINES_CAPTURED.includes(thisArg)) {
        window.__FEL_ENGINES_CAPTURED.push(thisArg);
      }
    } catch { /* observation must never break the page */ }
    return realBind.call(this, thisArg, ...rest);
  };
};

/** Everything measurable about the first skinned character in the scene. */
const MEASURE = () => {
  const s = (window.__FEL_ENGINES_CAPTURED ?? []).flatMap((e) => e.scenes ?? [])
    .find((x) => x.skeletons?.length);
  if (!s) return { error: 'no scene with a skeleton — did the mode reach playing?' };
  const sk = s.skeletons[0];
  const eng = s.getEngine();
  const n = (name) => sk.bones.find((b) => b.name === name)?.getTransformNode?.() ?? null;
  const world = (node) => { node.computeWorldMatrix(true); return node.getAbsolutePosition(); };

  const head = n('Head'); const foot = n('LeftFoot') ?? n('LeftToeBase');
  const sh = n('LeftArm'); const hand = n('LeftHand') ?? n('LeftForeArm'); const hips = n('Hips');
  if (!head || !foot || !hips) return { error: 'rig is missing Head/Foot/Hips — names are UNPREFIXED' };

  const V = world(head).constructor;
  const M = head.getWorldMatrix().constructor;
  const vp = s.activeCamera.viewport.toGlobal(eng.getRenderWidth(), eng.getRenderHeight());
  const proj = (node) => V.Project(world(node), M.Identity(), s.getTransformMatrix(), vp);

  const hp = proj(head); const fp = proj(foot);
  const charPx = Math.abs(fp.y - hp.y);
  const canvasPx = eng.getRenderHeight();

  let arm = null;
  if (sh && hand) {
    const a = world(sh).clone(); const b = world(hand).clone(); const h = world(hips).clone();
    arm = {
      // 0 = straight down, 90 = straight out. Bind on this rig is 90.
      angleFromVertical: Math.round((Math.atan2(Math.hypot(b.x - a.x, b.z - a.z), a.y - b.y) * 180) / Math.PI),
      handOutFromHips: +Math.abs(b.x - h.x).toFixed(3),
      handRelativeToHipsY: +(b.y - h.y).toFixed(3),
    };
  }

  const c = eng.getRenderingCanvas().getBoundingClientRect();
  return {
    charPx: Math.round(charPx),
    canvasPx,
    // What the PLAYER sees, which is the backing measurement scaled to CSS.
    charCssPx: Math.round(charPx * (c.height / canvasPx)),
    frameFraction: +(charPx / canvasPx).toFixed(4),
    heightMetres: +(world(head).y - world(foot).y).toFixed(3),
    fovRad: +s.activeCamera.fov.toFixed(4),
    cameraDistance: +V.Distance(s.activeCamera.globalPosition ?? s.activeCamera.position, world(hips)).toFixed(2),
    arm,
    playing: (s.animationGroups ?? []).filter((g) => g.isPlaying).map((g) => g.name),
  };
};

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  proxy: { server: process.env.HTTPS_PROXY },
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--ssl-version-max=tls1.2', '--enable-unsafe-swiftshader'],
});
if (!existsSync(STATE)) {
  console.log(`[POSE] no session at ${STATE} — every mode will hit the sign-in wall.`);
  console.log('       node tools/smoke.mjs --login\n');
}
const ctx = await browser.newContext(PHONE
  ? { ...devices['iPhone 13'], storageState: existsSync(STATE) ? STATE : undefined }
  : { storageState: existsSync(STATE) ? STATE : undefined, viewport: { width: 1280, height: 800 } });

console.log(`[POSE] ${BASE} — ${PHONE ? 'iPhone 13' : 'desktop 1280x800'}\n`);
console.log('mode          char px   css px   % frame   cam m    arm°   hand out   clip');
const rows = [];
for (const mode of MODES) {
  const page = await ctx.newPage();
  await page.addInitScript(HOOK);
  let m = { error: 'navigation failed' };
  try {
    await page.goto(`${BASE}/play/${mode}`, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForSelector('canvas', { timeout: 30000 });
    await page.waitForTimeout(5000);
    // Anchored: a loose /START|PLAY/ matches "MATCH PLAY" in a title.
    const gate = page.getByText(/^\s*(TAP TO START|START)\s*$/i).first();
    const gb = await gate.boundingBox().catch(() => null);
    if (gb) {
      if (PHONE) await page.touchscreen.tap(gb.x + gb.width / 2, gb.y + gb.height / 2);
      else await gate.click().catch(() => {});
    }
    await page.waitForTimeout(6000);
    m = await page.evaluate(MEASURE);
  } catch (e) { m = { error: String(e).slice(0, 70) }; }

  if (m.error) console.log(`${mode.padEnd(13)} ${m.error}`);
  else {
    console.log(`${mode.padEnd(13)} ${String(m.charPx).padStart(7)}  ${String(m.charCssPx).padStart(7)}  `
      + `${(m.frameFraction * 100).toFixed(1).padStart(7)}%  ${String(m.cameraDistance).padStart(6)}  `
      + `${String(m.arm?.angleFromVertical ?? '-').padStart(5)}  ${String(m.arm?.handOutFromHips ?? '-').padStart(8)}   `
      + (m.playing[0] ?? '—'));
  }
  rows.push({ mode, ...m });
  await page.close();
}
await browser.close();

const ok = rows.filter((r) => !r.error);
if (ok.length) {
  const tooFar = ok.filter((r) => r.frameFraction < 0.15);
  console.log(`\n[POSE] ${tooFar.length}/${ok.length} modes frame the character below 15% of the screen.`);
  if (tooFar.length) {
    console.log('       At that size a 20-degree arm and a 90-degree arm are the same');
    console.log('       picture, and no subject-anchored tell can be read. See M97.');
  }
  const bind = ok.filter((r) => r.arm && r.arm.angleFromVertical > 75);
  console.log(`[POSE] ${bind.length}/${ok.length} modes show arms above 75 degrees (bind pose is 90).`);
}
await mkdir('artifacts', { recursive: true }).catch(() => {});
await writeFile('artifacts/pose-probe.json', JSON.stringify({
  base: BASE, at: new Date().toISOString(), viewport: PHONE ? 'iPhone 13' : 'desktop 1280x800', modes: rows,
}, null, 2));
console.log('       Full report → artifacts/pose-probe.json');
